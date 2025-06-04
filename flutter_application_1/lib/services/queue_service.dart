import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'database_helper.dart';
import '../models/active_patient_queue_item.dart';
import '../models/appointment.dart';
import 'auth_service.dart';
import 'dart:math';
import 'api_service.dart';
import 'dart:convert';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  /// Get current active queue items from the database.
  /// By default, fetches 'waiting' and 'in_consultation' statuses.
  Future<List<ActivePatientQueueItem>> getActiveQueueItems(
      {List<String>? statuses}) async {
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
      print('QueueService: Error checking if patient is active in queue: $e');
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
    final currentUserId = await _authService.getCurrentUserId();
    final now = DateTime.now();
    String queueEntryId = patientData['queueId']?.toString() ??
        'qentry-${now.millisecondsSinceEpoch}-${Random().nextInt(9999)}';

    final nextQueueNumber = await _getNextQueueNumber();

    final newItem = ActivePatientQueueItem(
      queueEntryId: queueEntryId,
      patientId: patientData['patientId'] as String?,
      patientName: patientData['name'] as String,
      arrivalTime:
          DateTime.tryParse(patientData['arrivalTime']?.toString() ?? '') ??
              now,
      queueNumber: nextQueueNumber,
      gender: patientData['gender'] as String?,
      age: patientData['age'] is int
          ? patientData['age']
          : (patientData['age'] is String
              ? int.tryParse(patientData['age']!)
              : null),
      conditionOrPurpose: patientData['condition'] as String?,
      status: patientData['status']?.toString() ?? 'waiting',
      createdAt:
          DateTime.tryParse(patientData['addedTime']?.toString() ?? '') ?? now,
      addedByUserId: currentUserId,
      selectedServices:
          patientData['selectedServices'] as List<Map<String, dynamic>>?,
      totalPrice: patientData['totalPrice'] as double?,
    );

    return await _dbHelper.addToActiveQueue(newItem);
  }

  /// Adds a pre-constructed ActivePatientQueueItem object to the active queue.
  /// This is useful for activating scheduled appointments.
  Future<bool> addPatientToQueue(ActivePatientQueueItem queueItem) async {
    try {
      // The DatabaseHelper.addToActiveQueue method already handles the DB insertion.
      // It returns the item, so we assume success if no exception.
      await _dbHelper.addToActiveQueue(queueItem);
      print('QueueService: Patient ${queueItem.patientName} (ID: ${queueItem.queueEntryId}) added to active queue via addPatientToQueue.');
      return true; // Return true on success
    } catch (e) {
      print("QueueService: Error in addPatientToQueue for ${queueItem.patientName}: $e");
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
        .map((item) => item.queueNumber ?? 0)
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

    if (result > 0 && updatedItem.originalAppointmentId != null) {
      try {
        await ApiService.updateAppointmentStatus(updatedItem.originalAppointmentId!, 'Cancelled');
        print('QueueService: Original appointment ${updatedItem.originalAppointmentId} status updated to Cancelled due to queue removal.');
      } catch (e) {
        print('QueueService: Error updating original appointment ${updatedItem.originalAppointmentId} to Cancelled: $e');
        // Decide if this error should affect the return value of removeFromQueue
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
    final allQueueItems = await getActiveQueueItems(statuses: null);
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
  }) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) {
      print(
          'QueueService: Item with ID $queueEntryId not found for status update.');
      return false;
    }

    ActivePatientQueueItem updatedItem;
    final now = DateTime.now();

    // Create a copy with the new status first
    updatedItem = item.copyWith(status: newStatus);

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
        print(
            'QueueService: Successfully updated patient $queueEntryId to status $newStatus');

        // ADDED: Propagate to original Appointment if exists
        if (updatedItem.originalAppointmentId != null) {
          try {
            Appointment? originalAppointment = await _dbHelper.appointmentDbService.getAppointmentById(updatedItem.originalAppointmentId!);
            if (originalAppointment != null) {
              Appointment updatedOriginalAppointment = originalAppointment.copyWith(
                status: newStatus == 'served' ? 'Completed' : (newStatus == 'in_consultation' ? 'In Consultation' : originalAppointment.status), // Also update appointment status
                consultationStartedAt: updatedItem.consultationStartedAt ?? originalAppointment.consultationStartedAt,
                servedAt: updatedItem.servedAt ?? originalAppointment.servedAt,
                // selectedServices, totalPrice, paymentStatus are more tied to payment/finalization
              );
              await _dbHelper.appointmentDbService.updateAppointment(updatedOriginalAppointment);
              print('QueueService: Updated original appointment ${originalAppointment.id} due to queue status change.');
            }
          } catch (e) {
            print('QueueService: Error updating original appointment after queue status change: $e');
          }
        }
        // END ADDED
        return true;
      } else {
        print(
            'QueueService: Failed to update patient $queueEntryId status in DB.');
        return false;
      }
    } catch (e) {
      print(
          "QueueService: Error in updatePatientStatusInQueue for $queueEntryId: $e");
      return false;
    }
  }

  /// Mark patient as served in the active queue.
  Future<bool> markPatientAsServed(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null || item.status == 'removed') return false;

    final now = DateTime.now();
    ActivePatientQueueItem updatedItem;

    if (item.consultationStartedAt == null) {
      updatedItem = item.copyWith(
          status: 'served', servedAt: now, consultationStartedAt: now);
    } else {
      updatedItem = item.copyWith(status: 'served', servedAt: now);
    }
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);

    if (result > 0 && updatedItem.originalAppointmentId != null) {
      try {
        await ApiService.updateAppointmentStatus(updatedItem.originalAppointmentId!, 'Completed');
        print('QueueService: Original appointment ${updatedItem.originalAppointmentId} status updated to Completed.');
      } catch (e) {
        print('QueueService: Error updating original appointment ${updatedItem.originalAppointmentId} to Completed: $e');
        // Decide if this error should affect the return value of markPatientAsServed
      }
    }
    return result > 0;
  }

  /// Mark patient as 'in_consultation' in the active queue.
  Future<bool> markPatientAsInConsultation(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null || item.status == 'removed' || item.status == 'served')
      return false;

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

  /// Generate daily queue report from the active queue data for a specific date.
  /// The report will reflect the state of the queue *at the time of generation* for that day.
  Future<Map<String, dynamic>> generateDailyReport(
      {DateTime? reportDate}) async {
    final dateToReport = reportDate ?? DateTime.now();
    final startOfDay =
        DateTime(dateToReport.year, dateToReport.month, dateToReport.day);
    final endOfDay = DateTime(dateToReport.year, dateToReport.month,
        dateToReport.day, 23, 59, 59, 999);

    List<ActivePatientQueueItem> reportItems;
    // Always fetch from the DB for the specified date range to ensure accuracy for past dates
    reportItems =
        await _dbHelper.getActiveQueueByDateRange(startOfDay, endOfDay);

    final totalProcessed = reportItems.length;
    final servedPatients =
        reportItems.where((p) => p.status == 'served').toList();
    final servedCount = servedPatients.length;
    final removedCount = reportItems.where((p) => p.status == 'removed').length;

    String averageWaitTimeDisplay = "N/A";
    if (servedPatients.isNotEmpty) {
      List<Duration> waitTimes = [];
      for (var p in servedPatients) {
        DateTime? effectiveStartTime = p.consultationStartedAt ?? p.servedAt;
        if (p.arrivalTime != null && effectiveStartTime != null) {
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
    };
    return report;
  }

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
    final estiloTexto = pw.TextStyle(fontSize: 11, color: PdfColors.black);
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
          ];
          return content;
        },
      ),
    );

    // Updated directory path
    final String dirPath =
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
    print('PDF Report saved to $filePath');
    return file;
  }

  /// Removes a 'Scheduled' entry from the active queue based on the original appointment ID.
  /// This is used when an appointment is cancelled or deleted.
  Future<void> removeScheduledEntryForAppointment(String appointmentId) async {
    if (appointmentId.isEmpty) {
      print("QueueService: removeScheduledEntryForAppointment called with empty appointmentId.");
      return;
    }
    final String queueEntryIdToRemove = 'appt_$appointmentId';
    try {
      await _dbHelper.deleteActiveQueueItemByQueueEntryId(queueEntryIdToRemove);
      print("QueueService: Attempted to remove scheduled entry $queueEntryIdToRemove for appointment $appointmentId.");
    } catch (e) {
      print("QueueService: Error removing scheduled entry for appointment $appointmentId: $e");
      // Depending on policy, you might want to rethrow or handle silently
    }
  }

  /// Marks a patient as payment processed, updates status to Served, and original appointment to Completed.
  Future<bool> markPaymentSuccessfulAndServe(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) {
      print('QueueService: Item $queueEntryId not found for payment processing.');
      return false;
    }

    if (item.status.toLowerCase() != 'in_consultation') {
      print('QueueService: Item $queueEntryId is not In Consultation. Current status: ${item.status}. Cannot process payment unless in consultation.');
      // Optionally show a message to the user or handle differently
      // For now, just preventing the update if not 'in_consultation'
      // Consider if 'waiting' patients should be allowed to pay and then be set to 'in_consultation' or 'served'
      return false; 
    }

    final now = DateTime.now();
    final ActivePatientQueueItem updatedItem = item.copyWith(
      status: 'served',
      paymentStatus: 'Paid',
      servedAt: now,
      // If consultationStartedAt is somehow null here, set it to now as well.
      consultationStartedAt: item.consultationStartedAt ?? now,
    );

    final result = await _dbHelper.updateActiveQueueItem(updatedItem);

    if (result > 0) {
      print('QueueService: Item $queueEntryId marked as Paid and Served.');
      if (updatedItem.originalAppointmentId != null) {
        try {
          // Fetch the original appointment
          Appointment? originalAppointment = await _dbHelper.appointmentDbService.getAppointmentById(updatedItem.originalAppointmentId!);
          if (originalAppointment != null) {
            // Update it with the new details
            Appointment updatedOriginalAppointment = originalAppointment.copyWith(
              status: 'Completed',
              paymentStatus: 'Paid',
              servedAt: updatedItem.servedAt,
              consultationStartedAt: updatedItem.consultationStartedAt ?? originalAppointment.consultationStartedAt,
              selectedServices: updatedItem.selectedServices,
              totalPrice: updatedItem.totalPrice ?? originalAppointment.totalPrice,
            );
            await _dbHelper.appointmentDbService.updateAppointment(updatedOriginalAppointment);
            print('QueueService: Original appointment ${updatedItem.originalAppointmentId} updated to Completed and payment details synced.');
          } else {
            print('QueueService: Original appointment ${updatedItem.originalAppointmentId} not found for updating after payment.');
          }
        } catch (e) {
          print('QueueService: Error updating original appointment ${updatedItem.originalAppointmentId} after payment: $e');
          // Decide if this error should affect the return value
        }
      }
      return true;
    } else {
      print('QueueService: Failed to update item $queueEntryId after payment.');
      return false;
    }
  }
}

// Helper to ensure ValueGetter<T?>? parameters in copyWith are handled.
// Not directly used in the provided snippet but good for model classes.
T? _copyWith<T>(T? value, T Function()? getter) {
  if (getter != null) {
    return getter();
  }
  return value;
}

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
