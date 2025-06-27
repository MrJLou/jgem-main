import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:intl/intl.dart';

class InConsultationPatientList extends StatelessWidget {
  final List<ActivePatientQueueItem> patients;
  final ActivePatientQueueItem? selectedPatient;
  final Function(ActivePatientQueueItem) onPatientSelected;
  final NumberFormat currencyFormat;
  final bool isLoading;

  const InConsultationPatientList({
    super.key,
    required this.patients,
    required this.selectedPatient,
    required this.onPatientSelected,
    required this.currencyFormat,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (patients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No patients currently in consultation.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        final isSelected = selectedPatient?.queueEntryId == patient.queueEntryId;
        return Card(
          color: isSelected ? Colors.teal.shade50 : Colors.white,
          elevation: isSelected ? 3 : 1,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(patient.patientName),
            subtitle: Text('Total: ${currencyFormat.format(patient.totalPrice ?? 0)}'),
            onTap: () => onPatientSelected(patient),
            selected: isSelected,
          ),
        );
      },
    );
  }
} 