import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/active_patient_queue_item.dart';
import '../../../models/bill_item.dart';

class PaymentCompleteView extends StatelessWidget {
  final String generatedInvoiceNumber;
  final String paymentReferenceNumber;
  final ActivePatientQueueItem selectedPatientQueueItem;
  final List<BillItem> currentBillItems;
  final double paymentChange;
  final NumberFormat currencyFormat;
  final VoidCallback onPrintReceipt;
  final VoidCallback onNewInvoice;
  final Widget pdfPreviewThumbnail;

  const PaymentCompleteView({
    super.key,
    required this.generatedInvoiceNumber,
    required this.paymentReferenceNumber,
    required this.selectedPatientQueueItem,
    required this.currentBillItems,
    required this.paymentChange,
    required this.currencyFormat,
    required this.onPrintReceipt,
    required this.onNewInvoice,
    required this.pdfPreviewThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    double subtotal =
        currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.0; // Assuming discount is 0
    double totalBillAmount = subtotal - discount; // No tax
    double amountPaid = totalBillAmount +
        paymentChange; // This is correct as change is amountPaid - totalBill

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 60),
          const SizedBox(height: 20),
          Text("Payment Successful!",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700])),
          const SizedBox(height: 20),
          Text("Invoice #: $generatedInvoiceNumber",
              style: const TextStyle(fontSize: 16)),
          Text("Payment Ref #: $paymentReferenceNumber",
              style: const TextStyle(fontSize: 16)),
          Text("Patient: ${selectedPatientQueueItem.patientName}",
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 15),
          Text("Total Bill: ${currencyFormat.format(totalBillAmount)}",
              style: const TextStyle(fontSize: 16)),
          Text("Amount Paid: ${currencyFormat.format(amountPaid)}",
              style: const TextStyle(fontSize: 16)),
          Text("Change Given: ${currencyFormat.format(paymentChange)}",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          pdfPreviewThumbnail,
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.print_outlined),
                label: const Text("Print Receipt"),
                onPressed: onPrintReceipt,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(width: 15),
              ElevatedButton(
                onPressed: onNewInvoice,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text("New Invoice/Payment"),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 