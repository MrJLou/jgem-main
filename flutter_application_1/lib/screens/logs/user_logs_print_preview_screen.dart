import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class UserLogsPrintPreviewScreen extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  const UserLogsPrintPreviewScreen({super.key, required this.logs});

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('User Activity Log', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Paragraph(
            text: 'Generated on: ${DateTime.now().toLocal().toString().substring(0, 16)}',
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Timestamp', 'User ID', 'Action'],
            data: logs.map((log) {
              final timestamp = log['timestamp'] != null
                  ? DateTime.parse(log['timestamp']).toLocal().toString().substring(0, 16)
                  : 'N/A';
              final userId = log['userId']?.toString() ?? 'N/A';
              final action = log['actionDescription']?.toString() ?? 'N/A';
              return [timestamp, userId, action];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Logs - Print Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) => _generatePdf(format),
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
      ),
    );
  }
} 