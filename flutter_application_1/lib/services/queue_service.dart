import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'database_helper.dart';
import '../models/active_patient_queue_item.dart';
import '../models/user.dart';
import 'auth_service.dart';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  /// Get current active queue items from the database.
  /// By default, fetches 'waiting' and 'in_consultation' statuses.
  Future<List<ActivePatientQueueItem>> getActiveQueueItems(
      {List<String> statuses = const ['waiting', 'in_consultation']}) async {
    return await _dbHelper.getActiveQueue(statuses: statuses);
  }

  /// Add patient to the active queue in the database.
  Future<ActivePatientQueueItem> addToQueue(
      Map<String, dynamic> patientData) async {
    final currentUserId = await _authService.getCurrentUserId();
    final now = DateTime.now();
    String queueEntryId = patientData['queueId']?.toString() ??
        'qentry-${now.millisecondsSinceEpoch}';

    final newItem = ActivePatientQueueItem(
      queueEntryId: queueEntryId,
      patientId: patientData['patientId'] as String?,
      patientName: patientData['name'] as String,
      arrivalTime:
          DateTime.tryParse(patientData['arrivalTime']?.toString() ?? '') ??
              now,
      gender: patientData['gender'] as String?,
      age: patientData['age'] is int
          ? patientData['age']
          : (patientData['age'] is String
              ? int.tryParse(patientData['age'])
              : null),
      conditionOrPurpose: patientData['condition'] as String?,
      status: patientData['status']?.toString() ?? 'waiting',
      createdAt:
          DateTime.tryParse(patientData['addedTime']?.toString() ?? '') ?? now,
      addedByUserId: currentUserId,
    );

    return await _dbHelper.addToActiveQueue(newItem);
  }

  /// Remove patient from active queue (mark as 'removed').
  Future<bool> removeFromQueue(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) return false;

    final updatedItem =
        item.copyWith(status: 'removed', removedAt: () => DateTime.now());
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);
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
    final activeQueue = await getActiveQueueItems(
        statuses: ['waiting', 'in_consultation', 'served', 'removed']);
    if (searchTerm.trim().isEmpty) {
      return activeQueue
          .where((item) =>
              item.status == 'waiting' || item.status == 'in_consultation')
          .toList();
    }
    final lowerSearchTerm = searchTerm.toLowerCase().trim();

    return activeQueue.where((item) {
      final nameMatches =
          item.patientName.toLowerCase().contains(lowerSearchTerm);
      final idMatches =
          item.patientId?.toLowerCase().contains(lowerSearchTerm) ?? false;
      return nameMatches || idMatches;
    }).toList();
  }

  /// Mark patient as served in the active queue.
  Future<bool> markPatientAsServed(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) return false;

    final updatedItem =
        item.copyWith(status: 'served', servedAt: () => DateTime.now());
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);
    return result > 0;
  }

  /// Mark patient as 'in_consultation' in the active queue.
  Future<bool> markPatientAsInConsultation(String queueEntryId) async {
    final item = await _dbHelper.getActiveQueueItem(queueEntryId);
    if (item == null) return false;

    final updatedItem = item.copyWith(
        status: 'in_consultation', consultationStartedAt: () => DateTime.now());
    final result = await _dbHelper.updateActiveQueueItem(updatedItem);
    return result > 0;
  }

  /// Generate daily queue report from the active queue data for today.
  Future<Map<String, dynamic>> generateDailyReport() async {
    final allTodayQueueItems = await _dbHelper.getActiveQueue(
        statuses: ['waiting', 'in_consultation', 'served', 'removed']);

    final totalPatients = allTodayQueueItems.length;
    final servedPatientsCount =
        allTodayQueueItems.where((p) => p.status == 'served').length;
    final waitingPatientsCount =
        allTodayQueueItems.where((p) => p.status == 'waiting').length;
    final removedPatientsCount =
        allTodayQueueItems.where((p) => p.status == 'removed').length;
    final inConsultationPatientsCount =
        allTodayQueueItems.where((p) => p.status == 'in_consultation').length;

    String averageWaitTime = await _calculateAverageWaitTime(allTodayQueueItems
        .where((p) => p.status == 'served' && p.servedAt != null)
        .toList());
    String peakHour = _findPeakHour(allTodayQueueItems);

    final queueDataForReport =
        allTodayQueueItems.map((item) => item.toJson()).toList();

    return {
      'reportDate': DateTime.now().toIso8601String().split('T')[0],
      'totalPatients': totalPatients,
      'patientsServed': servedPatientsCount,
      'patientsWaiting': waitingPatientsCount,
      'patientsInConsultation': inConsultationPatientsCount,
      'patientsRemoved': removedPatientsCount,
      'averageWaitTime': averageWaitTime,
      'peakHour': peakHour,
      'queueData': queueDataForReport,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Save daily report to database (this uses the patient_queue table for historical reports).
  Future<String> saveDailyReportToDb({Map<String, dynamic>? reportData}) async {
    final report = reportData ?? await generateDailyReport();
    return await _dbHelper.saveDailyQueueReport(report);
  }

  /// Clears the active patient queue. Typically done at the end of the day.
  Future<int> clearTodaysActiveQueue() async {
    return await _dbHelper.clearActiveQueue();
  }

  // --- Helper methods for report generation (can be adapted) ---

  Future<String> _calculateAverageWaitTime(
      List<ActivePatientQueueItem> servedItemsWithTimestamp) async {
    if (servedItemsWithTimestamp.isEmpty) return 'N/A';

    double totalWaitSeconds = 0;

    for (var item in servedItemsWithTimestamp) {
      if (item.servedAt != null) {
        totalWaitSeconds +=
            item.servedAt!.difference(item.arrivalTime).inSeconds;
      }
    }

    if (servedItemsWithTimestamp.isEmpty)
      return 'N/A (No fully served patients with timestamps)';

    final averageSeconds = totalWaitSeconds / servedItemsWithTimestamp.length;
    final minutes = (averageSeconds / 60).floor();
    final seconds = (averageSeconds % 60).round();
    return '${minutes}m ${seconds}s';
  }

  String _findPeakHour(List<ActivePatientQueueItem> items) {
    if (items.isEmpty) return 'N/A';
    Map<int, int> hourCounts = {};
    for (var item in items) {
      final hour = item.arrivalTime.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    if (hourCounts.isEmpty) return 'N/A';
    final peakHourEntry =
        hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final peakHour = peakHourEntry.key;
    return '${peakHour.toString().padLeft(2, '0')}:00 - ${(peakHour + 1).toString().padLeft(2, '0')}:00 (${peakHourEntry.value} entries)';
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  /// Export daily report as PDF. This part largely remains the same,
  /// but it will use the data from `generateDailyReport`.
  Future<String> exportDailyReportToPdf(
      Map<String, dynamic> reportDataToExport) async {
    final report = reportDataToExport;

    final pdf = pw.Document();

    List<Map<String, dynamic>> queueDetailsMap =
        List<Map<String, dynamic>>.from(report['queueData'] ?? []);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Daily Queue Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Report Date: ${report['reportDate']}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text(
                    'Generated At: ${_formatDateTime(report['generatedAt'])}'),
                pw.SizedBox(height: 8),
                pw.Text(
                    'Total Patients in Queue Today: ${report['totalPatients']}'),
                pw.Text('Patients Served: ${report['patientsServed']}'),
                pw.Text(
                    'Patients Currently Waiting: ${report['patientsWaiting']}'),
                pw.Text(
                    'Patients In Consultation: ${report['patientsInConsultation']}'),
                pw.Text(
                    'Patients Removed from Queue: ${report['patientsRemoved']}'),
                pw.Text(
                    'Average Wait Time (Served): ${report['averageWaitTime']}'),
                pw.Text('Peak Hour: ${report['peakHour']}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Queue Entry Details:',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              'Name',
              'Patient ID',
              'Arrival',
              'Condition',
              'Status',
              'Added By',
              'Served At'
            ],
            data: queueDetailsMap.map((item) {
              return [
                item['patientName'] ?? 'N/A',
                item['patientId'] ?? 'N/A',
                _formatDateTime(item['arrivalTime'] ?? ''),
                item['conditionOrPurpose'] ?? 'N/A',
                item['status'] ?? 'N/A',
                item['addedByUserId'] ?? 'System',
                _formatDateTime(item['servedAt']),
              ];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(2.2),
              4: const pw.FlexColumnWidth(1.3),
              5: const pw.FlexColumnWidth(1.3),
              6: const pw.FlexColumnWidth(1.8),
            },
          ),
        ],
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final String filePath =
        '${outputDir.path}/daily_queue_report_${report['reportDate']}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }
}

// Example of how you might fetch User for addedBy display name (conceptual)
// Future<String> _getUserFullName(String? userId) async {
//   if (userId == null) return 'System/N/A';
//   // Assuming you have a method in DatabaseHelper or AuthService to get user by ID
//   final user = await DatabaseHelper().getUserById(userId); // Fictional method
//   return user?.fullName ?? userId; // Fallback to ID if name not found
// }
