import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:intl/intl.dart';

class PrepareInvoiceView extends StatelessWidget {
  final ActivePatientQueueItem patient;
  final NumberFormat currencyFormat;
  final VoidCallback onGenerateAndPay;
  final VoidCallback onSaveUnpaid;

  const PrepareInvoiceView({
    super.key,
    required this.patient,
    required this.currencyFormat,
    required this.onGenerateAndPay,
    required this.onSaveUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prepare Invoice for: ${patient.patientName}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800]),
              ),
              const SizedBox(height: 10),
              Text('Patient ID: ${patient.patientId ?? "N/A"}'),
              Text('Queue Number: ${patient.queueNumber}'),
              Text(
                  'Total Price (from consultation): ${currencyFormat.format(patient.totalPrice ?? 0.0)}'),
              const Divider(height: 25),
              const Text('Services/Items to be Invoiced:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (patient.selectedServices != null &&
                  patient.selectedServices!.isNotEmpty)
                ...patient.selectedServices!.map((service) {
                  final serviceName = service['name'] ?? 'Unknown Service';
                  final price = service['price'] as num? ?? 0.0;
                  return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(serviceName),
                      trailing: Text(currencyFormat.format(price)));
                })
              else if (patient.conditionOrPurpose != null &&
                  patient.conditionOrPurpose!.isNotEmpty)
                ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(patient.conditionOrPurpose!),
                    trailing:
                        Text(currencyFormat.format(patient.totalPrice ?? 0.0)))
              else
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                        "No specific services listed. Invoice will use total price.",
                        style: TextStyle(fontStyle: FontStyle.italic))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Generate & Pay'),
                      onPressed: onGenerateAndPay,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Save Unpaid'),
                      onPressed: onSaveUnpaid,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 