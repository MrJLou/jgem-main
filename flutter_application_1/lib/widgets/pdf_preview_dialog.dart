import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class PDFPreviewDialog extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const PDFPreviewDialog({
    super.key,
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Printing.layoutPdf(
                          onLayout: (format) async => pdfBytes,
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            // PDF Preview
            Expanded(
              child: PdfPreview(
                build: (format) => pdfBytes,
                initialPageFormat: PdfPageFormat.a4,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canDebug: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
