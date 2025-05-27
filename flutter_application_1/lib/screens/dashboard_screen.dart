import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/registration/patient_registration_screen.dart';
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
  int _selectedIndex = 0; // Default to Registration (first item)
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = [];
  bool _isAddingAppointment = false;
  bool _isLoading = false;
  // final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>(); // May not be needed

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

  // Widget _currentScreen = const Center(child: CircularProgressIndicator()); // Replaced by _screens logic
  late String _currentTitle; // Updated to be initialized in initState

  final List<String> _menuTitles = [
    'Registration',
    'Maintenance',
    'Search',
    'Patient Laboratory Histories',
    'Patient Queue',
    'Appointment Schedule',
    'Patient Analytics',
    'Report',
    'Payment',
    'Billing',
    'Help',
    'About',
  ];

  late List<Widget> _screens; // Updated to be initialized in initState

  @override
  void initState() {
    super.initState();
    _currentTitle = _menuTitles[_selectedIndex];
    _screens = [
      RegistrationHubScreen(),
      MaintenanceHubScreen(),
      SearchHubScreen(),
      LaboratoryHubScreen(), // Assuming this is Patient Lab Histories
      PatientQueueHubScreen(),
      _buildAppointmentModule(), // Existing appointment module
      PatientAnalyticsScreen(),
      ReportHubScreen(),
      PaymentHubScreen(),
      BillingHubScreen(),
      HelpScreen(),
      const Center(child: Text('About Screen - Placeholder')), // Placeholder
    ];
    _loadInitialData(); // Keep this for now, relevant to appointment module
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
          // _currentScreen = _buildAppointmentModule(); // This will be managed by NavigationRail
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
        // Reload appointments to reflect changes from API if successful
        await _loadAppointments();
      }
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

  Widget _buildAppointmentModule() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1));
                          _loadAppointments();
                        });
                      },
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.add(const Duration(days: 1));
                          _loadAppointments();
                        });
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Appointment'),
                      onPressed: () {
                        _patientIdController.clear();
                        _patientNameController.clear();
                        _doctorController.clear();
                        _notesController.clear();
                        _selectedTime = TimeOfDay.now();
                        setState(() => _isAddingAppointment = true);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isAddingAppointment
                    ? AppointmentForm(
                        formKey: _appointmentFormKey,
                        patientNameController: _patientNameController,
                        patientIdController: _patientIdController,
                        doctorController: _doctorController,
                        notesController: _notesController,
                        selectedDate: _selectedDate,
                        selectedTime: _selectedTime,
                        onTimeChanged: (time) =>
                            setState(() => _selectedTime = time),
                        onSave: _saveAppointment,
                        onCancel: () =>
                            setState(() => _isAddingAppointment = false),
                        generatePatientId: _generatePatientId,
                      )
                    : _buildAppointmentList(
                        _appointments
                            .where((appt) =>
                                appt.date.year == _selectedDate.year &&
                                appt.date.month == _selectedDate.month &&
                                appt.date.day == _selectedDate.day)
                            .toList(),
                        _updateAppointmentStatus),
              ),
            ],
          );
  }

  // Method to handle logout
  void _logout() async {
    await AuthService.logout(); // Assuming AuthService has a logout method
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> menuItems = [];

    if (widget.accessLevel == 'admin') {
      // Admin sees all options based on Figure 8 MedTech Main
      menuItems = [
        // Example:
        ListTile(
            title: const Text('Registration (User Accounts)'),
            onTap: () {/* Navigate to UserManagementScreen */}),
        ListTile(title: const Text('Maintenance'), onTap: () {/* ... */}),
        ListTile(title: const Text('Search'), onTap: () {/* ... */}),
        ListTile(
            title: const Text('Patient Laboratory Histories'),
            onTap: () {/* ... */}),
        ListTile(title: const Text('Patient Queue'), onTap: () {/* ... */}),
        ListTile(
            title: const Text('Appointment Schedule'), onTap: () {/* ... */}),
        ListTile(title: const Text('Patient Analytics'), onTap: () {/* ... */}),
        ListTile(title: const Text('Report'), onTap: () {/* ... */}),
        ListTile(title: const Text('Payment'), onTap: () {/* ... */}),
        ListTile(title: const Text('Billing'), onTap: () {/* ... */}),
        ListTile(title: const Text('Help'), onTap: () {/* ... */}),
        ListTile(title: const Text('About'), onTap: () {/* ... */}),
        // ... add all admin menu items
      ];
    } else if (widget.accessLevel == 'doctor') {
      // Doctor sees options based on Figure 7 MedTech Main (Doctor view)
      menuItems = [
        // Example:
        ListTile(title: const Text('Search'), onTap: () {/* ... */}),
        ListTile(
            title: const Text('Patient Laboratory Histories'),
            onTap: () {/* ... */}),
        ListTile(title: const Text('Patient Queue'), onTap: () {/* ... */}),
        ListTile(
            title: const Text('Appointment Schedule'), onTap: () {/* ... */}),
        ListTile(title: const Text('Patient Analytics'), onTap: () {/* ... */}),
        ListTile(title: const Text('Report'), onTap: () {/* ... */}),
        ListTile(
            title: const Text('Payment'),
            onTap: () {
              /* ... */
            }), // Assuming A1 leads to Payment/Billing/Help/About
        ListTile(title: const Text('Billing'), onTap: () {/* ... */}),
        ListTile(title: const Text('Help'), onTap: () {/* ... */}),
        ListTile(title: const Text('About'), onTap: () {/* ... */}),
        // ... add all doctor menu items
      ];
    } else if (widget.accessLevel == 'medtech') {
      // Medtech sees options based on Figure 8 MedTech Main, but with specific restrictions.
      // The "Registration" for MedTech should lead to Patient Registration.
      menuItems = [
        // Example:
        ListTile(
            title: const Text('Registration (Patients)'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PatientRegistrationScreen()),
              );
            }),
        // Maintenance is typically an Admin function.
        ListTile(title: const Text('Search'), onTap: () {/* ... */}),
        ListTile(
            title: const Text('Patient Laboratory Histories'),
            onTap: () {/* ... */}),
        ListTile(title: const Text('Patient Queue'), onTap: () {/* ... */}),
        // G Connector items for MedTech (from Figure 8, left flow after Patient Queue)
        ListTile(
            title: const Text('Appointment Schedule'), onTap: () {/* ... */}),
        ListTile(title: const Text('Patient Analytics'), onTap: () {/* ... */}),
        ListTile(title: const Text('Report'), onTap: () {/* ... */}),
        ListTile(title: const Text('Payment'), onTap: () {/* ... */}),
        ListTile(title: const Text('Billing'), onTap: () {/* ... */}),
        // H Connector items for MedTech (from Figure 8, right flow after Billing)
        ListTile(title: const Text('Help'), onTap: () {/* ... */}),
        ListTile(title: const Text('About'), onTap: () {/* ... */}),
        // ... add all medtech menu items
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - ${widget.accessLevel}'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
                _currentTitle = _menuTitles[index];
                // If the selected screen is not the appointment module,
                // reset appointment specific state if necessary
                if (_menuTitles[index] != 'Appointment Schedule') {
                  _isAddingAppointment = false;
                }
              });
            },
            labelType: NavigationRailLabelType.all,
            selectedLabelTextStyle: TextStyle(color: Colors.teal[700]),
            unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.teal[100],
                    child: Icon(Icons.admin_panel_settings,
                        size: 30, color: Colors.teal[800]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admin', // Or dynamically set username
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal[800]),
                  ),
                ],
              ),
            ),
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.app_registration),
                selectedIcon: Icon(Icons.app_registration, color: Colors.teal),
                label: Text('Registration'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build_circle_outlined),
                selectedIcon: Icon(Icons.build_circle, color: Colors.teal),
                label: Text('Maintenance'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search, color: Colors.teal),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.science_outlined),
                selectedIcon: Icon(Icons.science, color: Colors.teal),
                label: Text('Lab Histories'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt, color: Colors.teal),
                label: Text('Patient Queue'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today, color: Colors.teal),
                label: Text('Appointments'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics, color: Colors.teal),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description, color: Colors.teal),
                label: Text('Report'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payment_outlined),
                selectedIcon: Icon(Icons.payment, color: Colors.teal),
                label: Text('Payment'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: Colors.teal),
                label: Text('Billing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.help_outline),
                selectedIcon: Icon(Icons.help, color: Colors.teal),
                label: Text('Help'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info, color: Colors.teal),
                label: Text('About'),
              ),
            ],
            backgroundColor: Colors.grey[100],
            elevation: 4,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // This is the main content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // child: _currentScreen, // Old way
              child: _screens[
                  _selectedIndex], // New way: display screen from the list
            ),
          )
        ],
      ),
    );
  }
}

class AppointmentForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController patientNameController;
  final TextEditingController patientIdController;
  final TextEditingController doctorController;
  final TextEditingController notesController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String Function() generatePatientId;

  const AppointmentForm({
    super.key,
    required this.formKey,
    required this.patientNameController,
    required this.patientIdController,
    required this.doctorController,
    required this.notesController,
    required this.selectedDate,
    required this.selectedTime,
    required this.onTimeChanged,
    required this.onSave,
    required this.onCancel,
    required this.generatePatientId,
  });

  @override
  _AppointmentFormState createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.selectedTime,
    );
    if (picked != null && picked != widget.selectedTime) {
      widget.onTimeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: widget.formKey,
        child: ListView(
          children: <Widget>[
            Text(
              'Add New Appointment on ${DateFormat('yyyy-MM-dd').format(widget.selectedDate)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.patientIdController,
              decoration: InputDecoration(
                labelText: 'Patient ID (auto-generated if empty)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fiber_new),
                  tooltip: 'Generate New ID',
                  onPressed: () {
                    widget.patientIdController.text =
                        widget.generatePatientId();
                  },
                ),
              ),
              // validator: (value) { // Optional: Add validation if ID is manually entered
              //   if (value != null && value.isNotEmpty && !value.startsWith('PT-')) {
              //     return 'Patient ID should start with PT-';
              //   }
              //   return null;
              // },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.patientNameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter patient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.doctorController,
              decoration: const InputDecoration(
                labelText: 'Doctor',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter doctor name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              title:
                  Text('Selected Time: ${widget.selectedTime.format(context)}'),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.onSave,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white),
                  child: const Text('SAVE APPOINTMENT'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildAppointmentList(
    List<Appointment> appointments, Function(String, String) onUpdateStatus) {
  if (appointments.isEmpty) {
    return const Center(child: Text('No appointments for this date.'));
  }
  return ListView.builder(
    itemCount: appointments.length,
    itemBuilder: (context, index) {
      return _buildAppointmentCard(
          appointments[index], onUpdateStatus, context);
    },
  );
}

Widget _buildAppointmentCard(Appointment appointment,
    Function(String, String) onUpdateStatus, BuildContext context) {
  Color statusColor = Colors.grey;
  IconData statusIcon = Icons.schedule;

  switch (appointment.status) {
    case 'Confirmed':
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      break;
    case 'Pending':
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
      break;
    case 'Cancelled':
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
      break;
    case 'Completed': // Added completed status
      statusColor = Colors.blue;
      statusIcon = Icons.done_all_outlined;
      break;
  }

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    elevation: 2,
    child: ListTile(
      leading: Icon(statusIcon, color: statusColor, size: 30),
      title: Text(
        '${appointment.patientName} (${appointment.patientId})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Doctor: ${appointment.doctor}'),
          Text('Time: ${appointment.time.format(context)}'),
          if (appointment.notes != null && appointment.notes!.isNotEmpty)
            Text('Notes: ${appointment.notes}'),
        ],
      ),
      trailing: _buildStatusDropdown(appointment.status, (newStatus) {
        if (newStatus != null) {
          onUpdateStatus(appointment.id, newStatus);
        }
      }),
      isThreeLine: true, // Adjust if notes make it longer
      onTap: () {
        // Optional: Show details or edit options on tap
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AppointmentDetailDialog(appointment: appointment);
          },
        );
      },
    ),
  );
}

