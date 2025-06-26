import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptService {
  static Future<Uint8List> generateReceiptPdfBytes(Map<String, dynamic> receiptDetails) async {
    final pdf = pw.Document();
    final logoImageBytes = await rootBundle.load('assets/images/slide1.png');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());
    
    final patientName = receiptDetails['patientName'] as String? ?? '';
    final invoiceNumber = receiptDetails['invoiceNumber'] as String? ?? '';
    final referenceNumber = receiptDetails['referenceNumber'] as String? ?? '';
    final paymentDate = receiptDetails['paymentDate'] as DateTime? ?? DateTime.now();
    final totalAmount = (receiptDetails['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (receiptDetails['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final change = (receiptDetails['change'] as num?)?.toDouble() ?? 0.0;
    final billItems = receiptDetails['billItems'] as List<dynamic>? ?? [];

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Official Receipt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 60, width: 60, child: pw.Image(logoImage)),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Text('JGEM Medical and Diagnosis Clinic'),
              pw.Text('074 Pook Hulo, Brgy. Loma de Gato, Marilao, Philippines'),
              pw.Divider(height: 30),
              pw.Text('Patient: $patientName'),
              if (invoiceNumber.isNotEmpty) pw.Text('Invoice #: $invoiceNumber'),
              pw.Text('Payment Ref: $referenceNumber'),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd hh:mm a').format(paymentDate)}'),
              pw.Divider(height: 30),
              pw.Text('Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...billItems.map((item) {
                  final itemName = item['description'] as String? ?? 'Unknown Service';
                  final itemTotal = (item['itemTotal'] as num?)?.toDouble() ?? 0.0;
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(itemName),
                      pw.Text('PHP${itemTotal.toStringAsFixed(2)}'),
                    ]
                  );
                }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total: PHP${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
              ),
               pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Amount Paid: PHP${amountPaid.toStringAsFixed(2)}'),
                ]
              ),
               pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Change: PHP${change.toStringAsFixed(2)}'),
                ]
              ),
              pw.SizedBox(height: 50),
              pw.Center(child: pw.Text('Thank you for your payment!')),
            ]
          );
        }
      )
    );
    return pdf.save();
  }
} 