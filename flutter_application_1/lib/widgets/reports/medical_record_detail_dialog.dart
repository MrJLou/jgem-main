import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/patient_report.dart';
import 'package:intl/intl.dart';

class MedicalRecordDetailDialog extends StatelessWidget {
  final PatientReport report;

  const MedicalRecordDetailDialog({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final record = report.record;
    final patient = report.patient;
    final services = record.selectedServices ?? [];

    return AlertDialog(
      title: Text(patient.fullName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Patient ID: ${patient.id}', style: TextStyle(color: Colors.grey[600])),
            const Divider(height: 24),
            _buildDetailRow(label: 'Record ID', value: record.id),
            _buildDetailRow(label: 'Record Date', value: DateFormat('yyyy-MM-dd HH:mm').format(record.recordDate.toLocal())),
            _buildDetailRow(label: 'Record Type', value: record.recordType),
            _buildDetailRow(label: 'Doctor ID', value: record.doctorId),
            _buildDetailRow(label: 'Diagnosis', value: record.diagnosis ?? 'N/A'),
            _buildDetailRow(label: 'Treatment', value: record.treatment ?? 'N/A'),
            _buildDetailRow(label: 'Prescription', value: record.prescription ?? 'N/A'),
            _buildDetailRow(label: 'Lab Results', value: record.labResults ?? 'N/A'),
            _buildDetailRow(label: 'Notes', value: record.notes ?? 'N/A'),
            const SizedBox(height: 16),
            if (services.isNotEmpty) ...[
              Text('Services Rendered:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...services.map((service) => Text('• ${service['name'] ?? 'Unknown Service'}')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14.0, color: Colors.black87),
          children: <TextSpan>[
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
} 