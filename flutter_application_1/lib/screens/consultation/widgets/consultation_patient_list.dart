import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';

class ConsultationPatientList extends StatelessWidget {
  final List<ActivePatientQueueItem> patients;
  final ActivePatientQueueItem? selectedPatient;
  final Function(ActivePatientQueueItem) onPatientSelected;

  const ConsultationPatientList({
    super.key,
    required this.patients,
    this.selectedPatient,
    required this.onPatientSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No patients in consultation',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Patients will appear here when they are currently in consultation',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        final isSelected =
            selectedPatient?.queueEntryId == patient.queueEntryId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.teal[50] : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.teal[600] : Colors.grey[400],
              child: Text(
                patient.patientName.isNotEmpty
                    ? patient.patientName[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              patient.patientName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.teal[800] : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Queue #${patient.queueNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.teal[600] : Colors.grey[600],
                  ),
                ),
                if (patient.selectedServices != null &&
                    patient.selectedServices!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4.0,
                    runSpacing: 2.0,
                    children: patient.selectedServices!.take(2).map((service) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? Colors.teal[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service['name'] ?? 'Service',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.teal[700]
                                : Colors.grey[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (patient.selectedServices!.length > 2)
                    Text(
                      '+${patient.selectedServices!.length - 2} more',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.teal[600] : Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.teal[600])
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => onPatientSelected(patient),
          ),
        );
      },
    );
  }
}
