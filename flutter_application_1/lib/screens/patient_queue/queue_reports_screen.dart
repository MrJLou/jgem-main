import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_application_1/models/active_patient_queue_item.dart'; // Not directly used for instantiation here
import 'package:intl/intl.dart'; // For date formatting
import 'dart:convert'; // For jsonDecode

import '../../services/queue_service.dart';
import '../../services/database_helper.dart';

class QueueReportsScreen extends StatefulWidget {
  const QueueReportsScreen({super.key});

  @override
  QueueReportsScreenState createState() => QueueReportsScreenState();
}

class QueueReportsScreenState extends State<QueueReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  DateTime _selectedDateForNewReport =
      DateTime.now(); // For generating report for a specific date

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _reportsFuture = _dbHelper.getDailyQueueReports();
    });
  }

  Future<void> _pickDateForReport(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateForNewReport,
      firstDate: DateTime(2020), // Arbitrary past date
      lastDate: DateTime.now(), // Can only generate for today or past
    );
    if (picked != null && picked != _selectedDateForNewReport) {
      setState(() {
        _selectedDateForNewReport = picked;
      });
      // Optionally, immediately try to generate report for this picked date
      // _generateAndSaveReportForDate(picked);
    }
  }

  Future<void> _generateAndSaveReportForDate(DateTime dateForReport) async {
    try {
      final reportDateString = DateFormat('yyyy-MM-dd').format(dateForReport);
      final existingReportForDate =
          await _dbHelper.getQueueReportByDate(reportDateString);

      if (existingReportForDate != null) {
        if (!mounted) return;
        bool overwrite = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Report Exists'),
                content: Text(
                    'A report for $reportDateString already exists. Overwrite it?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Overwrite')),
                ],
              ),
            ) ??
            false;
        if (!overwrite) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Report generation for $reportDateString cancelled.')));
          return;
        } else {
          // User confirmed overwrite, so delete the existing report first
          await _dbHelper.deleteQueueReport(existingReportForDate['id']);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Existing report for $reportDateString deleted. Saving new one...')),
          );
        }
      }
      // Generate report for the specific date (today or selected past date)
      final reportData =
          await _queueService.generateDailyReport(reportDate: dateForReport);

      final reportId =
          await _queueService.saveDailyReportToDb(reportData: reportData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Report for $reportDateString (ID: $reportId) saved successfully!'),
            backgroundColor: Colors.green),
      );
      _loadReports(); // Refresh the list of saved reports

      if (!mounted) return;
      bool exportNow = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Export Report'),
              content: Text(
                  'Do you want to export the generated report for $reportDateString to PDF now?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Later')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Export Now')),
              ],
            ),
          ) ??
          false;

      if (!mounted) return;
      if (exportNow) {
        // Fetch the just saved report data to pass its full data to export function
        // The `reportData` variable already holds what we need for export.
        _exportReport(reportData);
      }

      // Clear active queue if the report generated was for today
      final today = DateTime.now();
      if (dateForReport.year == today.year &&
          dateForReport.month == today.month &&
          dateForReport.day == today.day) {
        if (!mounted) return;
        bool clearQueue = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Clear Active Queue?'),
                content: const Text(
                    'Today\'s report has been saved. Do you want to clear the current active queue to prepare for the next operational day?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No, Keep It')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes, Clear Now')),
                ],
              ),
            ) ??
            false;

        if (!mounted) return;
        if (clearQueue) {
          int clearedCount = await _queueService.clearTodaysActiveQueue();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '$clearedCount entries cleared from the active queue.'),
                backgroundColor: Colors.blueAccent),
          );
          // Optionally, navigate away or refresh other relevant screens if needed
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error generating/saving report for $dateForReport: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewAndExportReport(Map<String, dynamic> report) async {
    List<Map<String, dynamic>> typedQueueData = [];
    if (report['queueData'] != null) {
      if (report['queueData'] is String) {
        try {
          typedQueueData =
              List<Map<String, dynamic>>.from(jsonDecode(report['queueData']));
        } catch (e) {
          if (kDebugMode) {
            print("Error decoding queueData in _viewAndExportReport: $e");
          }
        }
      } else if (report['queueData'] is List) {
        typedQueueData = List<Map<String, dynamic>>.from(report['queueData']);
      }
    }

    await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Report Details - ${report['reportDate']}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Total Patients in Queue: ${report['totalPatientsInQueue'] ?? report['totalPatients'] ?? 'N/A'}'), // Handle old and new field names
                  Text('Served: ${report['patientsServed'] ?? 'N/A'}'),
                  Text(
                      'Removed: ${report['patientsRemoved'] ?? 'N/A'}'), // Now directly from report map
                  Text(
                      'Avg. Wait: ${report['averageWaitTimeMinutes'] ?? report['averageWaitTime'] ?? 'N/A'}'), // Handle old and new field names
                  Text('Peak Hour: ${report['peakHour'] ?? 'N/A'}'),
                  const SizedBox(height: 10),
                  Text(
                      'Total Queue Entries Processed: ${typedQueueData.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  // Removed the detailed list of patients
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close')),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label:
                    const Text('Export PDF', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog first
                  // Ensure the report passed to _exportReport has queueData as List<Map> not String
                  Map<String, dynamic> reportForExport = Map.from(report);
                  reportForExport['queueData'] =
                      typedQueueData; // Use the decoded version
                  _exportReport(reportForExport);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        });
  }

  Future<void> _exportReport(Map<String, dynamic> reportData) async {
    try {
      // Ensure queueData is correctly formatted (List<Map>) for the PDF service
      Map<String, dynamic> dataForPdf = Map.from(reportData);
      if (dataForPdf['queueData'] is String) {
        try {
          dataForPdf['queueData'] = List<Map<String, dynamic>>.from(
              jsonDecode(dataForPdf['queueData']));
        } catch (e) {
          if (kDebugMode) {
            print("Error decoding queueData for PDF export: $e");
          }
          dataForPdf['queueData'] = []; // Fallback to empty list
        }
      } else if (dataForPdf['queueData'] == null) {
        dataForPdf['queueData'] = [];
      }

      final filePath = await _queueService.exportDailyReportToPdf(dataForPdf);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Report exported to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error exporting report: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Queue Reports',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadReports,
            tooltip: 'Refresh Reports',
          ),
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: () => _pickDateForReport(context),
            tooltip: 'Select Date for New Report',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_alt, color: Colors.white),
              label: Text(
                  'Generate & Save Report for ${DateFormat('yyyy-MM-dd').format(_selectedDateForNewReport)}',
                  style: const TextStyle(color: Colors.white)),
              onPressed: () =>
                  _generateAndSaveReportForDate(_selectedDateForNewReport),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _reportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error loading reports: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No saved queue reports found.',
                          style: TextStyle(fontSize: 16)));
                }
                final reports = snapshot.data!;
                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading:
                            Icon(Icons.description, color: Colors.teal[700]),
                        title: Text('Report Date: ${report['reportDate']}'),
                        subtitle: Text(
                            'Patients in Queue: ${report['totalPatientsInQueue'] ?? report['totalPatients'] ?? 'N/A'} - Served: ${report['patientsServed'] ?? 'N/A'}'), // Handle old and new field names
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _viewAndExportReport(report),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}