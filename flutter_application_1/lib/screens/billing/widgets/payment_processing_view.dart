import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/active_patient_queue_item.dart';
import '../../../models/bill_item.dart';

class PaymentProcessingView extends StatelessWidget {
  final String generatedInvoiceNumber;
  final ActivePatientQueueItem selectedPatientQueueItem;
  final List<BillItem> currentBillItems;
  final TextEditingController amountPaidController;
  final NumberFormat currencyFormat;
  final VoidCallback onConfirmAndPay;
  final VoidCallback onBackToInvoice;
  final bool isProcessing;

  const PaymentProcessingView({
    super.key,
    required this.generatedInvoiceNumber,
    required this.selectedPatientQueueItem,
    required this.currentBillItems,
    required this.amountPaidController,
    required this.currencyFormat,
    required this.onConfirmAndPay,
    required this.onBackToInvoice,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    double subtotal =
        currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.0; // Assuming discount is 0 for now
    double totalAmountDue = subtotal - discount; // No tax

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Process Payment for Invoice: $generatedInvoiceNumber",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700])),
          const SizedBox(height: 10),
          Text("Patient: ${selectedPatientQueueItem.patientName}",
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          Text("Total Amount Due: ${currencyFormat.format(totalAmountDue)}",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: amountPaidController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Enter Amount Paid (Cash)',
              hintText: 'e.g., ${currencyFormat.format(totalAmountDue)}',
              prefixText: '${currencyFormat.currencySymbol} ',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: Icon(Icons.money, color: Colors.green[700]),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter amount paid.';
              }
              final pVal = double.tryParse(value);
              if (pVal == null) return 'Invalid amount.';
              if (pVal < totalAmountDue) {
                return 'Amount is less than total due.';
              }
              return null;
            },
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isProcessing
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Confirm & Pay'),
              onPressed: isProcessing ? null : onConfirmAndPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Invoice'),
              onPressed: onBackToInvoice,
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
} 