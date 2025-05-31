import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/registration/patient_registration_screen.dart';
import 'package:flutter_application_1/screens/settings/system_settings_screen.dart'; // Import SystemSettingsScreen
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import '../services/queue_service.dart'; // Added import
import '../models/active_patient_queue_item.dart'; // Added import
import 'user_management_screen.dart';
import 'registration/registration_hub_screen.dart';
import 'search/search_hub_screen.dart';
import 'laboratory/laboratory_hub_screen.dart';
import 'patient_queue/patient_queue_hub_screen.dart';
import 'analytics/patient_analytics_screen.dart';
import 'reports/report_hub_screen.dart'; // Import the ReportHubScreen
import 'billing/billing_hub_screen.dart';
import 'payment/payment_hub_screen.dart';
import 'maintenance/maintenance_hub_screen.dart';
import 'help/help_screen.dart';
import 'about_screen.dart'; // Assuming an AboutScreen exists or will be created
import 'logs/user_activity_log_screen.dart'; // Corrected import path
import 'lan_client_connection_screen.dart'; // Import LAN client connection screen
import 'patient_queue/view_queue_screen.dart'; // For TableCellWidget

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
  late QueueService _queueService; // Added QueueService instance

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

  late List<String> _menuTitles; // Made non-final
  late List<Widget> _screens; // Made non-final
  late List<IconData> _menuIcons; // Made non-final

  // Define all possible menu items with their screens and icons
  final Map<String, Map<String, dynamic>> _allMenuItems = {
    'Live Queue': {
      'screen': LiveQueueDashboardView(
          queueService: QueueService()), // Pass initialized service
      'icon': Icons.people_outline // Example Icon
    },
    'Registration': {
      'screen': RegistrationHubScreen(),
      'icon': Icons.app_registration
    },
    'Maintenance': {
      'screen': MaintenanceHubScreen(),
      'icon': Icons.build_circle_outlined
    },
    'Search': {'screen': SearchHubScreen(), 'icon': Icons.search_outlined},
    'Patient Laboratory Histories': {
      'screen': LaboratoryHubScreen(),
      'icon': Icons.science_outlined
    },
    'Patient Queue': {
      'screen': PatientQueueHubScreen(),
      'icon': Icons.groups_outlined
    },
    'Appointment Schedule': {
      'screen': const Text("Placeholder"),
      'icon': Icons.calendar_month_outlined
    },
    'Patient Analytics': {
      'screen': PatientAnalyticsScreen(),
      'icon': Icons.analytics_outlined
    },
    'Report': {
      'screen': ReportHubScreen(),
      'icon': Icons.receipt_long_outlined
    },
    'Payment': {'screen': PaymentHubScreen(), 'icon': Icons.payment_outlined},
    'Billing': {
      'screen': BillingHubScreen(),
      'icon': Icons.request_quote_outlined
    },
    'Help': {'screen': HelpScreen(), 'icon': Icons.help_outline},
    'About': {'screen': const AboutScreen(), 'icon': Icons.info_outline},
  };

  // Define which menu items each role can access
  final Map<String, List<String>> _rolePermissions = {
    'admin': [
      'Live Queue',
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
      'About'
    ],
    'medtech': [
      'Live Queue',
      'Registration',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Appointment Schedule',
      'Patient Analytics',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'doctor': [
      'Live Queue',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Appointment Schedule',
      'Patient Analytics',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    // Default to a restricted view or handle as an error if role is unexpected
    'patient': ['Appointment Schedule', 'Help', 'About']
  };

  @override
  void initState() {
    super.initState();
    _queueService = QueueService(); // Initialize QueueService
    _configureMenuForRole();
    _loadInitialData(); // For appointment module
  }

  void _configureMenuForRole() {
    List<String> allowedMenuKeys = _rolePermissions[widget.accessLevel] ??
        _rolePermissions['patient']!; // Default to patient or a minimal set

    List<String> tempTitles = [];
    List<Widget> tempScreens = [];
    List<IconData> tempIcons = [];

    // Ensure 'Live Queue' is first for medtech and doctor if they have access
    if ((widget.accessLevel == 'medtech' || widget.accessLevel == 'doctor') &&
        _allMenuItems.containsKey('Live Queue') &&
        allowedMenuKeys.contains('Live Queue')) {
      tempTitles.add('Live Queue');
      tempScreens.add(_allMenuItems['Live Queue']!['screen'] as Widget);
      tempIcons.add(_allMenuItems['Live Queue']!['icon'] as IconData);
    }

    for (String key in _allMenuItems.keys) {
      if (key == 'Live Queue' &&
          (widget.accessLevel == 'medtech' || widget.accessLevel == 'doctor')) {
        continue; // Already added or will be handled
      }
      if (allowedMenuKeys.contains(key)) {
        tempTitles.add(key);
        Widget screenToShow = _allMenuItems[key]!['screen'] as Widget;

        if (key == 'Appointment Schedule') {
          screenToShow = _buildAppointmentModule();
        } else if (key == 'Registration') {
          if (widget.accessLevel == 'admin') {
            screenToShow = UserManagementScreen(); // Admin sees User Management
          } else if (widget.accessLevel == 'medtech') {
            // Medtech sees Patient Registration. If RegistrationHubScreen is desired for Medtechs
            // to choose patient/service, then keep _allMenuItems[key]!['screen']
            // For now, direct to PatientRegistrationScreen for Medtech
            screenToShow = PatientRegistrationScreen();
          } else {
            // For other roles (e.g. doctor), Registration might not be shown or lead to a default/error view
            // Currently, doctors don't have 'Registration' in _rolePermissions
            // If they did, this else would be relevant.
            // Defaulting to the original hub if role is not admin/medtech but has Registration permission.
            screenToShow = _allMenuItems[key]!['screen'] as Widget;
          }
        }
        tempScreens.add(screenToShow);
        tempIcons.add(_allMenuItems[key]!['icon'] as IconData);
      }
    }

    setState(() {
      _menuTitles = tempTitles;
      _screens = tempScreens;
      _menuIcons = tempIcons;

      // Ensure _selectedIndex is valid for the filtered list
      if (_selectedIndex >= _menuTitles.length) {
        _selectedIndex = 0;
      }
    });
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
          patientId: 'PT-1001',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 9, minute: 0),
          doctorId: 'dr_smith_id',
          status: 'Confirmed',
          notes: 'Regular checkup',
        ),
        Appointment(
          id: '2',
          patientId: 'PT-1002',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 11, minute: 30),
          doctorId: 'dr_johnson_id',
          status: 'Pending',
          notes: 'New patient consultation',
        ),
        Appointment(
          id: '3',
          patientId: 'PT-1003',
          date: DateTime.now().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 14, minute: 0),
          doctorId: 'dr_smith_id',
          status: 'Confirmed',
          notes: 'Follow-up appointment',
        ),
        Appointment(
          id: '4',
          patientId: 'PT-1004',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 15, minute: 30),
          doctorId: 'dr_wilson_id',
          status: 'Cancelled',
          notes: 'Annual physical examination',
        ),
        Appointment(
          id: '5',
          patientId: 'PT-1005',
          date: DateTime.now().add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 10, minute: 0),
          doctorId: 'dr_johnson_id',
          status: 'Pending',
          notes: 'Follow-up on lab results',
        ),
      ];

      // Try to get appointments from API (can fail silently for now)
      if (_menuTitles.contains('Appointment Schedule')) {
        // Only load if module is accessible
        try {
          final apiAppointments =
              await ApiService.getAppointments(_selectedDate);
          if (apiAppointments.isNotEmpty) {
            _appointments = apiAppointments;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error loading appointments: ${e.toString()}')),
            );
          }
          print('Error loading appointments: $e');
        }
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
          patientId: _patientIdController.text,
          date: _selectedDate,
          time: _selectedTime,
          doctorId: _doctorController.text,
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
    if (_menuTitles.isEmpty && widget.accessLevel != 'patient') {
      // Handle case where role might not have menus (e.g. during init)
      // This might happen if _configureMenuForRole hasn't completed or an unknown role is passed.
      // Provide a loading state or a restricted view.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_menuTitles.isEmpty && widget.accessLevel == 'patient') {
      return Scaffold(
        appBar: AppBar(title: const Text("Patient Dashboard")),
        body: const Center(
            child: Text(
                "Welcome Patient! Limited view.")), // Or specific patient view
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - ${widget.accessLevel}'),
        backgroundColor: Colors.teal[700],
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings & Actions',
            onSelected: (String result) {
              switch (result) {
                case 'activity_log':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UserActivityLogScreen()),
                  );
                  break;
                case 'lan_connection':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const LanClientConnectionScreen()),
                  );
                  break;
                case 'system_settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SystemSettingsScreen()),
                  );
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuEntry<String>> items = [];
              items.add(
                const PopupMenuItem<String>(
                  value: 'activity_log',
                  child: ListTile(
                      leading: Icon(Icons.history),
                      title: Text('Activity Log')),
                ),
              );
              items.add(
                const PopupMenuItem<String>(
                  value: 'lan_connection',
                  child: ListTile(
                      leading: Icon(Icons.wifi), title: Text('LAN Connection')),
                ),
              );

              // System Settings for all roles
              items.add(
                const PopupMenuItem<String>(
                  value: 'system_settings',
                  child: ListTile(
                      leading: Icon(Icons.settings_applications),
                      title: Text('System Settings')),
                ),
              );

              items.add(const PopupMenuDivider());
              items.add(
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout), title: Text('Logout')),
                ),
              );
              return items;
            },
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
            destinations: List.generate(_menuTitles.length, (index) {
              return NavigationRailDestination(
                icon: Icon(_menuIcons[index]),
                selectedIcon: Icon(_menuIcons[index],
                    color: Theme.of(context).primaryColor),
                label: SizedBox
                    .shrink(), // Further simplified: remove Text label entirely for now
              );
            }),
            minExtendedWidth: 180,
            minWidth: 100,
            extended: false,
            groupAlignment: -0.85,
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
        'Patient ID: ${appointment.patientId}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Doctor ID: ${appointment.doctorId}'),
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
                    'Patient ID: ${appointment.patientId}',
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
              Text('Doctor ID: ${appointment.doctorId}'),
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
      title: Text('Appointment Details - PID: ${appointment.patientId}'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('Patient ID: ${appointment.patientId}'),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(appointment.date)}'),
            Text('Time: ${appointment.time.format(context)}'),
            Text('Doctor ID: ${appointment.doctorId}'),
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

