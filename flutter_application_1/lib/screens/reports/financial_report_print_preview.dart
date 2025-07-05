import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for rootBundle
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinancialReportPrintPreview extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final double total;

  const FinancialReportPrintPreview(
      {super.key, required this.transactions, required this.total});

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    
    // Load logo image
    final logoImageBytes = await rootBundle.load('assets/images/slide1.png');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) {
          final tableHeaders = [
            'Date',
            'Reference #',
            'Patient Name',
            'Amount'
          ];
          final tableData = transactions.map((tr) {
            final date = DateTime.parse(tr['paymentDate'])
                .toLocal()
                .toString()
                .substring(0, 10);
            return [
              date,
              tr['referenceNumber'] ?? 'N/A',
              tr['patientName'] ?? 'N/A',
              'P${(tr['amountPaid'] as num).toStringAsFixed(2)}'
            ];
          }).toList();

          return [
            // Header with logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Financial Report',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated on: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                            style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Container(
                  height: 60,
                  width: 60,
                  child: pw.Image(logoImage),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: tableHeaders,
              data: tableData,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {3: pw.Alignment.centerRight},
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 200,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Payments:',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14)),
                        pw.Text('P${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                                color: PdfColors.green)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Report - Preview'),
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
      ),
    );
  }
}