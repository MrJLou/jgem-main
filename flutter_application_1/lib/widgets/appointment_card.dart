// Enhanced appointment card widget with status functionality
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import 'appointments/appointment_status_dropdown.dart';
import 'appointments/appointment_detail_dialog.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(String, String)? onUpdateStatus;

  const AppointmentCard({
    super.key, 
    required this.appointment,
    this.onEdit,
    this.onDelete,
    this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = _getStatusColor(appointment.status);
    IconData statusIcon = _getStatusIcon(appointment.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 30),
        title: Text('Patient ID: ${appointment.patientId}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor ID: ${appointment.doctorId}'),
            Text('Time: ${appointment.time.format(context)}'),
            if (appointment.consultationType.isNotEmpty)
              Text('Consultation Type: ${appointment.consultationType}'),
          ],
        ),
        trailing: onUpdateStatus != null 
          ? AppointmentStatusDropdown(
              currentStatus: appointment.status,
              onChanged: (newStatus) {
                if (newStatus != null) {
                  onUpdateStatus!(appointment.id, newStatus);
                }
              },
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: onEdit,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
              ],
            ),
        isThreeLine: true,
        onTap: () {
          showDialog(
              context: context,
              builder: (BuildContext context) =>
                  AppointmentDetailDialog(appointment: appointment));
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      case 'Completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Pending':
        return Icons.hourglass_empty;
      case 'Cancelled':
        return Icons.cancel_outlined;
      case 'Completed':
        return Icons.done_all_outlined;
      default:
        return Icons.schedule;
    }
  }
}
