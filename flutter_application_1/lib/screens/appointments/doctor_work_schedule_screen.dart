import 'package:flutter/material.dart';
import '../../models/doctor_schedule.dart';
import '../../models/user.dart';
import '../../services/doctor_schedule_service.dart';
import '../../services/api_service.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  User? _selectedDoctor;
  List<User> _doctors = [];
  DoctorSchedule? _doctorSchedule;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      setState(() => _isLoading = true);
      final users = await ApiService.getUsers();
      setState(() {
        _doctors = users.where((user) => user.role.toLowerCase() == 'doctor').toList();
        if (_doctors.isNotEmpty && _selectedDoctor == null) {
          _selectedDoctor = _doctors.first;
          _loadDoctorSchedule();
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load doctors: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDoctorSchedule() async {
    if (_selectedDoctor == null) return;

    try {
      setState(() => _isLoading = true);
      final schedule = await DoctorScheduleService.getDoctorSchedule(_selectedDoctor!.id);
      
      // If no schedule exists, create a default one
      if (schedule == null) {
        final defaultSchedule = DoctorSchedule.createDefault(
          doctorId: _selectedDoctor!.id,
          doctorName: _selectedDoctor!.fullName,
        );
        await DoctorScheduleService.saveDoctorSchedule(defaultSchedule);
        setState(() {
          _doctorSchedule = defaultSchedule;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _doctorSchedule = schedule;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load schedule: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditScheduleDialog() async {
    if (_doctorSchedule == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ScheduleEditDialog(schedule: _doctorSchedule!),
    );

    if (result != null) {
      final updatedSchedule = _doctorSchedule!.copyWith(
        arrivalTime: result['arrivalTime'],
        departureTime: result['departureTime'],
        notes: result['notes'].isEmpty ? null : result['notes'],
        updatedAt: DateTime.now(),
      );

      final success = await DoctorScheduleService.saveDoctorSchedule(updatedSchedule);
      
      if (success) {
        setState(() => _doctorSchedule = updatedSchedule);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Doctor schedule updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update schedule'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Work Schedule'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with doctor selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Doctor:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<User>(
                  value: _selectedDoctor,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _doctors.map((doctor) {
                    return DropdownMenuItem(
                      value: doctor,
                      child: Text(doctor.fullName),
                    );
                  }).toList(),
                  onChanged: (doctor) {
                    setState(() => _selectedDoctor = doctor);
                    _loadDoctorSchedule();
                  },
                ),
              ],
            ),
          ),

          // Schedule Display
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDoctorSchedule,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildScheduleDisplay(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleDisplay() {
    if (_doctorSchedule == null) return const SizedBox();

    final isCurrentlyWorking = _doctorSchedule!.isCurrentlyWorking();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Status Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCurrentlyWorking ? Icons.work : Icons.work_off,
                        color: isCurrentlyWorking ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentlyWorking ? Colors.green.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCurrentlyWorking ? 'Currently Working' : 'Not Working',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCurrentlyWorking ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Schedule Details Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Work Schedule',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _showEditScheduleDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Arrival Time
                  Row(
                    children: [
                      const Icon(Icons.login, color: Colors.green),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Arrival Time',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _formatTime(_doctorSchedule!.arrivalTime),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Departure Time
                  Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.orange),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Departure Time',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _formatTime(_doctorSchedule!.departureTime),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Duration
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.blue),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Work Duration',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${_doctorSchedule!.getDurationInHours().toStringAsFixed(1)} hours',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (_doctorSchedule!.notes != null && _doctorSchedule!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notes',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(_doctorSchedule!.notes!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
}

class _ScheduleEditDialog extends StatefulWidget {
  final DoctorSchedule schedule;

  const _ScheduleEditDialog({required this.schedule});

  @override
  State<_ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<_ScheduleEditDialog> {
  late TimeOfDay _arrivalTime;
  late TimeOfDay _departureTime;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _arrivalTime = widget.schedule.arrivalTime;
    _departureTime = widget.schedule.departureTime;
    _notesController = TextEditingController(text: widget.schedule.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectArrivalTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
    );
    if (picked != null) {
      setState(() => _arrivalTime = picked);
    }
  }

  Future<void> _selectDepartureTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked != null) {
      setState(() => _departureTime = picked);
    }
  }

  bool get _isValidTimeRange {
    final arrivalMinutes = _arrivalTime.hour * 60 + _arrivalTime.minute;
    final departureMinutes = _departureTime.hour * 60 + _departureTime.minute;
    return arrivalMinutes < departureMinutes;
  }

  String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.schedule.doctorName} Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arrival Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Arrival Time', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _selectArrivalTime,
                        icon: const Icon(Icons.login),
                        label: Text(_formatTime(_arrivalTime)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Departure Time', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _selectDepartureTime,
                        icon: const Icon(Icons.logout),
                        label: Text(_formatTime(_departureTime)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isValidTimeRange)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Departure time must be after arrival time',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidTimeRange
              ? () {
                  Navigator.of(context).pop({
                    'arrivalTime': _arrivalTime,
                    'departureTime': _departureTime,
                    'notes': _notesController.text,
                  });
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
