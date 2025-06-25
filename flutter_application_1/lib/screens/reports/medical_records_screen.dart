import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_application_1/models/patient_report.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/widgets/reports/medical_record_detail_dialog.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  late Future<List<PatientReport>> _reportsFuture;
  List<PatientReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchPatientReports();
  }

  Future<List<PatientReport>> _fetchPatientReports() async {
    final records = await ApiService.getAllMedicalRecords();
    final List<PatientReport> reports = [];
    for (final record in records) {
      try {
        final patient = await ApiService.getPatientById(record.patientId);
        reports.add(PatientReport(record: record, patient: patient));
      } catch (e) {
        debugPrint(
            'Could not fetch patient ${record.patientId} for record ${record.id}: $e');
      }
    }
    // Sort by date, most recent first
    reports.sort((a, b) => b.record.recordDate.compareTo(a.record.recordDate));
    _reports = reports;
    return reports;
  }

  void _showPrintPreview(PatientReport report) {
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async =>
          _generateDetailPdf(format, report),
    );
  }

  void _showSummaryPrintPreview() {
    if (_reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to generate PDF.')),
      );
      return;
    }
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async =>
          _generateSummaryPdf(format, _reports),
    );
  }

  Future<Uint8List> _generateDetailPdf(
      PdfPageFormat format, PatientReport report) async {
    final pdf = pw.Document();
    final record = report.record;
    final patient = report.patient;
    final services = record.selectedServices ?? [];

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(patient.fullName,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text('Patient ID: ${patient.id}'),
              pw.Divider(height: 24),
              _buildPdfDetailRow(label: 'Record ID', value: record.id),
              _buildPdfDetailRow(
                  label: 'Record Date',
                  value: DateFormat('yyyy-MM-dd HH:mm')
                      .format(record.recordDate.toLocal())),
              _buildPdfDetailRow(
                  label: 'Record Type', value: record.recordType),
              _buildPdfDetailRow(label: 'Doctor ID', value: record.doctorId),
              _buildPdfDetailRow(
                  label: 'Diagnosis', value: record.diagnosis ?? 'N/A'),
              _buildPdfDetailRow(
                  label: 'Treatment', value: record.treatment ?? 'N/A'),
              _buildPdfDetailRow(
                  label: 'Prescription', value: record.prescription ?? 'N/A'),
              _buildPdfDetailRow(
                  label: 'Lab Results', value: record.labResults ?? 'N/A'),
              _buildPdfDetailRow(label: 'Notes', value: record.notes ?? 'N/A'),
              pw.SizedBox(height: 16),
              if (services.isNotEmpty) ...[
                pw.Text('Services Rendered:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                ...services.map((service) =>
                    pw.Text('• ${service['name'] ?? 'Unknown Service'}')),
              ],
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildPdfDetailRow({required String label, required String value}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 12.0, color: PdfColors.black),
          children: <pw.TextSpan>[
            pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _generateSummaryPdf(
      PdfPageFormat format, List<PatientReport> reports) async {
    final pdf = pw.Document();

    final tableHeaders = ['Date', 'Patient Name', 'Record Type', 'Diagnosis'];
    final tableData = reports.map((report) {
      return [
        DateFormat('yyyy-MM-dd').format(report.record.recordDate.toLocal()),
        report.patient.fullName,
        report.record.recordType,
        report.record.diagnosis ?? 'N/A',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Patient Medical Records Summary',
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<List<PatientReport>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No medical records found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _reports.length,
            itemBuilder: (context, index) {
              final report = _reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.patient.fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient ID: ${report.patient.id}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Divider(height: 24),
                      _buildRecordDetail(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: report.record.recordDate
                            .toLocal()
                            .toString()
                            .substring(0, 10),
                      ),
                      _buildRecordDetail(
                        icon: Icons.medical_services_outlined,
                        label: 'Record Type',
                        value: report.record.recordType,
                      ),
                      _buildRecordDetail(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Diagnosis',
                        value: report.record.diagnosis ?? 'N/A',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Print'),
                            onPressed: () => _showPrintPreview(report),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('View Details'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    MedicalRecordDetailDialog(report: report),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSummaryPrintPreview,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }

  Widget _buildRecordDetail(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.teal),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
