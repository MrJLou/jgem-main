import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/models/patient_report.dart';
import 'package:flutter_application_1/models/patient_bill.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data class to hold all necessary information for the analytics report.
/// This ensures type safety and uses proper model types.
class ServiceAnalyticsReportData {
  final double totalRevenue;
  final int totalPatients;
  final double avgPayment;
  final int totalServices;
  final int maleCount;
  final int femaleCount;
  final List<PatientReport> recentPatients;
  final List<PatientBill> paidBills;
  final List<PatientBill> unpaidBills;
  final List<ServiceUsageData> serviceUsageData;
  final List<MonthlyRevenueData> monthlyRevenueData;

  ServiceAnalyticsReportData({
    required this.totalRevenue,
    required this.totalPatients,
    required this.avgPayment,
    required this.totalServices,
    required this.maleCount,
    required this.femaleCount,
    required this.recentPatients,
    required this.paidBills,
    required this.unpaidBills,
    required this.serviceUsageData,
    required this.monthlyRevenueData,
  });

  int get paidCount => paidBills.length;
  int get unpaidCount => unpaidBills.length;
}

class ServiceUsageData {
  final String serviceName;
  final int usageCount;

  ServiceUsageData({
    required this.serviceName,
    required this.usageCount,
  });
}

class MonthlyRevenueData {
  final String month;
  final double revenue;

  MonthlyRevenueData({
    required this.month,
    required this.revenue,
  });
}

class ServiceAnalyticsPdfService {  /// Generates a PDF document from the provided service analytics data.
  ///
  /// The [reportData] is a strongly-typed object containing all the
  /// necessary information for the report.
  /// The [serviceName] is used for the report title.
  /// This method creates a text-based PDF for efficient printing.
  Future<Uint8List> generatePdf(
      ServiceAnalyticsReportData reportData, String serviceName) async {
    try {
      final pdf = pw.Document();

      // Use default fonts for better compatibility and efficiency
      final theme = pw.ThemeData();

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            pw.Text(
              'CLINIC ANALYTICS REPORT',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Service: ${_safeString(serviceName)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Report Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 30),
            
            // Summary Statistics
            _buildTextBasedSummary(reportData),
            pw.SizedBox(height: 30),
            
            // Patient Demographics
            _buildTextBasedDemographics(reportData),
            pw.SizedBox(height: 30),
              // Service Usage Summary
            _buildTextBasedServiceUsage(reportData.serviceUsageData),
            pw.SizedBox(height: 30),
              // Monthly Revenue Summary
            _buildTextBasedMonthlyRevenue(reportData),
            pw.SizedBox(height: 30),
            
            // Recent Patients Table
            if (reportData.recentPatients.isNotEmpty)
              _buildTextBasedRecentPatients(reportData.recentPatients)
            else
              pw.Text('No recent patients found for this service.',
                  style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      );

      return pdf.save();
    } catch (e) {
      if (kDebugMode) {
        print('Error generating PDF: $e');
      }
      rethrow;
    }  }

  /// Safe string helper to prevent null/empty values
  String _safeString(String? value) {
    return value?.isNotEmpty == true ? value! : 'N/A';
  }

  /// Safe number formatting with PHP currency
  String _formatCurrency(double amount) {
    return 'PHP ${NumberFormat('#,##0.00').format(amount)}';
  }

  /// Text-based summary section
  pw.Widget _buildTextBasedSummary(ServiceAnalyticsReportData reportData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SUMMARY STATISTICS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Total Patients: ${reportData.totalPatients}'),
        pw.Text('Total Revenue: ${_formatCurrency(reportData.totalRevenue)}'),
        pw.Text('Average Payment: ${_formatCurrency(reportData.avgPayment)}'),
        pw.Text('Total Services: ${reportData.totalServices}'),
        pw.Text('Paid Bills: ${reportData.paidCount}'),
        pw.Text('Unpaid Bills: ${reportData.unpaidCount}'),
      ],
    );
  }

  /// Text-based demographics section
  pw.Widget _buildTextBasedDemographics(ServiceAnalyticsReportData reportData) {
    final total = reportData.maleCount + reportData.femaleCount;
    final malePercent = total > 0 ? (reportData.maleCount / total * 100).toStringAsFixed(1) : '0.0';
    final femalePercent = total > 0 ? (reportData.femaleCount / total * 100).toStringAsFixed(1) : '0.0';
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PATIENT DEMOGRAPHICS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Male Patients: ${reportData.maleCount} ($malePercent%)'),
        pw.Text('Female Patients: ${reportData.femaleCount} ($femalePercent%)'),
        pw.Text('Total Patients: $total'),
      ],
    );
  }

  /// Text-based service usage section
  pw.Widget _buildTextBasedServiceUsage(List<ServiceUsageData> serviceUsageData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SERVICE USAGE SUMMARY',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        if (serviceUsageData.isEmpty)
          pw.Text('No service usage data available.')
        else
          ...serviceUsageData.take(10).map((service) => pw.Text(
            '${_safeString(service.serviceName)}: ${service.usageCount} uses'
          )),
      ],
    );
  }  /// Text-based monthly revenue section
  pw.Widget _buildTextBasedMonthlyRevenue(ServiceAnalyticsReportData reportData) {
    final now = DateTime.now();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'MONTHLY REVENUE SUMMARY - ${now.year}',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        if (reportData.monthlyRevenueData.isEmpty)
          pw.Text('No monthly revenue data available.')
        else
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Month', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              ...reportData.monthlyRevenueData.map((data) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(data.month),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_formatCurrency(data.revenue)),
                    ),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  /// Text-based recent patients table
  pw.Widget _buildTextBasedRecentPatients(List<PatientReport> patients) {
    try {
      if (patients.isEmpty) {
        return pw.Text('No recent patients found.');
      }      // Safe data processing
      final safePatients = patients.where((patient) {
        try {
          // Validate that we can access the required fields
          return patient.patient.fullName.isNotEmpty;
        } catch (e) {
          if (kDebugMode) {
            print('Skipping invalid patient data: $e');
          }
          return false;
        }
      }).take(15).toList();

      if (safePatients.isEmpty) {
        return pw.Text('No valid patient data available.');
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RECENT PATIENTS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Patient Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Diagnosis', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              ...safePatients.map((patient) {
                try {
                  final patientName = _safeString(patient.patient.fullName);
                  final date = DateFormat('MMM dd, yyyy').format(patient.record.recordDate);
                  final diagnosis = _safeString(patient.record.diagnosis);
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(patientName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(date),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(diagnosis),
                      ),
                    ],
                  );
                } catch (e) {
                  if (kDebugMode) {
                    print('Error processing patient row: $e');
                  }
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Error loading data'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Error'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Error'),
                      ),
                    ],
                  );
                }
              }),
            ],
          ),
        ],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error building recent patients table: $e');
      }
      return pw.Text('Error loading patient data.');
    }
  }
}