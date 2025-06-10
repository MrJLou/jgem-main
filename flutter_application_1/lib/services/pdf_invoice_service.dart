import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/active_patient_queue_item.dart';
import '../models/bill_item.dart';
import '../models/patient.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateInvoicePdf({
    required String? generatedInvoiceNumber,
    required DateTime? invoiceDate,
    required Patient? detailedPatientForInvoice,
    required ActivePatientQueueItem? selectedPatientQueueItem,
    required List<BillItem> currentBillItems,
    required NumberFormat currencyFormat,
  }) async {
    final pdf = pw.Document();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/slide1.png')).buffer.asUint8List(),
    );

    final baseColor = PdfColor.fromHex('#009688'); // Teal
    final accentColor = PdfColor.fromHex('#E0F2F1'); // Light Teal
    final darkTextColor = PdfColor.fromHex('#37474F');
    final lightTextColor = PdfColor.fromHex('#78909C');

    final headerStyle = pw.TextStyle(fontSize: 10, color: lightTextColor);
    final boldStyle =
        pw.TextStyle(fontWeight: pw.FontWeight.bold, color: darkTextColor, fontSize: 10);

    final String invoiceNumber = generatedInvoiceNumber ?? 'N/A';
    final DateTime issueDate = invoiceDate ?? DateTime.now();
    final patientName = detailedPatientForInvoice?.fullName ??
        selectedPatientQueueItem?.patientName ??
        'N/A';
    final patientAddress = detailedPatientForInvoice?.address ?? 'N/A';
    final patientContact =
        detailedPatientForInvoice?.contactNumber ?? 'N/A';
    final patientEmail = detailedPatientForInvoice?.email ?? 'N/A';
    final doctorName = selectedPatientQueueItem?.doctorName ?? 'N/A';
    final subtotal =
        currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    final totalAmount = subtotal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          final items = <List<String>>[
            ['DATE', 'SERVICE DESCRIPTION', 'AMOUNT'],
            ...currentBillItems.map((item) => [
                  DateFormat('dd-MMM-yy').format(issueDate),
                  item.description,
                  currencyFormat.format(item.itemTotal),
                ]),
          ];

          const int totalRows = 8;
          int existingItems = currentBillItems.length;
          if (existingItems < totalRows) {
            for (int i = 0; i < totalRows - existingItems; i++) {
              items.add(['', '', '']);
            }
          }

          return pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('INVOICE',
                    style: pw.TextStyle(
                        fontSize: 32,
                        color: baseColor,
                        fontWeight: pw.FontWeight.bold)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(width: 80, height: 80, child: pw.Image(logo)),
                    pw.SizedBox(height: 8),
                    pw.Text('J-GEM Medical Clinic',
                        style: boldStyle.copyWith(fontSize: 14)),
                    pw.Text('74 Pook Hulo, Marilao, Bulacan',
                        style: headerStyle),
                    pw.Text('jgemclinic@gmail.com', style: headerStyle),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: accentColor),
                                color: accentColor),
                            child: pw.Center(
                                child:
                                    pw.Text('INVOICE #', style: boldStyle))),
                        pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: accentColor)),
                            child: pw.Center(
                                child: pw.Text(invoiceNumber,
                                    style:
                                        const pw.TextStyle(fontSize: 14)))),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Row(children: [
                            pw.Expanded(
                                child: pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                        border:
                                            pw.Border.all(color: accentColor),
                                        color: accentColor),
                                    child: pw.Text('INVOICE DATE',
                                        style: boldStyle))),
                            pw.Expanded(
                                child: pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                        border:
                                            pw.Border.all(color: accentColor)),
                                    child: pw.Text(DateFormat('dd-MMM-yy')
                                        .format(issueDate)))),
                          ]),
                          pw.Row(children: [
                            pw.Expanded(
                                child: pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                        border:
                                            pw.Border.all(color: accentColor),
                                        color: accentColor),
                                    child: pw.Text('DUE DATE',
                                        style: boldStyle))),
                            pw.Expanded(
                                child: pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                        border:
                                            pw.Border.all(color: accentColor)),
                                    child: pw.Text(DateFormat('dd-MMM-yy')
                                        .format(issueDate.add(
                                            const Duration(days: 30)))))),
                          ]),
                        ]),
                  )
                ]),
            pw.SizedBox(height: 15),
            _buildInfoTable(
                'PATIENT INFORMATION',
                {
                  'Name': patientName,
                  'Address': patientAddress,
                  'Phone Number': patientContact,
                  'Email': patientEmail,
                },
                boldStyle,
                baseColor,
                accentColor),
            pw.SizedBox(height: 15),
            _buildInfoTable(
                'DOCTOR INFORMATION',
                {
                  'Name': "Dr. $doctorName",
                  'Address': 'N/A',
                },
                boldStyle,
                baseColor,
                accentColor),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: boldStyle,
              headerDecoration: pw.BoxDecoration(color: accentColor),
              cellPadding: const pw.EdgeInsets.all(8),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              headerAlignment: pw.Alignment.center,
              data: items,
              border: pw.TableBorder.all(color: accentColor),
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Conditions',
                          style: boldStyle.copyWith(fontSize: 8)),
                      pw.Text('Please send payment within 30 days',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.SizedBox(
                    width: 200,
                    child: pw.Table(
                        columnWidths: const {
                          0: pw.FlexColumnWidth(2),
                          1: pw.FlexColumnWidth(2),
                        },
                        children: [
                          pw.TableRow(children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child:
                                    pw.Text('SUB TOTAL', style: boldStyle)),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                    currencyFormat.format(subtotal),
                                    style: boldStyle,
                                    textAlign: pw.TextAlign.right)),
                          ]),
                          pw.TableRow(children: [
                            pw.Container(
                                color: baseColor,
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('TOTAL',
                                    style: boldStyle.copyWith(
                                        color: PdfColors.white))),
                            pw.Container(
                                color: baseColor,
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                    currencyFormat.format(totalAmount),
                                    style: boldStyle.copyWith(
                                        color: PdfColors.white),
                                    textAlign: pw.TextAlign.right)),
                          ]),
                        ])),
              ],
            ),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Column(children: [
                pw.Container(
                  width: 150,
                  height: 1,
                  color: darkTextColor,
                ),
                pw.SizedBox(height: 4),
                pw.Text('Signature'),
              ]),
            ),
          ]);
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoTable(
      String title,
      Map<String, String> data,
      pw.TextStyle boldStyle,
      PdfColor baseColor,
      PdfColor accentColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          color: accentColor,
          child: pw.Text(title, style: boldStyle.copyWith(color: baseColor)),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: accentColor),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(3),
          },
          children: data.entries.map((e) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.key, style: boldStyle),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.value),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
} 