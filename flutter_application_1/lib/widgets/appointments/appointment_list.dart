// Appointment list widget to display appointments
import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../utils/doctor_utils.dart';
import 'appointment_status_dropdown.dart';
import 'appointment_detail_dialog.dart';

class AppointmentList extends StatelessWidget {
  final List<Appointment> appointments;
  final Function(String, String) onUpdateStatus;
  final Function(Appointment) onEditAppointment;

  const AppointmentList({
    super.key,
    required this.appointments,
    required this.onUpdateStatus,
    required this.onEditAppointment,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const Center(
          child: Text('No appointments scheduled for this day.',
              style: TextStyle(fontSize: 16, color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        return AppointmentListCard(
          appointment: appointments[index],
          onUpdateStatus: onUpdateStatus,
          onEdit: () => onEditAppointment(appointments[index]),
        );
      },
    );
  }
}

class AppointmentListCard extends StatefulWidget {
  final Appointment appointment;
  final Function(String, String) onUpdateStatus;
  final VoidCallback onEdit;

  const AppointmentListCard({
    super.key,
    required this.appointment,
    required this.onUpdateStatus,
    required this.onEdit,
  });

  @override
  State<AppointmentListCard> createState() => _AppointmentListCardState();
}

class _AppointmentListCardState extends State<AppointmentListCard> {
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
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.schedule;

    switch (widget.appointment.status) {
      case 'Confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Completed':
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext context) =>
                AppointmentDetailDialog(appointment: widget.appointment),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Patient ID: ${widget.appointment.patientId}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Chip(
                    avatar: Icon(statusIcon, color: Colors.white, size: 16),
                    label: Text(widget.appointment.status,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: statusColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.medical_services, size: 16, color: Colors.teal[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Doctor: ${_doctorDisplayName.isNotEmpty ? _doctorDisplayName : 'Loading...'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _doctorDisplayName.isNotEmpty ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text('Time: ${widget.appointment.time.format(context)}'),
                ],
              ),
              if (widget.appointment.consultationType.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.medical_information, size: 16, color: Colors.purple[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Type: ${widget.appointment.consultationType}',
                            style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Change Status: '),
                  AppointmentStatusDropdown(
                    currentStatus: widget.appointment.status,
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        widget.onUpdateStatus(widget.appointment.id, newStatus);
                      }
                    },
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
