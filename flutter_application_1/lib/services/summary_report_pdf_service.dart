import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/models/patient_report.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A strongly-typed data class for the summary report to ensure type safety
/// and prevent runtime errors related to data handling.
class SummaryReportData {
  final Map<String, int> demographics;
  final Map<String, int> treatmentAnalytics;
  final List<PatientReport> recentVisits;
  final String reportDate;

  SummaryReportData({
    required this.demographics,
    required this.treatmentAnalytics,
    required this.recentVisits,
    required this.reportDate,
  });
}

class SummaryReportPdfService {  /// Generates a summary PDF from the strongly-typed [SummaryReportData].
  /// Creates a text-based PDF for efficient printing with PHP currency.
  Future<Uint8List> generateSummaryPdf(SummaryReportData data) async {
    try {
      final pdf = pw.Document();

      // Use default fonts for better compatibility and efficiency
      final theme = pw.ThemeData();

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [            _buildTextHeader(data.reportDate),
            pw.SizedBox(height: 20),
            _buildTextDemographics(data.demographics),
            pw.SizedBox(height: 20),
            _buildTextTreatmentAnalytics(data.treatmentAnalytics),
            pw.SizedBox(height: 20),
            _buildTextRecentVisits(data.recentVisits),
          ],
        ),
      );

      return pdf.save();
    } catch (e) {
      if (kDebugMode) {
        print('Error generating summary PDF: $e');
      }
      rethrow;
    }  }

  /// Safe string helper
  String _safeString(String? value) {
    return value?.isNotEmpty == true ? value! : 'N/A';
  }

  /// Text-based header
  pw.Widget _buildTextHeader(String reportDate) {
    return pw.Column(
      children: [        pw.Text(
          'CLINIC SUMMARY REPORT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Report Date: $reportDate',
          style: const pw.TextStyle(fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Text-based demographics
  pw.Widget _buildTextDemographics(Map<String, int> demographics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [        pw.Text(
          'PATIENT DEMOGRAPHICS',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (demographics.isEmpty)
          pw.Text('No demographic data available.', style: const pw.TextStyle(fontSize: 10))
        else
          ...demographics.entries.map((entry) => 
            pw.Text('${entry.key}: ${entry.value}', style: const pw.TextStyle(fontSize: 10))
          ),
      ],
    );
  }

  /// Text-based treatment analytics
  pw.Widget _buildTextTreatmentAnalytics(Map<String, int> treatmentAnalytics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [        pw.Text(
          'TREATMENT & SERVICE ANALYTICS',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (treatmentAnalytics.isEmpty)
          pw.Text('No treatment analytics available.', style: const pw.TextStyle(fontSize: 10))
        else
          ...treatmentAnalytics.entries.map((entry) => 
            pw.Text('${entry.key}: ${entry.value} times', style: const pw.TextStyle(fontSize: 10))
          ),
      ],
    );
  }

  /// Text-based recent visits
  pw.Widget _buildTextRecentVisits(List<PatientReport> recentVisits) {
    try {
      if (recentVisits.isEmpty) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RECENT PATIENT VISITS',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('No recent visits found.'),
          ],
        );
      }      // Safe data processing
      final safeVisits = recentVisits.where((visit) {
        try {
          return visit.patient.fullName.isNotEmpty;
        } catch (e) {
          if (kDebugMode) {
            print('Skipping invalid visit data: $e');
          }
          return false;
        }
      }).take(15).toList();

      if (safeVisits.isEmpty) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RECENT PATIENT VISITS',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('No valid visit data available.'),
          ],
        );
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RECENT PATIENT VISITS',
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
              ...safeVisits.map((visit) {
                try {
                  final patientName = _safeString(visit.patient.fullName);
                  final date = DateFormat('MMM dd, yyyy').format(visit.record.recordDate);
                  final diagnosis = _safeString(visit.record.diagnosis);
                  
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
                    print('Error processing visit row: $e');
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
        print('Error building recent visits table: $e');
      }
      return pw.Text('Error loading recent visits data.');
    }
  }
} 