Widget _buildStatusDropdown(String currentStatus, Function(String?) onChanged) {
  List<String> statuses = ['Pending', 'Confirmed', 'Cancelled', 'Completed'];
  // Ensure currentStatus is always in the list to avoid DropdownButton error
  if (!statuses.contains(currentStatus)) {
    statuses.add(currentStatus);
  }
  return DropdownButton<String>(
    value: currentStatus,
    items: statuses.map((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList(),
    onChanged: onChanged,
    underline: Container(), // Remove underline for a cleaner look
    style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.normal),
    iconEnabledColor: Colors.teal[700],
  );
}

class AppointmentList extends StatelessWidget {
  final List<Appointment> appointments;
  final Function(String, String) onUpdateStatus;
  final Function(Appointment) onEditAppointment; // Add this callback

  const AppointmentList({
    super.key,
    required this.appointments,
    required this.onUpdateStatus,
    required this.onEditAppointment, // Add this
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const Center(
        child: Text(
          'No appointments scheduled for this day.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        return AppointmentCard(
          appointment: appointments[index],
          onUpdateStatus: onUpdateStatus,
          onEdit: () =>
              onEditAppointment(appointments[index]), // Pass the callback
        );
      },
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final Function(String, String) onUpdateStatus;
  final VoidCallback onEdit; // Add this

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onUpdateStatus,
    required this.onEdit, // Add this
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.schedule;

    switch (appointment.status) {
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
        onTap: onEdit, // Call onEdit when card is tapped
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    appointment.patientName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    avatar: Icon(statusIcon, color: Colors.white, size: 16),
                    label: Text(appointment.status,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: statusColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('ID: ${appointment.patientId}'),
              Text('Doctor: ${appointment.doctor}'),
              Text('Time: ${appointment.time.format(context)}'),
              if (appointment.notes != null && appointment.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('Notes: ${appointment.notes}',
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Change Status: '),
                  _buildStatusDropdown(appointment.status, (newStatus) {
                    if (newStatus != null) {
                      onUpdateStatus(appointment.id, newStatus);
                    }
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppointmentDetailDialog extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailDialog({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Appointment Details - ${appointment.patientName}'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('Patient ID: ${appointment.patientId}'),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(appointment.date)}'),
            Text('Time: ${appointment.time.format(context)}'),
            Text('Doctor: ${appointment.doctor}'),
            Text('Status: ${appointment.status}'),
            if (appointment.notes != null && appointment.notes!.isNotEmpty)
              Text('Notes: ${appointment.notes}'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
