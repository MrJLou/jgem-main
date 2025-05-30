import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:convert'; // For jsonDecode if queueData is stored as JSON string

import '../../services/queue_service.dart';
import '../../services/database_helper.dart';

class QueueReportsScreen extends StatefulWidget {
  const QueueReportsScreen({Key? key}) : super(key: key);

  @override
  _QueueReportsScreenState createState() => _QueueReportsScreenState();
}

class _QueueReportsScreenState extends State<QueueReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();
  late Future<List<Map<String, dynamic>>> _reportsFuture;

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

  Future<void> _generateAndSaveTodaysReport() async {
    try {
      final todaysReportData = await _queueService.generateDailyReport();
      // Check if a report for today already exists to avoid duplicates if desired
      final existingReportForToday =
          await _dbHelper.getQueueReportByDate(todaysReportData['reportDate']);
      if (existingReportForToday != null) {
        bool overwrite = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                      title: Text('Report Exists'),
                      content: Text(
                          'A report for ${todaysReportData['reportDate']} already exists. Overwrite it?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Overwrite')),
                      ],
                    )) ??
            false;
        if (!overwrite) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Report generation cancelled.')));
          return;
        }
      }

      final reportId =
          await _queueService.saveDailyReportToDb(reportData: todaysReportData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Today\'s report (ID: $reportId) saved successfully!'),
            backgroundColor: Colors.green),
      );
      _loadReports(); // Refresh the list

      // Ask to export immediately
      bool exportNow = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                    title: Text('Export Report'),
                    content: Text(
                        'Do you want to export the generated report to PDF now?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Later')),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text('Export Now')),
                    ],
                  )) ??
          false;

      if (exportNow) {
        // Fetch the just saved report to pass its full data to export function
        final fullReportData = await _dbHelper
            .getQueueReportByDate(todaysReportData['reportDate']);
        if (fullReportData != null) {
          _exportReport(fullReportData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not fetch report data for export.'),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error generating/saving report: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewAndExportReport(Map<String, dynamic> report) async {
    // The report map from getDailyQueueReports already has queueData decoded.
    await showDialog(
        context: context,
        builder: (context) {
          List<dynamic> queueDataList = report['queueData'] ?? [];
          // Ensure queueDataList is List<Map<String, dynamic>> if it comes from JSON text
          if (queueDataList.isNotEmpty && queueDataList.first is String) {
            // Basic check if it needs decoding
            try {
              queueDataList = jsonDecode(queueDataList.join(''));
            } catch (e) {/* handle error or assume it's already map */}
          }
          List<Map<String, dynamic>> typedQueueData =
              List<Map<String, dynamic>>.from(queueDataList);

          return AlertDialog(
            title: Text('Report Details - ${report['reportDate']}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total Patients: ${report['totalPatients']}'),
                  Text('Served: ${report['patientsServed']}'),
                  Text('Avg. Wait: ${report['averageWaitTime']}'),
                  Text('Peak Hour: ${report['peakHour']}'),
                  const SizedBox(height: 10),
                  Text('Queue Entries:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (typedQueueData.isEmpty)
                    Text('No queue entries recorded.'),
                  ...typedQueueData.map((entry) {
                    // Convert map to ActivePatientQueueItem for easier field access if preferred, or use map directly
                    // final item = ActivePatientQueueItem.fromJson(entry);
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: ${entry['patientName'] ?? 'N/A'}',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                  'Patient ID: ${entry['patientId'] ?? 'N/A'}'),
                              Text(
                                  'Arrival: ${DateFormat('HH:mm').format(DateTime.parse(entry['arrivalTime']))}'),
                              Text('Status: ${entry['status']}'),
                              if (entry['conditionOrPurpose'] != null)
                                Text(
                                    'Condition: ${entry['conditionOrPurpose']}'),
                            ]),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close')),
              ElevatedButton.icon(
                icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                label:
                    Text('Export PDF', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog first
                  _exportReport(report);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors
                      .white, // Ensures icon and text color if not overridden by direct style
                ),
              ),
            ],
          );
        });
  }

  Future<void> _exportReport(Map<String, dynamic> reportData) async {
    try {
      final filePath = await _queueService.exportDailyReportToPdf(reportData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Report exported to: $filePath'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5)),
      );
    } catch (e) {
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
            icon: Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh Reports',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.save_alt, color: Colors.white),
              label: Text('Generate & Save Today\'s Queue Report',
                  style: TextStyle(color: Colors.white)),
              onPressed: _generateAndSaveTodaysReport,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors
                      .white, // Ensures icon and text color if not overridden by direct style
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
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
                            'Total Patients: ${report['totalPatients']} - Served: ${report['patientsServed']}'),
                        trailing: Icon(Icons.arrow_forward_ios),
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
