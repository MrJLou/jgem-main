import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfInvoiceService {
  Future<Uint8List> generateInvoicePdf({
    required ActivePatientQueueItem queueItem,
    required Patient? patientDetails,
    required String invoiceNumber,
    required DateTime invoiceDate,
  }) async {
    final pdf = pw.Document();

    final logoImageBytes = (await rootBundle.load('assets/images/slide1.png')).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoImageBytes);
    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    final baseColor = PdfColor.fromHex('#E0F2F1'); // Light Teal
    final accentColor = PdfColor.fromHex('#00695C'); // Dark Teal

    final textStyle = pw.TextStyle(font: font, fontSize: 10);
    final boldStyle = pw.TextStyle(font: boldFont, fontSize: 10);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(logoImage, accentColor),
              pw.SizedBox(height: 30),
              _buildMainInfo(invoiceNumber, invoiceDate, queueItem, patientDetails, baseColor, accentColor, boldStyle, textStyle),
              pw.SizedBox(height: 30),
              _buildServicesTable(context, queueItem, accentColor, boldStyle, textStyle),
              pw.SizedBox(height: 1),
              _buildTotals(queueItem, accentColor, boldStyle, textStyle),
              pw.Spacer(),
              _buildFooter(boldStyle, textStyle),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(pw.ImageProvider logoImage, PdfColor accentColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('INVOICE', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: accentColor)),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(height: 60, width: 60, child: pw.Image(logoImage)),
            pw.SizedBox(height: 8),
            pw.Text('JGEM Medical and Diagnosis Clinic', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 2),
            pw.Text('074 Pook Hulo, Brgy. Loma de Gato, Marilao, Philippines', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('0936 467 2988', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('jgemclinic@gmail.com', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildMainInfo(String invoiceNumber, DateTime invoiceDate, ActivePatientQueueItem queueItem, Patient? patientDetails, PdfColor baseColor, PdfColor accentColor, pw.TextStyle boldStyle, pw.TextStyle textStyle) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildInfoBox('INVOICE #', invoiceNumber, baseColor, accentColor, boldStyle),
              pw.SizedBox(height: 15),
              _buildPatientInfoBox(
                name: queueItem.patientName, 
                address: patientDetails?.address ?? 'N/A', 
                doctor: queueItem.doctorName,
                baseColor: baseColor, 
                accentColor: accentColor, 
                boldStyle: boldStyle, 
                textStyle: textStyle
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 30),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildInfoBox('INVOICE DATE', DateFormat('dd-MMM-yy').format(invoiceDate), baseColor, accentColor, boldStyle),
              pw.SizedBox(height: 15),
              _buildTotalDueBox(queueItem.totalPrice ?? 0.0, baseColor, accentColor, boldStyle),
            ],
          ),
        )
      ],
    );
  }

  pw.Widget _buildInfoBox(String title, String value, PdfColor baseColor, PdfColor accentColor, pw.TextStyle boldStyle) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: accentColor, width: 2))),
      child: pw.Container(
        color: baseColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: boldStyle.copyWith(color: accentColor)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: boldStyle.copyWith(fontSize: 12)),
          ]
        ),
      )
    );
  }
  
  pw.Widget _buildPatientInfoBox({
    required String name, 
    required String address,
    String? doctor,
    required PdfColor baseColor, 
    required PdfColor accentColor, 
    required pw.TextStyle boldStyle, 
    required pw.TextStyle textStyle
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: accentColor, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: baseColor,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: pw.Text('PATIENT INFORMATION', style: boldStyle.copyWith(color: accentColor)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Table(
              columnWidths: { 0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(4) },
              children: [
                pw.TableRow(children: [pw.Text('Name', style: boldStyle), pw.Text(name, style: textStyle)]),
                pw.TableRow(children: [pw.SizedBox(height: 8), pw.SizedBox(height: 8)]),
                pw.TableRow(children: [pw.Text('Address', style: boldStyle), pw.Text(address, style: textStyle)]),
                if (doctor != null && doctor.isNotEmpty)
                  ...[
                    pw.TableRow(children: [pw.SizedBox(height: 8), pw.SizedBox(height: 8)]),
                    pw.TableRow(children: [pw.Text('Doctor', style: boldStyle), pw.Text(doctor, style: textStyle)]),
                  ]
              ]
            ),
          )
        ]
      )
    );
  }

  pw.Widget _buildTotalDueBox(double total, PdfColor baseColor, PdfColor accentColor, pw.TextStyle boldStyle) {
    return pw.Container(
      color: baseColor,
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TOTAL DUE', style: boldStyle.copyWith(color: accentColor)),
          pw.SizedBox(height: 4),
          pw.Text('PHP ${total.toStringAsFixed(2)}', style: boldStyle.copyWith(color: accentColor, fontSize: 20)),
        ]
      )
    );
  }

  pw.Widget _buildServicesTable(pw.Context context, ActivePatientQueueItem queueItem, PdfColor accentColor, pw.TextStyle boldStyle, pw.TextStyle textStyle) {
    final services = queueItem.selectedServices ?? [];
    final data = services.map((service) {
      const qty = 1;
      final unitPrice = (service['price'] as num?)?.toDouble() ?? 0.0;
      final total = qty * unitPrice;
      return [ service['name'] as String? ?? 'Unknown Service', qty.toString(), unitPrice.toStringAsFixed(2), total.toStringAsFixed(2) ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      context: context,
      headers: ['DESCRIPTION', 'QTY', 'UNIT PRICE', 'TOTAL'],
      data: data,
      headerStyle: boldStyle.copyWith(color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: accentColor),
      cellStyle: textStyle,
      cellAlignments: { 0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight, },
      border: pw.TableBorder.all(color: accentColor, width: 1),
      columnWidths: { 0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2), }
    );
  }

  pw.Widget _buildTotals(ActivePatientQueueItem queueItem, PdfColor accentColor, pw.TextStyle boldStyle, pw.TextStyle textStyle) {
    final subtotal = queueItem.totalPrice ?? 0.0;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: accentColor, width: 1), right: pw.BorderSide(color: accentColor, width: 1), bottom: pw.BorderSide(color: accentColor, width: 1))
      ),
      child: pw.Row(
        children: [
          pw.Spacer(flex: 6),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SUB TOTAL', style: textStyle),
                      pw.Text('PHP ${subtotal.toStringAsFixed(2)}', style: textStyle),
                    ]
                  )
                ),
                pw.Container(
                  color: accentColor,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL', style: boldStyle.copyWith(color: PdfColors.white)),
                      pw.Text('PHP ${subtotal.toStringAsFixed(2)}', style: boldStyle.copyWith(color: PdfColors.white)),
                    ]
                  )
                )
              ]
            )
          )
        ]
      )
    );
  }

  pw.Widget _buildFooter(pw.TextStyle boldStyle, pw.TextStyle textStyle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Terms & Conditions', style: boldStyle),
            pw.SizedBox(height: 4),
            pw.Text('Please send payment within 30 days.', style: textStyle),
          ]
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(height: 1, width: 150, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Text('Signature', style: textStyle),
          ]
        ),
      ]
    );
  }
} 