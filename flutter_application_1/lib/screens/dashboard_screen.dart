import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import 'user_management_screen.dart';
import 'registration/registration_hub_screen.dart';
import 'search/search_hub_screen.dart';
import 'laboratory/laboratory_hub_screen.dart';
import 'patient/patient_queue_hub_screen.dart';
import 'analytics/patient_analytics_screen.dart';
import 'reports/report_hub_screen.dart'; // Import the ReportHubScreen
import 'billing/billing_hub_screen.dart';
import 'payment/payment_hub_screen.dart';
import 'maintenance/maintenance_hub_screen.dart';
import 'help/help_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String accessLevel;

  const DashboardScreen({super.key, required this.accessLevel});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 2; // Default to Appointment module
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = [];
  bool _isAddingAppointment = false;
  bool _isLoading = false;
  final _appointmentFormKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Generate unique patient ID
  String _generatePatientId() {
    return 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    // Load mock data initially
    setState(() {
      _appointments = [
        Appointment(
          id: '1',
          patientName: 'John Doe',
          patientId: 'PT-1001',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 9, minute: 0),
          doctor: 'Dr. Smith',
          status: 'Confirmed',
          notes: 'Regular checkup',
        ),
        Appointment(
          id: '2',
          patientName: 'Jane Smith',
          patientId: 'PT-1002',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 11, minute: 30),
          doctor: 'Dr. Johnson',
          status: 'Pending',
          notes: 'New patient consultation',
        ),
        Appointment(
          id: '3',
          patientName: 'Robert Brown',
          patientId: 'PT-1003',
          date: DateTime.now().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 14, minute: 0),
          doctor: 'Dr. Smith',
          status: 'Confirmed',
          notes: 'Follow-up appointment',
        ),
      ];
    });
    // Then try to load from API
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final apiAppointments = await ApiService.getAppointments(_selectedDate);
      if (apiAppointments.isNotEmpty) {
        setState(() => _appointments = apiAppointments);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load appointments. Please try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAppointment() async {
    if (_appointmentFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String newId;
        // Generate new ID if patient ID is empty
        if (_patientIdController.text.isEmpty) {
          _patientIdController.text = _generatePatientId();
          newId = DateTime.now().millisecondsSinceEpoch.toString();
        } else {
          // Check if patient ID already exists
          try {
            newId = _appointments
                .firstWhere((a) => a.patientId == _patientIdController.text)
                .id;
          } catch (e) {
            // If not found, generate new ID
            newId = DateTime.now().millisecondsSinceEpoch.toString();
          }
        }

        final newAppointment = Appointment(
          id: newId,
          patientName: _patientNameController.text,
          patientId: _patientIdController.text,
          date: _selectedDate,
          time: _selectedTime,
          doctor: _doctorController.text,
          status: 'Confirmed',
          notes: _notesController.text,
        );

        // Try API save first
        try {
          await ApiService.saveAppointment(newAppointment);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment saved successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          // Fallback to local storage if API fails
          setState(() {
            _appointments.add(newAppointment);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally. Sync when connection is restored.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }

        await _loadAppointments();
        setState(() => _isAddingAppointment = false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save appointment. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAppointmentStatus(String id, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      // Find the appointment
      final index = _appointments.indexWhere((appt) => appt.id == id);
      if (index != -1) {
        // Try API update first
        try {
          await ApiService.updateAppointmentStatus(id, newStatus);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          // Fallback to local update
          setState(() {
            _appointments[index] =
                _appointments[index].copyWith(status: newStatus);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Status updated locally. Sync when connection is restored.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      await _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAppointment(String id) async {
    setState(() => _isLoading = true);
    try {
      // Try API delete first
      try {
        await ApiService.deleteAppointment(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Fallback to local delete
        setState(() {
          _appointments.removeWhere((appt) => appt.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleted locally. Sync when connection is restored.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete appointment. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Record Management',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) async {
              // Handle profile actions
              if (value == 'Logout') {
                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  // Clear auth data - ensure this completes
                  await AuthService.logout();

                  // Pop the loading dialog
                  if (context.mounted) Navigator.of(context).pop();

                  // Navigate to login screen and clear the navigation stack
                  if (context.mounted) {
                    // This completely replaces the navigation stack with just the login screen
                    await Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false, // This removes all existing routes
                    );
                  }
                } catch (e) {
                  // Handle any errors during logout
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Profile', 'Settings', 'Logout'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[700]!, Colors.teal[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.teal),
                  ),
                  SizedBox(height: 10),
                  Text('Admin User',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('Administrator',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.people, 'Registration', 0),
            _buildDrawerItem(Icons.search, 'Search', 1),
            _buildDrawerItem(Icons.calendar_today, 'Appointments', 2),
            _buildDrawerItem(Icons.medical_services, 'Lab Histories', 3),
            _buildDrawerItem(Icons.people_alt, 'Patient Queue', 4),
            _buildDrawerItem(Icons.analytics, 'Patient Analytics', 5),
            _buildDrawerItem(Icons.report, 'Reports', 6),
            _buildDrawerItem(Icons.receipt, 'Billing', 7),
            _buildDrawerItem(Icons.payment, 'Payment', 8),
            _buildDrawerItem(Icons.settings, 'Maintenance', 9),
            _buildDrawerItem(Icons.help, 'Help', 10),
            _buildDrawerItem(Icons.info, 'About', 11),
          ],
        ),
      ),
      body: _buildSelectedModule(),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isAddingAppointment = true;
                  _patientNameController.clear();
                  _patientIdController.clear();
                  _patientIdController.text = _generatePatientId();
                  _doctorController.clear();
                  _notesController.clear();
                  _selectedTime = TimeOfDay.now();
                });
              },
              backgroundColor: Colors.teal[700],
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon,
          color: _selectedIndex == index ? Colors.teal : Colors.grey[700]),
      title: Text(title,
          style: TextStyle(
            color: _selectedIndex == index ? Colors.teal : Colors.black,
            fontWeight:
                _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
          )),
      selected: _selectedIndex == index,
      selectedTileColor: Colors.teal[50],
      onTap: () {
        setState(() {
          _selectedIndex = index;
          Navigator.pop(context);
        });
      },
    );
  }

  Widget _buildSelectedModule() {
    switch (_selectedIndex) {
      case 0:
        return RegistrationHubScreen();
      case 1:
        return SearchHubScreen();
      case 2:
        return _buildAppointmentModule();
      case 3:
        return LaboratoryHubScreen();
      case 4: // Patient Queue module
        return PatientQueueHubScreen(); // Connect the Patient Queue Hub
      case 5: // Patient Analytics module
        return PatientAnalyticsScreen(); // Connect the Patient Analytics Screen
      case 6: // Report module
        return ReportHubScreen(); // Connect the Report Hub Screen
      case 7: // Billing module
        return BillingHubScreen(); // Connect the Billing Hub Screen
      case 8: // Payment module
        return PaymentHubScreen(); // Connect the Payment Hub Screen
      case 9: // Maintenance module
        return MaintenanceHubScreen(); // Connect the Maintenance Hub Screen
      case 10: // Help module
        return HelpScreen(); // Connect the Help Screen
      default:
        return Center(
          child: Text('Module under development',
              style: TextStyle(color: Colors.teal[700], fontSize: 18)),
        );
    }
  }

  Widget _buildAppointmentModule() {
    final filteredAppointments = _appointments
        .where((appt) =>
            appt.date.year == _selectedDate.year &&
            appt.date.month == _selectedDate.month &&
            appt.date.day == _selectedDate.day)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Appointment Schedule',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDatePicker(),
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal[700],
                ),
              ),
            ],
          ),
        ),
        if (_isAddingAppointment) _buildAddAppointmentForm(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredAppointments.isEmpty
                  ? const Center(
                      child: Text('No appointments for selected date'))
                  : ListView.builder(
                      itemCount: filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = filteredAppointments[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal[100],
                              child:
                                  const Icon(Icons.person, color: Colors.teal),
                            ),
                            title: Text(
                              appointment.patientName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('ID: ${appointment.patientId}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Time: ${appointment.time.format(context)} with ${appointment.doctor}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            _getStatusColor(appointment.status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        appointment.status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (appointment.notes != null &&
                                    appointment.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Notes: ${appointment.notes}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) =>
                                  _handleAppointmentAction(value, appointment),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'confirm',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Confirm'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Row(
                                    children: [
                                      Icon(Icons.cancel, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Cancel'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'complete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.done_all, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Complete'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleAppointmentAction(String action, Appointment appointment) {
    switch (action) {
      case 'edit':
        setState(() {
          _isAddingAppointment = true;
          _patientNameController.text = appointment.patientName;
          _patientIdController.text = appointment.patientId;
          _doctorController.text = appointment.doctor;
          _selectedTime = appointment.time;
          _selectedDate = appointment.date;
          _notesController.text = appointment.notes ?? '';
          _appointments.remove(appointment);
        });
        break;
      case 'confirm':
        _updateAppointmentStatus(appointment.id, 'Confirmed');
        break;
      case 'cancel':
        _updateAppointmentStatus(appointment.id, 'Cancelled');
        break;
      case 'complete':
        _updateAppointmentStatus(appointment.id, 'Completed');
        break;
      case 'delete':
        _deleteAppointment(appointment.id);
        break;
    }
  }

  Widget _buildAddAppointmentForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _appointmentFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _patientNameController.text.isEmpty
                    ? 'Add New Appointment'
                    : 'Edit Appointment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'Patient Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter patient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _patientIdController,
                decoration: const InputDecoration(
                  labelText: 'Patient ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter patient ID';
                  }
                  if (_appointments.any((a) =>
                      a.patientId == value &&
                      a.id !=
                          _appointments
                              .firstWhere((a) => a.patientId == value)
                              .id)) {
                    return 'Patient ID already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doctorController,
                decoration: const InputDecoration(
                  labelText: 'Doctor',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_services),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter doctor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDatePicker(),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _isAddingAppointment = false);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.teal[700]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save'),
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
