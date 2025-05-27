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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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

  Widget _currentScreen = const Center(child: CircularProgressIndicator());
  String _currentTitle = 'Appointment Schedule';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      // Try to get appointments from API
      try {
        final apiAppointments = await ApiService.getAppointments(_selectedDate);
        if (apiAppointments.isNotEmpty) {
          setState(() => _appointments = apiAppointments);
        }
      } catch (e) {
        // Silently fail and keep existing appointments
        print('Failed to load appointments from API: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Mock data - will be replaced by actual API call later
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
        Appointment(
          id: '4',
          patientName: 'Mary Johnson',
          patientId: 'PT-1004',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 15, minute: 30),
          doctor: 'Dr. Wilson',
          status: 'Cancelled',
          notes: 'Annual physical examination',
        ),
        Appointment(
          id: '5',
          patientName: 'David Lee',
          patientId: 'PT-1005',
          date: DateTime.now().add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 10, minute: 0),
          doctor: 'Dr. Johnson',
          status: 'Pending',
          notes: 'Follow-up on lab results',
        ),
      ];

      // Try to get appointments from API (can fail silently for now)
      try {
        final apiAppointments = await ApiService.getAppointments(_selectedDate);
        if (apiAppointments.isNotEmpty) {
          _appointments = apiAppointments;
        }
      } catch (e) {
        // Silently fail and use mock data
        print('Using mock data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentScreen = _buildAppointmentModule();
        });
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (_appointmentFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String newId;

        if (_patientIdController.text.isEmpty) {
          _patientIdController.text = _generatePatientId();
          newId = DateTime.now().millisecondsSinceEpoch.toString();
        } else {
          try {
            newId = _appointments
                .firstWhere((a) => a.patientId == _patientIdController.text)
                .id;
          } catch (e) {
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
      final index = _appointments.indexWhere((appt) => appt.id == id);
      if (index != -1) {
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
          setState(() {
            _appointments[index] =
                _appointments[index].copyWith(status: newStatus);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Updated locally. Sync when connection is restored.'),
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

  void _navigateToScreen(Widget screen, String title) {
    Navigator.pop(context); // Close drawer
    setState(() {
      _currentScreen = screen;
      _currentTitle = title;
      // Reset appointment state when navigating away
      if (title != 'Appointment Schedule') {
        _isAddingAppointment = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        elevation: 4,
        title: Text(
          _currentTitle,
          style: const TextStyle(color: Colors.white),
        ),
        leading: _currentTitle != 'Appointment Schedule'
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentScreen = _buildAppointmentModule();
                  _currentTitle = 'Appointment Schedule';
                });
              },
            )
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) async {
              if (value == 'Logout') {
                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  await AuthService.logout();
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    await Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
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
                  Text(
                    'Admin User',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Administrator',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('Registration'),
              onTap: () => _navigateToScreen(RegistrationHubScreen(), 'Registration Portal'),
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Search'),
              onTap: () => _navigateToScreen(SearchHubScreen(), 'Search Portal'),
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text('Appointments'),
              onTap: () => _navigateToScreen(_buildAppointmentModule(), 'Appointment Schedule'),
            ),
            ListTile(
              leading: Icon(Icons.medical_services),
              title: Text('Lab Histories'),
              onTap: () => _navigateToScreen(LaboratoryHubScreen(), 'Laboratory Hub'),
            ),
            ListTile(
              leading: Icon(Icons.people_alt),
              title: Text('Patient Queue'),
              onTap: () => _navigateToScreen(PatientQueueHubScreen(), 'Patient Queue'),
            ),
            ListTile(
              leading: Icon(Icons.analytics),
              title: Text('Patient Analytics'),
              onTap: () => _navigateToScreen(PatientAnalyticsScreen(), 'Patient Analytics'),
            ),
            ListTile(
              leading: Icon(Icons.report),
              title: Text('Reports'),
              onTap: () => _navigateToScreen(ReportHubScreen(), 'Reports'),
            ),
            ListTile(
              leading: Icon(Icons.receipt),
              title: Text('Billing'),
              onTap: () => _navigateToScreen(BillingHubScreen(), 'Billing'),
            ),
            ListTile(
              leading: Icon(Icons.payment),
              title: Text('Payment'),
              onTap: () => _navigateToScreen(PaymentHubScreen(), 'Payment'),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Maintenance'),
              onTap: () => _navigateToScreen(MaintenanceHubScreen(), 'Maintenance'),
            ),
            ListTile(
              leading: Icon(Icons.help),
              title: Text('Help'),
              onTap: () => _navigateToScreen(HelpScreen(), 'Help'),
            ),
          ],
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_currentTitle != 'Appointment Schedule') {
            setState(() {
              _currentScreen = _buildAppointmentModule();
              _currentTitle = 'Appointment Schedule';
            });
            return false;
          }
          return true;
        },
        child: _currentScreen,
      ),
      floatingActionButton: _currentTitle == 'Appointment Schedule'
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

  Widget _buildAppointmentModule() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _showDatePicker,
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
              : _buildAppointmentList(),
        ),
      ],
    );
  }

  Widget _buildAppointmentList() {
    final filteredAppointments = _appointments
        .where((appt) =>
            appt.date.year == _selectedDate.year &&
            appt.date.month == _selectedDate.month &&
            appt.date.day == _selectedDate.day)
        .toList();

    return filteredAppointments.isEmpty
        ? const Center(child: Text('No appointments for selected date'))
        : ListView.builder(
            itemCount: filteredAppointments.length,
            itemBuilder: (context, index) {
              final appointment = filteredAppointments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: const Icon(Icons.person, color: Colors.teal),
                  ),
                  title: Text(appointment.patientName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${appointment.patientId}'),
                      Text(
                        'Time: ${appointment.time.format(context)} with ${appointment.doctor}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(appointment.status),
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
                      if (appointment.notes?.isNotEmpty ?? false)
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
                    onSelected: (value) => _handleAppointmentAction(value, appointment),
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
                            Icon(Icons.check_circle, color: Colors.green),
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
