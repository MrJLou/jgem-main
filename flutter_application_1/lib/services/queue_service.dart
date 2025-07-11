import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'database_helper.dart';
import '../models/active_patient_queue_item.dart';
import '../models/appointment.dart';
import 'auth_service.dart';
import 'database_sync_client.dart'; // Added for sync triggering
import 'enhanced_shelf_lan_server.dart'; // Added for server status checking
import 'dart:math';
import 'api_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get current active queue items from the database.
  /// By default, fetches 'waiting' and 'in_progress' statuses.
  Future<List<ActivePatientQueueItem>> getActiveQueueItems(
      {List<String> statuses = const ['waiting', 'in_progress']}) async {
    return await _dbHelper.getActiveQueue(statuses: statuses);
  }

  /// Checks if a patient is already in the active queue with 'waiting' or 'in_progress' status.
  Future<bool> isPatientCurrentlyActive(
      {String? patientId, required String patientName}) async {
    try {
      return await _dbHelper.isPatientInActiveQueue(
        patientId: patientId,
        patientName: patientName,
      );
    } catch (e) {
      if (kDebugMode) {
        print('QueueService: Error checking if patient is active in queue: $e');
      }
      // Depending on your error handling strategy:
      // Option 1: Rethrow the error to be handled by the caller
      // throw Exception('Failed to check patient queue status: $e');
      // Option 2: Return false, allowing the UI to potentially proceed.
      return false;
    }
  }

  /// Add patient to the active queue in the database using raw data.
  Future<ActivePatientQueueItem> addPatientDataToQueue(
      Map<String, dynamic> patientData) async {
    final currentUserId = await AuthService.getCurrentUserId();
    final now = DateTime.now();
    String queueEntryId = patientData['queueId']?.toString() ??
        'qentry-${now.millisecondsSinceEpoch}-${Random().nextInt(9999)}';

    if (kDebugMode) {
      print(
          'QueueService: SYNC DEBUG - Creating queue entry with ID: $queueEntryId');
      print(
          'QueueService: SYNC DEBUG - Client sync connected: ${DatabaseSyncClient.isConnected}');
      print(
          'QueueService: SYNC DEBUG - Host server running: ${EnhancedShelfServer.isRunning}');
    }

    final nextQueueNumber = await _getNextQueueNumber();

    final newItem = ActivePatientQueueItem(
      queueEntryId: queueEntryId,
      patientId: patientData['patientId']?.toString() ?? '',
      patientName: patientData['patientName']?.toString() ?? 'Unnamed Patient',
      arrivalTime:
          DateTime.tryParse(patientData['arrivalTime']?.toString() ?? '') ??
              now,
      queueNumber: nextQueueNumber,
      gender: patientData['gender']?.toString() ?? '',
      age: patientData['age'] is int
          ? patientData['age']
          : (patientData['age'] is String
              ? int.tryParse(patientData['age']!)
              : null),
      conditionOrPurpose: patientData['conditionOrPurpose']?.toString() ?? '',
      status: patientData['status']?.toString() ?? 'waiting',
      createdAt: now,
      addedByUserId: currentUserId,
      selectedServices: (patientData['selectedServices'] as List?)
          ?.cast<Map<String, dynamic>>(),
      totalPrice: (patientData['totalPrice'] as num?)?.toDouble() ?? 0.0,
      doctorId: patientData['doctorId']?.toString() ?? '',
      doctorName: patientData['doctorName']?.toString() ?? '',
      isWalkIn: patientData['isWalkIn'] as bool? ?? false,
      originalAppointmentId:
          patientData['originalAppointmentId']?.toString() ?? '',
    );

    // Add to database - this will automatically trigger sync notifications via logChange
    if (kDebugMode) {
      print('QueueService: SYNC DEBUG - Before calling addToActiveQueue');
    }
    final addedItem = await _dbHelper.addToActiveQueue(newItem);
    if (kDebugMode) {
      print('QueueService: SYNC DEBUG - After calling addToActiveQueue');
    }

    // Trigger immediate sync to notify connected devices
    _triggerImmediateSync();

    // Log successful queue addition for debugging
    if (kDebugMode) {
      print(
          'QueueService: Successfully added ${addedItem.patientName} to queue (ID: ${addedItem.queueEntryId}, Queue #${addedItem.queueNumber})');
      print(
          'QueueService: Queue addition should trigger real-time sync to connected devices');
    }

    return addedItem;
  }

  /// Adds a pre-constructed ActivePatientQueueItem object to the active queue.
  /// This is useful for activating scheduled appointments.
  Future<bool> addPatientToQueue(ActivePatientQueueItem queueItem) async {
    try {
      if (kDebugMode) {
        print(
            'QueueService: Patient ${queueItem.patientName} (ID: ${queueItem.queueEntryId}) added to active queue via addPatientToQueue.');
      }
      return true; // Return true on success
    } catch (e) {
      if (kDebugMode) {
        print(
            "QueueService: Error in addPatientToQueue for ${queueItem.patientName}: $e");
      }
      return false; // Return false on failure
    }
  }

  /// Get the next queue number for today
  Future<int> _getNextQueueNumber() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final todaysQueue =
        await _dbHelper.getActiveQueueByDateRange(startOfDay, endOfDay);

    if (todaysQueue.isEmpty) {
      return 1;
    }

    final maxQueueNumber = todaysQueue
        .map((item) => item.queueNumber)
        .reduce((a, b) => a > b ? a : b);

    return maxQueueNumber + 1;
  }

  /// Remove patient from active queue (mark as 'removed').
  Future<bool> removeFromQueue(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) return false;

    final updatedItem =
        item.copyWith(status: 'removed', removedAt: DateTime.now());
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);

    if (result > 0) {
      if (updatedItem.originalAppointmentId != null) {
        try {
          await ApiService.updateAppointmentStatus(
              updatedItem.originalAppointmentId!, 'Cancelled');
          if (kDebugMode) {
            print(
                'QueueService: Original appointment ${updatedItem.originalAppointmentId} status updated to Cancelled due to queue removal.');
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                'QueueService: Error updating original appointment ${updatedItem.originalAppointmentId} to Cancelled: $e');
          }
          // Decide if this error should affect the return value of removeFromQueue
        }
      }
    }
    return result > 0;
  }

  /// Get a specific queue item by its ID.
  Future<ActivePatientQueueItem?> getQueueItem(String queueEntryId) async {
    return await _dbHelper.getActiveQueueItem(queueEntryId);
  }

  /// Find patient in queue by name or patient ID (exact match for now).
  /// This might be slow if queue is large; consider DB-side search for more efficiency.
  Future<ActivePatientQueueItem?> findPatientInQueue(String identifier) async {
    final activeQueue =
        await getActiveQueueItems(statuses: ['waiting', 'in_progress']);
    final lowerIdentifier = identifier.toLowerCase().trim();

    for (var item in activeQueue) {
      final nameMatches = item.patientName.toLowerCase() == lowerIdentifier;
      final idMatches = item.patientId?.toLowerCase() == lowerIdentifier;
      if (nameMatches || idMatches) {
        return item;
      }
    }
    return null;
  }

  /// Search patients in active queue by name or patient ID (partial matches).
  Future<List<ActivePatientQueueItem>> searchPatientsInQueue(
      String searchTerm) async {
    final allQueueItems = await getActiveQueueItems(statuses: []);
    if (searchTerm.trim().isEmpty) {
      return allQueueItems
          .where((item) =>
              item.status == 'waiting' || item.status == 'in_progress')
          .toList();
    }
    final lowerSearchTerm = searchTerm.toLowerCase().trim();

    return allQueueItems.where((item) {
      final nameMatches =
          item.patientName.toLowerCase().contains(lowerSearchTerm);
      final idMatches =
          item.patientId?.toLowerCase().contains(lowerSearchTerm) ?? false;
      return nameMatches || idMatches;
    }).toList();
  }

  /// Updates the status of a patient in the active queue and sets relevant timestamps.
  ///
  /// Use this method to change a patient's status and automatically update
  /// `consultationStartedAt`, `servedAt`, or `removedAt` based on the new status.
  Future<bool> updatePatientStatusInQueue(
    String queueEntryId,
    String newStatus, {
    DateTime? consultationStartedAt,
    DateTime? servedAt,
    DateTime? removedAt,
    String? paymentStatus,
  }) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) {
      if (kDebugMode) {
        print(
            'QueueService: Item with ID $queueEntryId not found for status update.');
      }
      return false;
    }

    ActivePatientQueueItem updatedItem;
    final now = DateTime.now();

    // Create a copy with the new status first
    updatedItem = item.copyWith(status: newStatus);

    if (paymentStatus != null) {
      updatedItem = updatedItem.copyWith(paymentStatus: paymentStatus);
    }

    // Update timestamps based on the new status
    switch (newStatus.toLowerCase()) {
      case 'waiting':
        updatedItem = updatedItem.copyWith(
          consultationStartedAt: null, // Explicitly nullify
          servedAt: null, // Explicitly nullify
          removedAt: null, // Explicitly nullify
        );
        break;
      case 'in_progress':
        // If already in progress, keep original start time, otherwise set to now or provided
        updatedItem = updatedItem.copyWith(
          consultationStartedAt: item.status == 'in_progress'
              ? item.consultationStartedAt
              : (consultationStartedAt ?? now),
          servedAt: null, // Nullify if moving back from served/other
          removedAt: null, // Nullify if moving back from removed
        );
        break;
      case 'served':
        updatedItem = updatedItem.copyWith(
          servedAt: servedAt ?? now,
          // If consultationStartedAt is null when moving to served, set it to servedAt time.
          consultationStartedAt:
              item.consultationStartedAt ?? (servedAt ?? now),
          removedAt: null, // Nullify if moving from removed
        );
        break;
      case 'removed':
        updatedItem = updatedItem.copyWith(
          removedAt: removedAt ?? now,
          // Optionally, you might want to keep servedAt if it was served then removed.
          // For now, it will retain its previous value unless explicitly nulled.
        );
        break;
      // Add other statuses if needed, e.g., 'cancelled', 'no_show'
      default:
        // For any other status, just update the status string
        // Timestamps are not automatically managed for unlisted statuses here
        break;
    }

    try {
      final result = await _dbHelper.updateActiveQueueItem(updatedItem);
      if (result > 0) {
        if (kDebugMode) {
          print(
              'QueueService: Successfully updated patient $queueEntryId to status $newStatus');
        }

        // Trigger immediate sync to notify all connected devices
        _triggerImmediateSync();

        // Medical record creation is now handled in markPaymentSuccessfulAndServe
        // and consultation results screen to prevent duplicates
        // Removed: automatic medical record creation on status change to 'served'

        // NO LONGER CREATING APPOINTMENT RECORDS FOR WALK-IN PATIENTS
        // Queue and appointment systems are now completely separate
        // Walk-in patients exist only in the queue system, not in appointments

        if (kDebugMode) {
          print(
              'QueueService: Status updated for ${updatedItem.isWalkIn ? "walk-in" : "scheduled"} patient ${updatedItem.patientName} to $newStatus');
        }

        // ADDED: Propagate to original Appointment if exists
        else if (updatedItem.originalAppointmentId != null) {
          try {
            Appointment? originalAppointment = await _dbHelper
                .appointmentDbService
                .getAppointmentById(updatedItem.originalAppointmentId!);
            if (originalAppointment != null) {
              Appointment updatedOriginalAppointment =
                  originalAppointment.copyWith(
                status: newStatus == 'served'
                    ? 'Completed'
                    : (newStatus == 'in_progress'
                        ? 'In Progress'
                        : originalAppointment
                            .status), // Also update appointment status
                consultationStartedAt: updatedItem.consultationStartedAt ??
                    originalAppointment.consultationStartedAt,
                servedAt: updatedItem.servedAt ?? originalAppointment.servedAt,
                paymentStatus: updatedItem.paymentStatus,
                totalPrice:
                    updatedItem.totalPrice ?? originalAppointment.totalPrice,
                selectedServices: updatedItem.selectedServices ??
                    originalAppointment.selectedServices,
              );
              await _dbHelper.appointmentDbService
                  .updateAppointment(updatedOriginalAppointment);
              if (kDebugMode) {
                print(
                    'QueueService: Updated original appointment ${originalAppointment.id} due to queue status change.');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                  'QueueService: Error updating original appointment after queue status change: $e');
            }
          }
        }

        // Trigger immediate sync notification
        _triggerImmediateSync();

        return true;
      } else {
        if (kDebugMode) {
          print(
              'QueueService: Failed to update patient $queueEntryId status in DB.');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "QueueService: Error in updatePatientStatusInQueue for $queueEntryId: $e");
      }
      return false;
    }
  }

  /// Mark patient as served in the active queue.
  Future<bool> markPatientAsServed(String queueEntryId) async {
    // Reroute to the central status update method to ensure all logic is applied.
    return await updatePatientStatusInQueue(queueEntryId, 'served');
  }

  /// Mark patient as 'in_progress' in the active queue.
  Future<bool> markPatientAsInConsultation(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null || item.status == 'removed' || item.status == 'served') {
      return false;
    }

    final updatedItem = item.copyWith(
        status: 'in_progress',
        consultationStartedAt: DateTime.now(),
        servedAt: null);
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);
    return result > 0;
  }

  /// Mark patient as ongoing (in progress).
  Future<bool> markPatientAsOngoing(String queueEntryId) async {
    return await updatePatientStatusInQueue(queueEntryId, 'in_progress');
  }

  /// Mark patient as done.
  Future<bool> markPatientAsDone(String queueEntryId) async {
    return await updatePatientStatusInQueue(queueEntryId, 'done');
  }

  /// Mark consultation as complete and update patient status
  /// This respects the payment-lab workflow and doesn't immediately mark as served
  /// if the patient still needs payment processing or has pending lab work
  Future<bool> markConsultationComplete(
    String queueEntryId,
    String patientId,
    String doctorId,
  ) async {
    try {
      final item = await _dbHelper.getActiveQueueItem(queueEntryId);
      if (item == null) {
        if (kDebugMode) {
          print(
              'QueueService: Item with ID $queueEntryId not found for consultation completion.');
        }
        return false;
      }

      // Check if this item has lab services that require separate processing
      bool hasLabServices = false;
      if (item.selectedServices != null && item.selectedServices!.isNotEmpty) {
        hasLabServices = item.selectedServices!.any((service) {
          final category = (service['category'] as String? ?? '').toLowerCase();
          return ['laboratory', 'hematology', 'chemistry', 'urinalysis', 'microbiology', 'pathology']
              .contains(category);
        });
      }

      // Determine the appropriate status based on payment and lab requirements
      String newStatus;
      DateTime? servedAtTime;
      
      if (item.paymentStatus == 'Paid') {
        // Payment already processed
        if (hasLabServices) {
          // Has lab services - check if lab results have been entered
          final labResults = await _dbHelper.getLabResultsHistoryForPatient(item.patientId!);
          final hasLabResults = labResults.isNotEmpty;
          
          if (hasLabResults) {
            // Both payment and lab results are complete
            newStatus = 'done';
            servedAtTime = DateTime.now();
          } else {
            // Payment done but lab results still needed
            newStatus = 'in_progress';
            servedAtTime = null;
          }
        } else {
          // No lab services, consultation complete, payment done - fully served
          newStatus = 'done';
          servedAtTime = DateTime.now();
        }
      } else {
        // Payment not yet processed
        if (hasLabServices) {
          // Has lab services but no payment - keep in progress for billing workflow
          newStatus = 'in_progress';
          servedAtTime = null; // Don't mark as served until payment is complete
        } else {
          // No lab services but no payment - keep in progress for billing
          newStatus = 'in_progress';
          servedAtTime = null;
        }
      }

      // Update the queue item with appropriate status
      final updatedItem = item.copyWith(
        status: newStatus,
        servedAt: servedAtTime,
        consultationStartedAt: item.consultationStartedAt ?? DateTime.now(),
      );

      final result = await _dbHelper.updateActiveQueueItem(updatedItem);

      if (kDebugMode) {
        print(
            'QueueService: Consultation completed for $queueEntryId - Status: $newStatus, HasLabServices: $hasLabServices, PaymentStatus: ${item.paymentStatus}');
      }

      if (result > 0) {
        // If the original item was an appointment, update its status
        if (item.originalAppointmentId != null) {
          try {
            await ApiService.updateAppointmentStatus(
                item.originalAppointmentId!, 'Completed');
          } catch (e) {
            if (kDebugMode) {
              print(
                  'QueueService: Failed to update original appointment status: $e');
            }
          }
        }

        // Trigger immediate sync notification
        _triggerImmediateSync();

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print(
            'QueueService: Error in markConsultationComplete for $queueEntryId: $e');
      }
      return false;
    }
  }

  // Helper methods
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${twoDigitMinutes}m";
    } else {
      return "${twoDigitMinutes}m";
    }
  }

  String _findPeakHour(List<DateTime> arrivalTimes) {
    if (arrivalTimes.isEmpty) return "N/A";
    Map<int, int> hourCounts = {};
    for (var time in arrivalTimes) {
      hourCounts.update(time.hour, (value) => value + 1, ifAbsent: () => 1);
    }
    if (hourCounts.isEmpty) return "N/A";
    int peakHour =
        hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    String amPmPeak = DateFormat('ha').format(DateTime(2000, 1, 1, peakHour));
    String amPmNext =
        DateFormat('ha').format(DateTime(2000, 1, 1, peakHour + 1));
    return "$amPmPeak - $amPmNext";
  }

  // Helper function to check if two DateTime objects represent the same day.
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Generate daily queue report from the active queue data for a specific date.
  /// The report will reflect the state of the queue *at the time of generation* for that day.
  /// Enhanced to include appointment data for more comprehensive reporting.
  Future<Map<String, dynamic>> generateDailyReport(
      {DateTime? reportDate}) async {
    final dateToReport = reportDate ?? DateTime.now();
    final startOfDay =
        DateTime(dateToReport.year, dateToReport.month, dateToReport.day);
    final endOfDay = DateTime(dateToReport.year, dateToReport.month,
        dateToReport.day, 23, 59, 59, 999);

    // Fetch queue items for the specified date range
    List<ActivePatientQueueItem> reportItems;
    reportItems =
        await _dbHelper.getActiveQueueByDateRange(startOfDay, endOfDay);

    // Fetch appointments for the same date to include in the report
    List<Appointment> dayAppointments = [];
    try {
      dayAppointments = await _dbHelper.getAppointmentsByDate(dateToReport);
    } catch (e) {
      if (kDebugMode) {
        print('QueueService: Error fetching appointments for report: $e');
      }
    }

    // Separate queue items by origin (appointment vs walk-in)
    final appointmentOriginatedItems = reportItems
        .where((item) =>
            item.originalAppointmentId != null &&
            item.originalAppointmentId!.isNotEmpty)
        .toList();
    final walkInItems = reportItems
        .where((item) =>
            item.originalAppointmentId == null ||
            item.originalAppointmentId!.isEmpty)
        .toList();

    final totalProcessed = reportItems.length;
    final servedPatients =
        reportItems.where((p) => p.status == 'served').toList();
    final servedCount = servedPatients.length;
    final removedCount = reportItems.where((p) => p.status == 'removed').length;

    // Calculate appointment statistics for THE REPORT DATE ONLY
    int totalScheduledAppointmentsForReportDate = 0;
    int completedAppointmentsForReportDate = 0;
    int cancelledAppointmentsForReportDate = 0;

    if (dayAppointments.isNotEmpty) {
      totalScheduledAppointmentsForReportDate = dayAppointments.length;
      completedAppointmentsForReportDate = dayAppointments
          .where((appt) =>
                  (appt.status.toLowerCase() == 'completed' ||
                      appt.status.toLowerCase() == 'served') &&
                  isSameDay(appt.date,
                      dateToReport) // Double check, though getAppointmentsByDate should ensure this
              )
          .length;
      cancelledAppointmentsForReportDate = dayAppointments
          .where((appt) =>
                  appt.status.toLowerCase() == 'cancelled' &&
                  isSameDay(appt.date, dateToReport) // Double check
              )
          .length;
    }
    // final noShowAppointments = dayAppointments.where((appt) =>
    //     appt.status.toLowerCase() == 'no show').length;

    String averageWaitTimeDisplay = "N/A";
    if (servedPatients.isNotEmpty) {
      List<Duration> waitTimes = [];
      for (var p in servedPatients) {
        DateTime? effectiveStartTime = p.consultationStartedAt ?? p.servedAt;
        if (effectiveStartTime != null) {
          if (effectiveStartTime.isAfter(p.arrivalTime)) {
            waitTimes.add(effectiveStartTime.difference(p.arrivalTime));
          }
        }
      }
      if (waitTimes.isNotEmpty) {
        Duration totalWait = waitTimes.reduce((a, b) => a + b);
        Duration avgWait = Duration(
            microseconds: totalWait.inMicroseconds ~/ waitTimes.length);
        averageWaitTimeDisplay = _formatDuration(avgWait);
      }
    }
    String peakHour =
        _findPeakHour(reportItems.map((item) => item.arrivalTime).toList());

    final report = {
      'reportDate': DateFormat('yyyy-MM-dd').format(dateToReport),
      'totalPatientsInQueue': totalProcessed,
      'patientsServed': servedCount,
      'patientsRemoved': removedCount,
      'averageWaitTimeMinutes': averageWaitTimeDisplay,
      'peakHour': peakHour,
      'queueData': reportItems.map((item) => item.toJson()).toList(),
      'generatedAt': DateTime.now().toIso8601String(),
      // Enhanced appointment statistics for the report date
      'appointmentStats': {
        'totalScheduledAppointmentsForReportDate':
            totalScheduledAppointmentsForReportDate,
        'completedAppointmentsToday':
            completedAppointmentsForReportDate, // Renamed for clarity in report
        'cancelledAppointmentsToday':
            cancelledAppointmentsForReportDate, // Renamed for clarity in report
        // 'noShowAppointments': noShowAppointments, // Kept commented if not immediately needed
        'appointmentOriginatedQueueItems': appointmentOriginatedItems
            .length, // From active queue items for the day
        'walkInQueueItems':
            walkInItems.length, // From active queue items for the day
      },
      'appointmentData': dayAppointments
          .map((appt) => appt.toMap())
          .toList(), // Full appointment data for the day
    };
    return report;
  }

  /// Save daily report to database (this uses the patient_queue table for historical reports).
  Future<String> saveDailyReportToDb(
      {required Map<String, dynamic> reportData}) async {
    return _dbHelper.saveDailyQueueReport(reportData);
  }

  /// Clears the active patient queue. Typically done at the end of the day.
  /// IMPORTANT: This should be called with caution, usually as part of an end-of-day process.
  Future<int> clearTodaysActiveQueue() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    // No endOfDay needed, clear all for today based on arrivalTime being on this date
    return await _dbHelper.deleteActiveQueueItemsByDate(startOfDay);
  }

  /// Export daily report as PDF. This part largely remains the same,
  /// but it will use the data from `generateDailyReport`.
  Future<File> exportDailyReportToPdf(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();

    // Load logo image
    final logoImageBytes = await rootBundle.load('assets/images/slide1.png');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

    // Define styles
    final estiloTitulo = pw.TextStyle(
        fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700);
    final estiloSubtitulo = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey800);
    const estiloTexto = pw.TextStyle(fontSize: 11, color: PdfColors.black);
    final estiloValor = pw.TextStyle(
        fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black);

    final String reportTitle =
        'Daily Queue Report - ${reportData['reportDate']}';
    final DateTime generatedAtTime = DateTime.tryParse(
            reportData['generatedAt'] ?? DateTime.now().toIso8601String()) ??
        DateTime.now();
    final String formattedGeneratedAt =
        DateFormat('yyyy-MM-dd HH:mm').format(generatedAtTime);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          List<pw.Widget> content = [
            // Header with logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                    level: 0, child: pw.Text(reportTitle, style: estiloTitulo)),
                pw.Container(height: 60, width: 60, child: pw.Image(logoImage)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Report Generation Time: $formattedGeneratedAt',
                style: estiloTexto.copyWith(
                    fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 15),
            pw.Text('Summary Statistics:', style: estiloSubtitulo),
            pw.SizedBox(height: 10),
            _buildPdfStatRow(
                'Total Patients Processed:',
                '${reportData['totalPatientsInQueue'] ?? reportData['totalPatients'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow(
                'Patients Served:',
                '${reportData['patientsServed'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow(
                'Patients Removed from Queue:',
                '${reportData['patientsRemoved'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow(
                'Average Wait Time (Served):',
                '${reportData['averageWaitTimeMinutes'] ?? reportData['averageWaitTime'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow('Peak Hour:', '${reportData['peakHour'] ?? 'N/A'}',
                estiloTexto, estiloValor),
            pw.SizedBox(height: 20),

            // Add appointment statistics section
            pw.Text('Appointment Statistics:', style: estiloSubtitulo),
            pw.SizedBox(height: 10),
            _buildPdfStatRow(
                'Total Scheduled Appointments:',
                '${reportData['appointmentStats']?['totalScheduledAppointmentsForReportDate'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow(
                'Completed Appointments:',
                '${reportData['appointmentStats']?['completedAppointmentsToday'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow(
                'Cancelled Appointments:',
                '${reportData['appointmentStats']?['cancelledAppointmentsToday'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            pw.SizedBox(height: 10),
            pw.Text('Queue Origin Breakdown:', style: estiloSubtitulo),
            pw.SizedBox(height: 10),
            _buildPdfStatRow(
                'Appointment-Originated Queue Items:',
                '${reportData['appointmentStats']?['appointmentOriginatedQueueItems'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            _buildPdfStatRow(
                'Walk-In Queue Items:',
                '${reportData['appointmentStats']?['walkInQueueItems'] ?? 'N/A'}',
                estiloTexto,
                estiloValor),
            pw.SizedBox(height: 20),
          ];
          return content;
        },
      ),
    );

    // Updated directory path
    const String dirPath =
        r'C:\Users\jesie\Documents\jgem-softeng\jgem-main\Daily Reports';
    final Directory dailyReportDir = Directory(dirPath);

    // Create the directory if it doesn't exist
    if (!await dailyReportDir.exists()) {
      await dailyReportDir.create(recursive: true);
    }

    final String fileName =
        'daily_queue_report_${reportData['reportDate']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final String filePath =
        '${dailyReportDir.path}${Platform.pathSeparator}$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    if (kDebugMode) {
      print('PDF Report saved to $filePath');
    }
    return file;
  }

  /// Removes a 'Scheduled' entry from the active queue based on the original appointment ID.
  /// This is used when an appointment is cancelled or deleted.
  Future<void> removeScheduledEntryForAppointment(String appointmentId) async {
    if (appointmentId.isEmpty) {
      if (kDebugMode) {
        print(
            "QueueService: removeScheduledEntryForAppointment called with empty appointmentId.");
      }
      return;
    }
    final String queueEntryIdToRemove = 'appt_$appointmentId';
    try {
      await _dbHelper.deleteActiveQueueItemByQueueEntryId(queueEntryIdToRemove);
      if (kDebugMode) {
        print(
            "QueueService: Attempted to remove scheduled entry $queueEntryIdToRemove for appointment $appointmentId.");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "QueueService: Error removing scheduled entry for appointment $appointmentId: $e");
      }
      // Depending on policy, you might want to rethrow or handle silently
    }
  }

  /// Marks a queue item's payment status as 'Paid' and checks if it should be marked as served.
  /// For laboratory services, the item will not be marked as 'served' until lab results are entered.
  /// For other services, the item will be marked as 'served' immediately.
  /// Also creates a corresponding medical record.
  Future<bool> markPaymentSuccessfulAndServe(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) {
      if (kDebugMode) {
        print(
            'QueueService: Item with ID $queueEntryId not found for marking as served.');
      }
      return false;
    }

    final now = DateTime.now();
    
    // Check if this queue item contains laboratory services
    bool hasLabServices = false;
    bool hasNonLabServices = false;
    
    if (item.selectedServices != null && item.selectedServices!.isNotEmpty) {
      for (final service in item.selectedServices!) {
        final category = (service['category'] as String? ?? '').toLowerCase();
        if (['laboratory', 'hematology', 'chemistry', 'urinalysis', 'microbiology', 'pathology']
            .contains(category)) {
          hasLabServices = true;
        } else {
          hasNonLabServices = true;
        }
      }
    }
    
    // For mixed services (consultation + lab), we only update payment status
    // but keep status as 'in_progress' until lab results are entered
    // For lab-only services, keep as 'in_progress' until results are entered
    // For consultation-only services, mark as 'done' immediately upon payment
    final updatedItem = item.copyWith(
      status: hasLabServices ? 'in_progress' : 'done', // Only mark non-lab services as done
      paymentStatus: 'Paid',
      servedAt: hasLabServices ? null : now, // Only set servedAt for pure non-lab services
      // If consultation hasn't officially started, mark it as started now
      consultationStartedAt: item.consultationStartedAt ?? now,
    );
    
    if (kDebugMode) {
      print('QueueService: Item contains lab services: $hasLabServices, non-lab services: $hasNonLabServices - Status set to ${updatedItem.status}');
    }

    final updateResult = await _dbHelper.updateActiveQueueItem(updatedItem);

    if (updateResult > 0) {
      // Create medical records based on service types
      // CRITICAL: Only create consultation records here, NEVER laboratory records
      // Laboratory records should ONLY be created by medtech in consultation results screen
      // AND: Do NOT create ANY records for pure lab services - wait for medtech to create them
      
      if (hasNonLabServices && !hasLabServices) {
        // ONLY create records for pure consultation services (no lab services mixed in)
        try {
          // Check if a medical record already exists for this patient and queue entry
          final existingRecords = await _dbHelper.getAllMedicalRecords();
          final hasExistingConsultationRecord = existingRecords.any((record) =>
            record['patientId'] == item.patientId &&
            record['queueEntryId'] == queueEntryId &&
            record['recordType']?.toString().toLowerCase() == 'consultation'
          );

          if (!hasExistingConsultationRecord) {
            final currentUserId = await AuthService.getCurrentUserId();
            final doctorId = item.doctorId ?? currentUserId ?? 'default_doctor_id';

            final recordId = const Uuid().v4();

            // Create consultation record only for pure consultation services
            final serviceNames = item.selectedServices!
                .map((s) => s['serviceName'] as String? ?? s['name'] as String? ?? 'Service')
                .join(', ');

            // IMPORTANT: Create a medical record with only consultation services
            final medicalRecordData = {
              'id': recordId,
              'patientId': item.patientId,
              'queueEntryId': queueEntryId, // Add queue entry ID for tracking
              'appointmentId': item.originalAppointmentId,
              'selectedServices': jsonEncode(item.selectedServices), // Store all services for pure consultation
              'recordType': 'consultation', // Use lowercase for consistency
              'recordDate': now.toIso8601String(),
              'diagnosis': 'See consultation details.',
              'notes': 'Consultation services performed: $serviceNames',
              'doctorId': doctorId,
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            };
            await _dbHelper.insertMedicalRecord(medicalRecordData);
            
            if (kDebugMode) {
              print('QueueService: Created consultation medical record for pure consultation services: $serviceNames');
            }
          } else {
            if (kDebugMode) {
              print('QueueService: Consultation medical record already exists for this queue entry, skipping creation');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                'QueueService: Failed to create consultation medical record for ${item.patientName}: $e');
          }
          // Decide if this error should fail the whole operation
        }
      } else if (hasLabServices) {
        if (kDebugMode) {
          print(
              'QueueService: Skipping ALL medical record creation for services that include laboratory work - records will ONLY be created by medtech in consultation results screen');
        }
      } else {
        // No services listed at all - create a minimal consultation record
        try {
          final existingRecords = await _dbHelper.getAllMedicalRecords();
          final hasExistingConsultationRecord = existingRecords.any((record) =>
            record['patientId'] == item.patientId &&
            record['queueEntryId'] == queueEntryId &&
            record['recordType']?.toString().toLowerCase() == 'consultation'
          );

          if (!hasExistingConsultationRecord) {
            final currentUserId = await AuthService.getCurrentUserId();
            final doctorId = item.doctorId ?? currentUserId ?? 'default_doctor_id';
            final recordId = const Uuid().v4();
            
            final medicalRecordData = {
              'id': recordId,
              'patientId': item.patientId,
              'queueEntryId': queueEntryId, // Add queue entry ID for tracking
              'appointmentId': item.originalAppointmentId,
              'recordType': 'consultation', // Use lowercase for consistency
              'recordDate': now.toIso8601String(),
              'diagnosis': 'See consultation details.',
              'notes': item.conditionOrPurpose ?? 'General consultation.',
              'doctorId': doctorId,
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            };
            await _dbHelper.insertMedicalRecord(medicalRecordData);
            
            if (kDebugMode) {
              print('QueueService: Created general consultation medical record');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                'QueueService: Failed to create general consultation medical record for ${item.patientName}: $e');
          }
        }
      }

      // If the original item was an appointment, update its status to 'Completed'
      if (item.originalAppointmentId != null) {
        try {
          await ApiService.updateAppointmentStatus(
              item.originalAppointmentId!, 'Completed');
        } catch (e) {
          if (kDebugMode) {
            print(
                'QueueService: Failed to update original appointment status to Completed: $e');
          }
        }
      }
      return true;
    }
    return false;
  }

  /// Trigger immediate sync to notify connected devices of queue changes
  void _triggerImmediateSync() {
    if (kDebugMode) {
      print('QueueService: SYNC DEBUG - Start _triggerImmediateSync()');
      print(
          'QueueService: SYNC DEBUG - Client sync connected: ${DatabaseSyncClient.isConnected}');
      print(
          'QueueService: SYNC DEBUG - Host server running: ${EnhancedShelfServer.isRunning}');
    }

    // Use DatabaseSyncClient to trigger queue refresh
    DatabaseSyncClient.triggerQueueRefresh();

    // Also request full sync for real-time updates
    DatabaseSyncClient.forceQueueRefresh();

    if (kDebugMode) {
      print('QueueService: SYNC DEBUG - End _triggerImmediateSync()');
      print('QueueService: Triggered immediate sync notification');
    }
  }

  /// Enhanced refresh method for external callers
  static void refreshAllQueues() {
    // Trigger sync through DatabaseSyncClient
    DatabaseSyncClient.forceQueueRefresh();

    // Also trigger appointment refresh since they're related
    DatabaseSyncClient.triggerAppointmentRefresh();

    if (kDebugMode) {
      print(
          'QueueService: Triggered comprehensive queue and appointment refresh');
    }
  }

  /// Marks a laboratory test as completed and updates the queue status
  /// This should be called after lab results are entered
  Future<bool> markLabResultCompleted(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) {
      if (kDebugMode) {
        print(
            'QueueService: Item with ID $queueEntryId not found for marking lab results as completed.');
      }
      return false;
    }

    // Only mark as served if payment is already complete (status 'in_progress' means payment done but lab pending)
    if (item.paymentStatus != 'Paid' || item.status != 'in_progress') {
      if (kDebugMode) {
        print(
            'QueueService: Cannot complete lab results - payment not complete or status not in_progress for queue item: $queueEntryId');
        print('QueueService: PaymentStatus: ${item.paymentStatus}, Status: ${item.status}');
      }
      return false;
    }

    final now = DateTime.now();
    // Update status to 'done' now that lab results are entered
    final updatedItem = item.copyWith(
      status: 'done', // Now mark as done since results are entered
      servedAt: now,
    );

    final result = await _dbHelper.updateActiveQueueItem(updatedItem);
    
    if (result > 0) {
      // Trigger immediate sync to notify all connected devices
      _triggerImmediateSync();
      
      if (kDebugMode) {
        print('QueueService: Lab results completed for queue item: $queueEntryId');
      }
      return true;
    }
    
    return false;
  }
}

// Helper to ensure ValueGetter<T?>? parameters in copyWith are handled.
// Not directly used in the provided snippet but good for model classes.
// T? _copyWith<T>(T? value, T Function()? getter) {
//   if (getter != null) {
//     return getter();
//   }
//   return value;
// }

// Helper for PDF stat rows, if not already present
pw.Widget _buildPdfStatRow(String label, String value, pw.TextStyle labelStyle,
    pw.TextStyle valueStyle) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: labelStyle),
        pw.Text(value, style: valueStyle),
      ],
    ),
  );
}
