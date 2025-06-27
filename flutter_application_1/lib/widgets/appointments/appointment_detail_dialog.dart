// Appointment detail dialog widget
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';

class AppointmentDetailDialog extends StatelessWidget {
  final Appointment appointment;
  
  const AppointmentDetailDialog({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Appointment Details - PID: ${appointment.patientId}'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('Patient ID: ${appointment.patientId}'),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(appointment.date)}'),
            Text('Time: ${appointment.time.format(context)}'),
            Text('Doctor ID: ${appointment.doctorId}'),
            Text('Status: ${appointment.status}'),
            if (appointment.consultationType.isNotEmpty)
              Text('Consultation Type: ${appointment.consultationType}'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
