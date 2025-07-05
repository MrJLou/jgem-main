import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  final List<Map<String, dynamic>>? payments; // Add payments data

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
    this.payments, // Optional payments data
  });
  int get paidCount => paidBills.length;
  int get unpaidCount => unpaidBills.length;
    // Helper method to find payment amount for a patient
  double? getPaymentForPatient(String patientId) {
    if (payments == null || payments!.isEmpty) return null;
    
    try {
      // Find all payments for this patient and sum their amounts
      final patientPayments = payments!.where((payment) => 
        payment['patientId'] == patientId);
      
      if (patientPayments.isEmpty) return null;
      
      // Sum all payments for this patient
      double totalPayments = patientPayments.fold<double>(0.0, (sum, payment) {
        final amount = (payment['amountPaid'] as num?)?.toDouble() ?? 0.0;
        return sum + amount;
      });
      
      return totalPayments > 0 ? totalPayments : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting payment for patient $patientId: $e');
      }
      return null;
    }
  }
  
  // Helper method to find bill for a patient (kept for backward compatibility)
  PatientBill? getBillForPatient(String patientId) {
    try {
      // First try to find in paid bills
      final paidBill = paidBills.where((bill) => bill.patientId == patientId).fold<PatientBill?>(
        null, (latest, bill) => latest == null || bill.invoiceDate.isAfter(latest.invoiceDate) ? bill : latest);
      if (paidBill != null) return paidBill;
      
      // Then try unpaid bills
      return unpaidBills.where((bill) => bill.patientId == patientId).fold<PatientBill?>(
        null, (latest, bill) => latest == null || bill.invoiceDate.isAfter(latest.invoiceDate) ? bill : latest);
    } catch (e) {
      return null;
    }
  }

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
      
      // Load logo image
      final logoImageBytes = await rootBundle.load('assets/images/slide1.png');
      final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

      // Use default fonts for better compatibility and efficiency
      final theme = pw.ThemeData();

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header with logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CLINIC ANALYTICS REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Service: ${_safeString(serviceName)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Report Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.Container(
                  height: 60,
                  width: 60,
                  child: pw.Image(logoImage),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
              // Summary Statistics
            _buildTextBasedSummary(reportData),
            pw.SizedBox(height: 16),
            
            // Patient Demographics
            _buildTextBasedDemographics(reportData),
            pw.SizedBox(height: 16),
              // Service Usage Summary
            _buildTextBasedServiceUsage(reportData.serviceUsageData),
            pw.SizedBox(height: 16),
              // Monthly Revenue Summary
            _buildTextBasedMonthlyRevenue(reportData),
            pw.SizedBox(height: 16),
              // Recent Patients Table
            if (reportData.recentPatients.isNotEmpty)
              _buildTextBasedRecentPatients(reportData.recentPatients, reportData)
            else
              pw.Text('No recent patients found for this service.',
                  style: const pw.TextStyle(fontSize: 8)),
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
  }  /// Text-based summary section
  pw.Widget _buildTextBasedSummary(ServiceAnalyticsReportData reportData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SUMMARY STATISTICS',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Total Patients: ${reportData.totalPatients}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Total Revenue: ${_formatCurrency(reportData.totalRevenue)}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Average Payment: ${_formatCurrency(reportData.avgPayment)}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Total Services: ${reportData.totalServices}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Paid Bills: ${reportData.paidCount}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Unpaid Bills: ${reportData.unpaidCount}', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }  /// Text-based demographics section
  pw.Widget _buildTextBasedDemographics(ServiceAnalyticsReportData reportData) {
    final total = reportData.maleCount + reportData.femaleCount;
    final malePercent = total > 0 ? (reportData.maleCount / total * 100).toStringAsFixed(1) : '0.0';
    final femalePercent = total > 0 ? (reportData.femaleCount / total * 100).toStringAsFixed(1) : '0.0';
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PATIENT DEMOGRAPHICS',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Male Patients: ${reportData.maleCount} ($malePercent%)', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Female Patients: ${reportData.femaleCount} ($femalePercent%)', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Total Patients: $total', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }  /// Text-based service usage section
  pw.Widget _buildTextBasedServiceUsage(List<ServiceUsageData> serviceUsageData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SERVICE USAGE SUMMARY',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (serviceUsageData.isEmpty)
          pw.Text('No service usage data available.', style: const pw.TextStyle(fontSize: 8))
        else
          ...serviceUsageData.take(10).map((service) => pw.Text(
            '${_safeString(service.serviceName)}: ${service.usageCount} uses',
            style: const pw.TextStyle(fontSize: 8)
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
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (reportData.monthlyRevenueData.isEmpty)
          pw.Text('No monthly revenue data available.', style: const pw.TextStyle(fontSize: 8))
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
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Month', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                ],
              ),
              // Data rows
              ...reportData.monthlyRevenueData.map((data) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(data.month, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(_formatCurrency(data.revenue), style: const pw.TextStyle(fontSize: 7)),
                    ),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }  /// Text-based recent patients table
  pw.Widget _buildTextBasedRecentPatients(List<PatientReport> patients, ServiceAnalyticsReportData reportData) {
    try {
      if (patients.isEmpty) {
        return pw.Text('No recent patients found.');
      }

      // Remove duplicates based on patient ID and record date
      final Map<String, PatientReport> uniquePatients = {};
      for (final patient in patients) {
        try {
          if (patient.patient.fullName.isNotEmpty) {
            final key = '${patient.patient.id}_${patient.record.recordDate.millisecondsSinceEpoch}';
            if (!uniquePatients.containsKey(key)) {
              uniquePatients[key] = patient;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Skipping invalid patient data: $e');
          }
        }
      }

      final safePatients = uniquePatients.values.take(10).toList(); // Limit to 10 for PDF readability

      if (safePatients.isEmpty) {
        return pw.Text('No valid patient data available.', style: const pw.TextStyle(fontSize: 8));
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RECENT PATIENTS',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Patient Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Service', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Gender', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  ),
                ],
              ),
              // Data rows
              ...safePatients.map((patient) {
                try {
                  final patientName = _safeString(patient.patient.fullName);
                  final date = DateFormat('dd/MM/yy').format(patient.record.recordDate);
                  final gender = patient.patient.gender.isNotEmpty ? patient.patient.gender.toUpperCase()[0] : 'U';
                  final services = patient.record.selectedServices?.isNotEmpty == true 
                      ? (patient.record.selectedServices!.length > 1 ? 'Multiple Services' : patient.record.selectedServices!.first['name'] ?? 'Service')
                      : 'Consultation';
                    // Get payment information for this patient
                  final paymentAmount = reportData.getPaymentForPatient(patient.patient.id);
                  final paymentAmountText = paymentAmount != null 
                      ? _formatCurrency(paymentAmount) 
                      : 'PHP 0.00';
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(patientName, style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(services, style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(gender, style: const pw.TextStyle(fontSize: 7)),
                      ),                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(paymentAmountText, style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(date, style: const pw.TextStyle(fontSize: 7)),
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
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Error loading data', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Error', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Error', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Error', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Error', style: const pw.TextStyle(fontSize: 7)),
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
      return pw.Text('Error loading patient data.', style: const pw.TextStyle(fontSize: 8));
    }
  }
}