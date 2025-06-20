import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/active_patient_queue_item.dart';
import '../../../models/bill_item.dart';
import '../../../models/patient.dart';

class GeneratedInvoiceView extends StatelessWidget {
  final String generatedInvoiceNumber;
  final DateTime invoiceDate;
  final Patient? detailedPatientForInvoice;
  final ActivePatientQueueItem selectedPatientQueueItem;
  final List<BillItem> currentBillItems;
  final Uint8List? generatedPdfBytes;
  final NumberFormat currencyFormat;
  final Function(Uint8List) onPrint;
  final Function(Uint8List, String) onSave;
  final VoidCallback onProceedToPayment;

  const GeneratedInvoiceView({
    super.key,
    required this.generatedInvoiceNumber,
    required this.invoiceDate,
    required this.detailedPatientForInvoice,
    required this.selectedPatientQueueItem,
    required this.currentBillItems,
    required this.generatedPdfBytes,
    required this.currencyFormat,
    required this.onPrint,
    required this.onSave,
    required this.onProceedToPayment,
  });

  @override
  Widget build(BuildContext context) {
    double subtotal =
        currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double total = subtotal; // No discount or tax for now

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVOICE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("Invoice #: $generatedInvoiceNumber",
                        style: TextStyle(color: Colors.grey[700])),
                    Text(
                        "Issued: ${DateFormat('dd MMM, yyyy').format(invoiceDate)}",
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                Image.asset(
                  'assets/images/slide1.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                      width: 80,
                      height: 80,
                      child: Icon(Icons.business_center)),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1),

            // --- Patient and Doctor Info ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BILLED TO",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                          detailedPatientForInvoice?.fullName ??
                              selectedPatientQueueItem.patientName,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (detailedPatientForInvoice?.address != null)
                        Text(detailedPatientForInvoice!.address!),
                    ],
                  ),
                ),
              ],
            ),
            
            if (selectedPatientQueueItem.doctorName != null) ...[
              const Divider(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DOCTOR INFORMATION",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Name: Dr. ${selectedPatientQueueItem.doctorName!}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Text(
                    "Occupation: Doctor",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // --- Items Table ---
            _buildItemsTable(),
            const SizedBox(height: 24),

            // --- Totals ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 250,
                  child: Column(
                    children: [
                      _buildTotalRow("Subtotal", subtotal),
                      _buildTotalRow("Discount", 0.00),
                      _buildTotalRow("Tax", 0.00),
                      const Divider(height: 10),
                      _buildTotalRow("TOTAL", total, isTotal: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- Buttons ---
            if (generatedPdfBytes != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text("Print"),
                    onPressed: () => onPrint(generatedPdfBytes!),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text("Save"),
                    onPressed: () => onSave(generatedPdfBytes!, generatedInvoiceNumber),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment_outlined),
                label: const Text("Proceed to Payment"),
                onPressed: onProceedToPayment,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.teal[700],
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: const Row(
            children: [
              Expanded(
                  flex: 7,
                  child: Text("ITEM/SERVICE",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 1,
                  child: Text("QTY",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text("RATE",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text("AMOUNT",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentBillItems.length,
          itemBuilder: (context, index) {
            final item = currentBillItems[index];
            return Container(
              color: index.isEven ? Colors.teal[50] : Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                      flex: 1,
                      child: Text(item.quantity.toString(),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(currencyFormat.format(item.unitPrice),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(currencyFormat.format(item.itemTotal),
                          textAlign: TextAlign.right,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500))),
                ],
              ),
            );
          },
        ),
        Divider(color: Colors.teal[700], thickness: 2, height: 2),
      ],
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14)),
          Text(currencyFormat.format(value),
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14,
                  color: isTotal ? Colors.black : Colors.grey[800])),
        ],
      ),
    );
  }
} 