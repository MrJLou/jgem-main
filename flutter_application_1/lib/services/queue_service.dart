import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'database_helper.dart';
import '../models/active_patient_queue_item.dart';
import '../models/appointment.dart';
import 'auth_service.dart';
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
  /// By default, fetches 'waiting' and 'in_consultation' statuses.
  Future<List<ActivePatientQueueItem>> getActiveQueueItems(
      {List<String> statuses = const ['waiting', 'in_consultation']}) async {
    return await _dbHelper.getActiveQueue(statuses: statuses);
  }

  /// Checks if a patient is already in the active queue with 'waiting' or 'in_consultation' status.
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
    final addedItem = await _dbHelper.addToActiveQueue(newItem);
    
    // Log successful queue addition for debugging
    if (kDebugMode) {
      print('QueueService: Successfully added ${addedItem.patientName} to queue (ID: ${addedItem.queueEntryId}, Queue #${addedItem.queueNumber})');
      print('QueueService: Queue addition should trigger real-time sync to connected devices');
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
        await getActiveQueueItems(statuses: ['waiting', 'in_consultation']);
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
              item.status == 'waiting' || item.status == 'in_consultation')
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
      case 'in_consultation':
        // If already in consultation, keep original start time, otherwise set to now or provided
        updatedItem = updatedItem.copyWith(
          consultationStartedAt: item.status == 'in_consultation'
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

        // If the new status is 'served', create a medical record for history.
        if (newStatus.toLowerCase() == 'served') {
          try {
            await _createMedicalRecordForServedPatient(updatedItem);
          } catch (e) {
            if (kDebugMode) {
              print(
                  'QueueService: Error creating medical record for served patient $queueEntryId: $e');
            }
            // Decide if this error should affect the overall success of the operation.
            // For now, we log it but don't return false, as the primary status update succeeded.
          }
        }

      // NO LONGER CREATING APPOINTMENT RECORDS FOR WALK-IN PATIENTS
      // Queue and appointment systems are now completely separate
      // Walk-in patients exist only in the queue system, not in appointments
      
      if (kDebugMode) {
        print('QueueService: Status updated for ${updatedItem.isWalkIn ? "walk-in" : "scheduled"} patient ${updatedItem.patientName} to $newStatus');
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
                    : (newStatus == 'in_consultation'
                        ? 'In Consultation'
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

  /// Mark patient as 'in_consultation' in the active queue.
  Future<bool> markPatientAsInConsultation(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null || item.status == 'removed' || item.status == 'served') {
      return false;
    }

    final updatedItem = item.copyWith(
        status: 'in_consultation',
        consultationStartedAt: DateTime.now(),
        servedAt: null);
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);
    return result > 0;
  }

  /// Mark patient as ongoing (in consultation).
  Future<bool> markPatientAsOngoing(String queueEntryId) async {
    return await updatePatientStatusInQueue(queueEntryId, 'in_consultation');
  }

  /// Mark patient as done.
  Future<bool> markPatientAsDone(String queueEntryId) async {
    return await updatePatientStatusInQueue(queueEntryId, 'done');
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
            pw.Header(
                level: 0, child: pw.Text(reportTitle, style: estiloTitulo)),
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

  /// Marks a queue item as 'served' and its payment status as 'Paid'.
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
    // Update status to 'served' and paymentStatus to 'Paid'
    final updatedItem = item.copyWith(
      status: 'done', // Use 'done' to signify completion
      paymentStatus: 'Paid',
      servedAt: now,
      // If consultation hasn't officially started, mark it as started now
      consultationStartedAt: item.consultationStartedAt ?? now,
    );

    final updateResult = await _dbHelper.updateActiveQueueItem(updatedItem);

    if (updateResult > 0) {
      // Logic to create medical record(s) based on services
      try {
        final currentUserId = await AuthService.getCurrentUserId();
        final doctorId = item.doctorId ?? currentUserId ?? 'default_doctor_id';

        if (item.selectedServices != null &&
            item.selectedServices!.isNotEmpty) {
          final recordId = const Uuid().v4();

          // Determine consolidated record type
          final bool isConsultation = item.selectedServices!.any((s) =>
              (s['category'] as String? ?? '').toLowerCase() == 'consultation');
          final String recordType =
              isConsultation ? 'Consultation' : 'Laboratory';

          // Consolidate notes from all services
          final serviceNames = item.selectedServices!
              .map((s) => s['serviceName'] as String? ?? 'Service')
              .join(', ');
          final notes = 'Services performed: $serviceNames';

          // Create a single medical record with all services
          final medicalRecordData = {
            'id': recordId,
            'patientId': item.patientId,
            'appointmentId': item.originalAppointmentId,
            'selectedServices': jsonEncode(
                item.selectedServices), // Store all services as a JSON string
            'recordType': recordType,
            'recordDate': now.toIso8601String(),
            'diagnosis': 'See consultation details.',
            'notes': notes,
            'doctorId': doctorId,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          };
          await _dbHelper.insertMedicalRecord(medicalRecordData);
        } else {
          // Fallback: if no services are listed, create a general consultation record
          final recordId = const Uuid().v4();
          final medicalRecordData = {
            'id': recordId,
            'patientId': item.patientId,
            'appointmentId': item.originalAppointmentId,
            'recordType': 'Consultation', // Default type
            'recordDate': now.toIso8601String(),
            'diagnosis': 'See consultation details.',
            'notes': item.conditionOrPurpose ?? 'General consultation.',
            'doctorId': doctorId,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          };
          await _dbHelper.insertMedicalRecord(medicalRecordData);
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              'QueueService: Failed to create medical record for ${item.patientName}: $e');
        }
        // Decide if this error should fail the whole operation
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

  Future<void> _createMedicalRecordForServedPatient(
      ActivePatientQueueItem item) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    // Prepare the notes from the services provided
    String notes = 'Consultation for: ${item.conditionOrPurpose}';

    final medicalRecordData = {
      'id': const Uuid().v4(), // Generate a unique ID for the record
      'patientId': item.patientId,
      'doctorId': item.doctorId,
      'recordDate': now.toIso8601String(),
      'recordType': 'Consultation', // This is the key for the history screen
      'notes': notes,
      'diagnosis': 'See consultation details.', // Placeholder
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await db.insert('medical_records', medicalRecordData);
    if (kDebugMode) {
      print(
          'Successfully created a medical record for served patient: ${item.patientName}');
    }
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
