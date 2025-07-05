// Enhanced appointment card widget with status functionality
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../utils/doctor_utils.dart';
import 'appointments/appointment_status_dropdown.dart';
import 'appointments/appointment_detail_dialog.dart';

class AppointmentCard extends StatefulWidget {
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
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  String _doctorDisplayName = '';

  @override
  void initState() {
    super.initState();
    _loadDoctorName();
  }

  Future<void> _loadDoctorName() async {
    final doctorName = await DoctorUtils.getDoctorDisplayNameAsync(widget.appointment.doctorId);
    if (mounted) {
      setState(() {
        _doctorDisplayName = doctorName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = _getStatusColor(widget.appointment.status);
    IconData statusIcon = _getStatusIcon(widget.appointment.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 30),
        title: Text('Patient ID: ${widget.appointment.patientId}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_doctorDisplayName.isNotEmpty 
              ? _doctorDisplayName 
              : 'Doctor ID: ${widget.appointment.doctorId}'),
            Text('Time: ${widget.appointment.time.format(context)}'),
            if (widget.appointment.consultationType.isNotEmpty)
              Text('Consultation Type: ${widget.appointment.consultationType}'),
          ],
        ),
        trailing: widget.onUpdateStatus != null 
          ? AppointmentStatusDropdown(
              currentStatus: widget.appointment.status,
              onChanged: (newStatus) {
                if (newStatus != null) {
                  widget.onUpdateStatus!(widget.appointment.id, newStatus);
                }
              },
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: widget.onEdit,
                  ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
        isThreeLine: true,
        onTap: () {
          showDialog(
              context: context,
              builder: (BuildContext context) =>
                  AppointmentDetailDialog(appointment: widget.appointment));
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