// Define LiveQueueDashboardView widget here
class LiveQueueDashboardView extends StatefulWidget {
  final QueueService queueService;

  const LiveQueueDashboardView({super.key, required this.queueService});

  @override
  _LiveQueueDashboardViewState createState() => _LiveQueueDashboardViewState();
}

class _LiveQueueDashboardViewState extends State<LiveQueueDashboardView> {
  late Future<List<ActivePatientQueueItem>> _queueFuture;
  final TextStyle cellStyle =
      const TextStyle(fontSize: 14, color: Colors.black87);

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  void _loadQueue() {
    setState(() {
      _queueFuture = widget.queueService.getActiveQueueItems(
          statuses: ['waiting', 'in_consultation']); // Focus on active patients
    });
  }

  void _refreshQueue() {
    _loadQueue();
  }

  Future<void> _nextPatient() async {
    try {
      final queue = await _queueFuture;
      final waitingPatients =
          queue.where((p) => p.status == 'waiting').toList();

      if (waitingPatients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No patients currently waiting.'),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      waitingPatients.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
      final nextPatient = waitingPatients.first;

      bool success = await widget.queueService
          .markPatientAsInConsultation(nextPatient.queueEntryId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${nextPatient.patientName} is now In Consultation.'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshQueue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to move ${nextPatient.patientName} to In Consultation.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error processing next patient: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  static String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return 'Waiting';
      case 'in_consultation':
        return 'In Consultation';
      case 'served':
        return 'Served';
      case 'removed':
        return 'Removed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange.shade700;
      case 'in_consultation':
        return Colors.blue.shade700;
      case 'served':
        return Colors.green.shade700;
      case 'removed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      // Changed to Row for side-by-side layout
      children: [
        // Live Queue Section (Left Half)
        Expanded(
          flex: 1, // Takes half of the screen
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Patient Queue',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700]), // Changed color to teal
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshQueue,
                      tooltip: 'Refresh Queue',
                      color: Colors.teal[700], // Changed color to teal
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTableHeader(),
                Expanded(
                  child: FutureBuilder<List<ActivePatientQueueItem>>(
                    future: _queueFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child:
                                Text('Error loading queue: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No patients waiting or in consultation.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final queue = snapshot.data!;
                      return ListView.builder(
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          return _buildTableRow(item);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16), // Space before the button
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.next_plan_outlined),
                    label: const Text('Next Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600], // Keep teal color
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _nextPatient,
                  ),
                ),
                const SizedBox(height: 16), // Space after the button
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1), // Separator
        // Analytics Section (Right Half)
        Expanded(
          flex: 1, // Takes the other half of the screen
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  'Monthly Analytics Report',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[700]), // Changed color to teal
                ),
                const SizedBox(height: 10),
                Text(
                  'Detailed analytics will be available in a future version.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600]),
                ),
                // You can add more placeholder UI for analytics here if needed
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    final headers = ['No.', 'Name', 'Arrival', 'Condition', 'Status'];
    return Container(
      color: Colors.teal[600], // Changed color to teal
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: headers.map((text) {
          return Expanded(
              flex: (text == 'Name' || text == 'Condition') ? 2 : 1,
              child: TableCellWidget(
                text: text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ));
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(ActivePatientQueueItem item) {
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';

    final dataCells = [
      item.queueNumber.toString(),
      item.patientName,
      arrivalDisplayTime,
      item.conditionOrPurpose ?? 'N/A',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex = (idx == 1 || idx == 3) ? 2 : 1;

            if (idx == 0) {
              return Expanded(
                  flex: 1,
                  child: Center(
                      child: Text(text,
                          style: cellStyle.copyWith(
                              fontWeight: FontWeight.bold))));
            }
            return Expanded(
                flex: flex,
                child: TableCellWidget(
                  text: text,
                  style: cellStyle,
                ));
          }).toList(),
          Expanded(
            flex: 1,
            child: TableCellWidget(
                child: Text(
              _getDisplayStatus(item.status),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(item.status),
                  fontSize: cellStyle.fontSize),
              textAlign: TextAlign.center,
            )),
          ),
        ],
      ),
    );
  }
}
