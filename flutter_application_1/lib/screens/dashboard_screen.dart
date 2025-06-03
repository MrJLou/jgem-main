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
import 'appointments/appointment_overview_screen.dart'; // Import the new AppointmentOverviewScreen
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

// Imports for new settings screens
import 'settings/user_profile_screen.dart';
import 'settings/appearance_settings_screen.dart';
import 'package:table_calendar/table_calendar.dart'; // Added for TableCalendar

class DashboardScreen extends StatefulWidget {
  final String accessLevel;
  const DashboardScreen({super.key, required this.accessLevel});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isHovered = false;
  Map<int, bool> _hoveredItems = {};

  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = [];
  bool _isAddingAppointment = false;
  bool _isLoading = false;
  final _appointmentFormKey = GlobalKey<FormState>();
  late QueueService _queueService;

  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  late List<String> _menuTitles;
  late List<Widget> _screens;
  late List<IconData> _menuIcons;

  final Map<String, Map<String, dynamic>> _allMenuItems = {
    'Dashboard': {
      'screen': (String accessLevel) => LiveQueueDashboardView(
          queueService: QueueService(), appointments: []),
      'icon': Icons.dashboard_outlined
    },
    'Registration': {
      'screen': (String accessLevel) => const RegistrationHubScreen(),
      'icon': Icons.app_registration
    },
    'User Management': {
      'screen': (String accessLevel) => const UserManagementScreen(),
      'icon': Icons.manage_accounts
    },
    'Maintenance': {
      'screen': (String accessLevel) => const MaintenanceHubScreen(),
      'icon': Icons.build_circle_outlined
    },
    'Search': {
      'screen': (String accessLevel) =>
          SearchHubScreen(accessLevel: accessLevel),
      'icon': Icons.search_outlined
    },
    'Patient Laboratory Histories': {
      'screen': (String accessLevel) => const LaboratoryHubScreen(),
      'icon': Icons.science_outlined
    },
    'Patient Queue': {
      'screen': (String accessLevel) =>
          PatientQueueHubScreen(accessLevel: accessLevel),
      'icon': Icons.groups_outlined
    },
    'Appointment Schedule': {
      'screen': (String accessLevel) => const AppointmentOverviewScreen(),
      'icon': Icons.calendar_month_outlined
    },
    'Patient Analytics': {
      'screen': (String accessLevel) => PatientAnalyticsScreen(),
      'icon': Icons.analytics_outlined
    },
    'Report': {
      'screen': (String accessLevel) => const ReportHubScreen(),
      'icon': Icons.receipt_long_outlined
    },
    'Payment': {
      'screen': (String accessLevel) => const PaymentHubScreen(),
      'icon': Icons.payment_outlined
    },
    'Billing': {
      'screen': (String accessLevel) => const BillingHubScreen(),
      'icon': Icons.request_quote_outlined
    },
    'Help': {
      'screen': (String accessLevel) => HelpScreen(),
      'icon': Icons.help_outline
    },
    'About': {
      'screen': (String accessLevel) => const AboutScreen(),
      'icon': Icons.info_outline
    },
  };

  final Map<String, List<String>> _rolePermissions = {
    'admin': [
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
      'Dashboard',
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
      'Dashboard',
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
    'patient': ['Appointment Schedule', 'Help', 'About']
  };

  @override
  void initState() {
    print('DEBUG: DashboardScreen initState START');
    super.initState();
    _queueService = QueueService();
    print('DEBUG: DashboardScreen initState calling _configureMenuForRole');
    _configureMenuForRole();
    print('DEBUG: DashboardScreen initState calling _loadInitialData');
    _loadInitialData();
    print('DEBUG: DashboardScreen initState END');
  }

  void _configureMenuForRole() {
    print('DEBUG: Received accessLevel in _configureMenuForRole: ${widget.accessLevel}');
    List<String> allowedMenuKeys =
        _rolePermissions[widget.accessLevel] ?? _rolePermissions['patient']!;
    print('DEBUG: allowedMenuKeys for ${widget.accessLevel}: $allowedMenuKeys');

    List<String> tempTitles = [];
    List<Widget> tempScreens = [];
    List<IconData> tempIcons = [];

    String dashboardKey = 'Dashboard';
    if (_allMenuItems.containsKey(dashboardKey) &&
        allowedMenuKeys.contains(dashboardKey)) {
      bool prioritize =
          (widget.accessLevel == 'medtech' || widget.accessLevel == 'doctor');
      if (!prioritize) {
        if (allowedMenuKeys.isNotEmpty &&
            allowedMenuKeys.first == dashboardKey) {
          prioritize = true;
        }
      }

      if (prioritize && !tempTitles.contains(dashboardKey)) {
        tempTitles.add(dashboardKey);
        tempScreens.add(LiveQueueDashboardView(
            queueService: _queueService, appointments: _appointments));
        tempIcons.add(_allMenuItems[dashboardKey]!['icon'] as IconData);
      }
    }

    for (String key in _allMenuItems.keys) {
      if (tempTitles.contains(key)) {
        continue;
      }

      if (allowedMenuKeys.contains(key)) {
        tempTitles.add(key);
        Widget screenToShow;
        Function? screenBuilder = _allMenuItems[key]!['screen'] as Function?;

        if (key == dashboardKey) {
          if (!tempTitles.contains(dashboardKey)) {
            screenToShow = LiveQueueDashboardView(
                queueService: _queueService, appointments: _appointments);
          } else {
            int existingIndex = tempTitles.indexOf(dashboardKey);
            if (existingIndex != -1) {
              screenToShow = tempScreens[existingIndex];
            } else {
              screenToShow = LiveQueueDashboardView(
                  queueService: _queueService, appointments: _appointments);
            }
          }
        } else if (key == 'Appointment Schedule') {
          screenToShow = const AppointmentOverviewScreen();
        } else if (key == 'Registration') {
          if (widget.accessLevel == 'medtech') {
            screenToShow = PatientRegistrationScreen();
          } else {
            if (screenBuilder != null) {
              screenToShow = screenBuilder(widget.accessLevel);
            } else {
              screenToShow =
                  const Center(child: Text("Error: Screen not configured"));
            }
          }
        } else if (key == 'Patient Laboratory Histories') {
          screenToShow = const LaboratoryHubScreen();
        } else {
          if (screenBuilder != null) {
            screenToShow = screenBuilder(widget.accessLevel);
          } else {
            screenToShow =
                const Center(child: Text("Error: Screen not configured"));
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

      if (_selectedIndex >= _menuTitles.length) {
        _selectedIndex = 0;
      }
    });
  }

  String _generatePatientId() {
    return 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final apiAppointments = await ApiService.getAppointments(_selectedDate);
      if (mounted) {
        setState(() => _appointments = apiAppointments ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to load appointments: $e (local data shown)')),
        );
        if (_appointments == null) {
          setState(() => _appointments = []);
        }
      }
      print('Failed to load appointments from API, using local/mock: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadInitialData() async {
    print('DEBUG: DashboardScreen _loadInitialData START');
    if (!mounted) {
      print('DEBUG: DashboardScreen _loadInitialData NOT MOUNTED, returning');
      return;
    }
    setState(() => _isLoading = true);
    _appointments = [
      Appointment(
          id: '1',
          patientId: 'PT-1001',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 9, minute: 0),
          doctorId: 'dr_smith_id',
          status: 'Confirmed',
          notes: 'Regular checkup'),
      Appointment(
          id: '2',
          patientId: 'PT-1002',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 11, minute: 30),
          doctorId: 'dr_johnson_id',
          status: 'Pending',
          notes: 'New patient consultation'),
    ];
    await _loadAppointments();
    print('DEBUG: DashboardScreen _loadInitialData after _loadAppointments');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    print('DEBUG: DashboardScreen _loadInitialData END');
  }

  Future<void> _saveAppointment() async {
    if (_appointmentFormKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        String newId;
        if (_patientIdController.text.isEmpty) {
          _patientIdController.text = _generatePatientId();
        }
        newId = _patientIdController.text +
            DateTime.now().millisecondsSinceEpoch.toString();

        final newAppointment = Appointment(
          id: newId,
          patientId: _patientIdController.text,
          date: _selectedDate,
          time: _selectedTime,
          doctorId: _doctorController.text,
          status: 'Confirmed',
          notes: _notesController.text,
        );

        await ApiService.saveAppointment(newAppointment);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Appointment saved successfully'),
                backgroundColor: Colors.green),
          );
        }
        await _loadAppointments();
        if (mounted) {
          setState(() => _isAddingAppointment = false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save appointment: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _updateAppointmentStatus(String id, String newStatus) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.updateAppointmentStatus(id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Status updated successfully'),
              backgroundColor: Colors.green),
        );
      }
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Widget _buildNavigationItem(int index) {
    bool isSelected = index == _selectedIndex;
    bool isItemHovered = _hoveredItems[index] ?? false;
    bool shouldShowLabel = _isHovered || isSelected || isItemHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItems[index] = true),
      onExit: (_) => setState(() => _hoveredItems[index] = false),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedIndex = index;
                if (_menuTitles[index] !=
                    'Appointment Schedule H Hypothetical') {}
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.teal.withOpacity(0.15)
                    : isItemHovered
                        ? Colors.teal.withOpacity(0.08)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _menuIcons[index],
                    color: isSelected || isItemHovered
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
                    size: 24,
                  ),
                  if (shouldShowLabel)
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: shouldShowLabel ? 1.0 : 0.0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            _menuTitles[index],
                            style: TextStyle(
                              color: isSelected || isItemHovered
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_menuTitles.isEmpty && widget.accessLevel != 'patient') {
      return Scaffold(
          appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/slide1.png',
                        height: 28,
                        width: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.medical_services_outlined,
                                color: Colors.teal, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'J-Gem Medical and Diagnostic Clinic',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.teal[700]),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_menuTitles.isEmpty && widget.accessLevel == 'patient') {
      return Scaffold(
        appBar: AppBar(
            title: const Text("Patient Dashboard"),
            backgroundColor: Colors.teal[700]),
        body: const Center(child: Text("Welcome Patient! Limited view.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/slide1.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.medical_services_outlined,
                      color: Colors.teal,
                      size: 28),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'J-Gem Medical and Diagnostic Clinic',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal[700],
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings & Actions',
            onSelected: (String result) {
              switch (result) {
                case 'user_profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                  );
                  break;
                case 'appearance_settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AppearanceSettingsScreen()),
                  );
                  break;
                case 'system_settings':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SystemSettingsScreen()));
                  break;
                case 'activity_log':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserActivityLogScreen()));
                  break;
                case 'lan_connection':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const LanClientConnectionScreen()));
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuEntry<String>> items = [];
              // User & App Personalization Group
              items.add(
                const PopupMenuItem<String>(
                  value: 'user_profile',
                  child: ListTile(
                      leading: Icon(Icons.account_circle_outlined),
                      title: Text('User Profile')),
                ),
              );
              items.add(
                const PopupMenuItem<String>(
                  value: 'appearance_settings',
                  child: ListTile(
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Appearance')),
                ),
              );
              items.add(const PopupMenuDivider()); // Divider 1

              // System & Technical Settings Group
              items.add(
                const PopupMenuItem<String>(
                  value: 'system_settings',
                  child: ListTile(
                      leading: Icon(Icons.settings_applications),
                      title: Text('System Settings')),
                ),
              );
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
              items.add(const PopupMenuDivider()); // Divider 2

              // Session Management Group
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _isHovered ? 200 : 72,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 2)
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: () {
                    List<Widget> navWidgets = [];
                    for (int i = 0; i < _menuTitles.length; i++) {
                      if (_menuTitles[i] == 'Report') {
                        navWidgets.add(const Divider(
                          height: 32.0,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.black26,
                        ));
                      }
                      navWidgets.add(_buildNavigationItem(i));
                    }
                    return navWidgets;
                  }(),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: (_selectedIndex < _screens.length)
                  ? _screens[_selectedIndex]
                  : const Center(child: Text("Screen not available")),
            ),
          ),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
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
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.patientNameController,
                  decoration: const InputDecoration(
                      labelText: 'Patient Name', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter patient name';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.doctorController,
                  decoration: const InputDecoration(
                      labelText: 'Doctor', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter doctor name';
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
                      labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: widget.onCancel, child: const Text('CANCEL')),
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
    itemBuilder: (context, index) => _buildAppointmentCard(
        appointments[index], onUpdateStatus, context),
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
    case 'Completed':
      statusColor = Colors.blue;
      statusIcon = Icons.done_all_outlined;
      break;
  }

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
          if (appointment.notes != null && appointment.notes!.isNotEmpty)
            Text('Notes: ${appointment.notes}'),
        ],
      ),
      trailing: _buildStatusDropdown(appointment.status, (newStatus) {
        if (newStatus != null) onUpdateStatus(appointment.id, newStatus);
      }),
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

Widget _buildStatusDropdown(String currentStatus, Function(String?) onChanged) {
  List<String> statuses = ['Pending', 'Confirmed', 'Cancelled', 'Completed'];
  if (!statuses.contains(currentStatus)) statuses.add(currentStatus);
  return DropdownButton<String>(
    value: currentStatus,
    items: statuses.map((String value) {
      return DropdownMenuItem<String>(value: value, child: Text(value));
    }).toList(),
    onChanged: onChanged,
    underline: Container(),
    style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.normal),
    iconEnabledColor: Colors.teal[700],
  );
}

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
        return AppointmentCard(
          appointment: appointments[index],
          onUpdateStatus: onUpdateStatus,
          onEdit: () => onEditAppointment(appointments[index]),
        );
      },
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final Function(String, String) onUpdateStatus;
  final VoidCallback onEdit;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onUpdateStatus,
    required this.onEdit,
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
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Patient ID: ${appointment.patientId}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
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
                    if (newStatus != null)
                      onUpdateStatus(appointment.id, newStatus);
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
            onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class LiveQueueDashboardView extends StatefulWidget {
  final QueueService queueService;
  final List<Appointment> appointments;

  const LiveQueueDashboardView(
      {super.key, required this.queueService, required this.appointments});

  @override
  _LiveQueueDashboardViewState createState() => _LiveQueueDashboardViewState();
}

class _LiveQueueDashboardViewState extends State<LiveQueueDashboardView> {
  late Future<List<ActivePatientQueueItem>> _activeQueueFuture;
  final TextStyle cellStyle =
      const TextStyle(fontSize: 14, color: Colors.black87);
  DateTime _calendarSelectedDate = DateTime.now();
  DateTime _calendarFocusedDay = DateTime.now();
  List<Appointment> _allAppointmentsForCalendar = [];
  List<Appointment> _dailyAppointmentsForDisplay = [];
  
  List<dynamic> _combinedQueueForDisplayList = [];
  bool _isLoadingQueueAndAppointments = true;

  @override
  void initState() {
    print('DEBUG: LiveQueueDashboardView initState START');
    super.initState();
    print('DEBUG: LiveQueueDashboardView initState calling _loadCombinedQueueData');
    _loadCombinedQueueData();
    print('DEBUG: LiveQueueDashboardView initState END');
  }

  Future<void> _loadCombinedQueueData() async {
    print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData START');
    if (!mounted) {
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData NOT MOUNTED, returning');
      return;
    }
    setState(() {
      _isLoadingQueueAndAppointments = true;
    });

    try {
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData fetching activeQueueItems...');
      final activeQueueItems = await widget.queueService.getActiveQueueItems(statuses: ['waiting', 'in_consultation']);
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData fetched activeQueueItems. Count: ${activeQueueItems.length}');
      
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData fetching allAppointments...');
      final allAppointments = await ApiService.getAllAppointments();
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData fetched allAppointments. Count: ${allAppointments.length}');
      
      if (mounted) {
        _allAppointmentsForCalendar = allAppointments;
        _filterDailyAppointments();

        List<dynamic> combinedList = [];
        DateTime today = DateTime.now();

        // Get patient IDs of those already in the active queue system to avoid duplication
        final Set<String> patientIdsInActiveSystem = activeQueueItems
            .map((item) => item.patientId)
            .where((id) => id != null) // Ensure we only consider non-null patient IDs
            .cast<String>() // Cast to Set<String> after filtering nulls
            .toSet();

        // Filter for today's appointments that are not yet in the active system and are in a schedulable status
        List<Appointment> todayScheduledAppointmentsToAdd = _allAppointmentsForCalendar
            .where((appt) =>
                isSameDay(appt.date, today) &&
                (appt.status.toLowerCase() == 'confirmed' || appt.status.toLowerCase() == 'pending') && // Eligible if confirmed or pending
                !patientIdsInActiveSystem.contains(appt.patientId) // And not already processed into active queue
            )
            .toList();

        todayScheduledAppointmentsToAdd.sort((a, b) {
            final aTime = a.time.hour * 60 + a.time.minute;
            final bTime = b.time.hour * 60 + b.time.minute;
            return aTime.compareTo(bTime);
        });

        for (var appt in todayScheduledAppointmentsToAdd) {
          combinedList.add(ActivePatientQueueItem(
            queueEntryId: 'appt_${appt.id}', // Prefix to identify as originally scheduled
            patientId: appt.patientId,
            patientName: 'PT: ${appt.patientId}', // Placeholder, consider fetching full name
            arrivalTime: DateTime(appt.date.year, appt.date.month, appt.date.day, appt.time.hour, appt.time.minute),
            queueNumber: 0, // Not a typical queue number; time is more relevant
            status: 'Scheduled', // Pseudo-status for display
            // Assuming Appointment model might have consultationType and paymentStatus, otherwise defaults are used.
            conditionOrPurpose: appt.consultationType ?? appt.notes ?? 'Appointment',
            paymentStatus: 'Pending', // Default for purely scheduled items not yet in active queue payment system
            createdAt: appt.createdAt ?? DateTime.now(), // Use appointment creation time if available
          ));
        }

        combinedList.addAll(activeQueueItems); // Add walk-ins and activated appointments

        // Sort the combined list: In Consultation > Waiting > Scheduled (by time)
        combinedList.sort((a, b) {
          int statusValue(String status) {
            if (status.toLowerCase() == 'in_consultation') return 0;
            if (status.toLowerCase() == 'waiting') return 1;
            if (status.toLowerCase() == 'scheduled') return 2;
            return 3; // Other statuses last
          }
          int compare = statusValue(a.status).compareTo(statusValue(b.status));
          if (compare == 0) { // If status is the same, sort by arrival/scheduled time
            return a.arrivalTime.compareTo(b.arrivalTime);
          }
          return compare;
        });

        setState(() {
          _combinedQueueForDisplayList = combinedList;
          // _activeQueueFuture probably still refers to items managed by QueueService for 'next' logic
          _activeQueueFuture = Future.value(activeQueueItems); 
        });
      }
    } catch (e) {
      if (mounted) {
        print("Failed to load combined queue data: $e");
        print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData ERROR: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQueueAndAppointments = false;
        });
      }
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData END');
    }
  }

  void _filterDailyAppointments() {
    if (!mounted) return;
    setState(() {
      _dailyAppointmentsForDisplay = _allAppointmentsForCalendar
          .where((appt) => isSameDay(appt.date, _calendarSelectedDate))
          .toList();
      _dailyAppointmentsForDisplay.sort((a, b) {
        final aTime = a.time.hour * 60 + a.time.minute;
        final bTime = b.time.hour * 60 + b.time.minute;
        return aTime.compareTo(bTime);
      });
    });
  }

  void _refreshAllData() {
    _loadCombinedQueueData();
  }

  void _refreshActiveQueueForNextPatient() async {
    final activeQueueItems = await widget.queueService.getActiveQueueItems(statuses: ['waiting', 'in_consultation']);
    setState(() {
      _activeQueueFuture = Future.value(activeQueueItems);
    });
     _loadCombinedQueueData();
  }

  Future<void> _activateAndCallScheduledPatient(String appointmentId) async {
    if (!mounted) return;
    setState(() { /* Potentially set a loading state for this specific item */ });

    try {
      final originalAppointment = _allAppointmentsForCalendar.firstWhere(
        (appt) => appt.id == appointmentId,
      );

      // Find the corresponding display item to check its current paymentStatus if needed
      // This representation is what's shown in the queue with the default 'Pending' or an updated status.
      final displayItemInQueue = _combinedQueueForDisplayList.firstWhere(
          (item) => item is ActivePatientQueueItem && item.queueEntryId == 'appt_${originalAppointment.id}',
          orElse: () => null, // Should ideally exist if button is pressed
      ) as ActivePatientQueueItem?;

      if (displayItemInQueue != null && displayItemInQueue.paymentStatus != 'Paid' && displayItemInQueue.paymentStatus != 'Waived') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment is ${displayItemInQueue.paymentStatus} for ${originalAppointment.patientId}. Activating anyway.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        // Depending on policy, you might prevent activation here:
        // if (strictPolicy) { setState(() {}); return; }
      }

      final newQueueItem = ActivePatientQueueItem(
        queueEntryId: 'active_${DateTime.now().millisecondsSinceEpoch}',
        patientId: originalAppointment.patientId,
        patientName: 'PT: ${originalAppointment.patientId}', 
        arrivalTime: DateTime.now(),
        queueNumber: 0, 
        status: 'in_consultation',
        paymentStatus: displayItemInQueue?.paymentStatus ?? 'Pending', // Carry over displayed payment status
        conditionOrPurpose: originalAppointment.consultationType ?? originalAppointment.notes ?? 'Scheduled Consultation',
        createdAt: DateTime.now(),
      );

      bool addedToActiveQueue = await widget.queueService.addPatientToQueue(newQueueItem); 

      if (addedToActiveQueue) {
        await ApiService.updateAppointmentStatus(appointmentId, 'In Consultation');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newQueueItem.patientName} is now In Consultation.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadCombinedQueueData(); // Refresh the list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to activate scheduled appointment.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        print("Error activating scheduled patient: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { /* Clear loading state for the item if set */ });
      }
    }
  }

  Future<void> _callNextScheduled() async {
    if (!mounted) return;

    final scheduledPatients = _combinedQueueForDisplayList
        .where((item) => item is ActivePatientQueueItem && item.status == 'Scheduled')
        .cast<ActivePatientQueueItem>()
        .toList();

    if (scheduledPatients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No appointments currently scheduled for today or all have been processed.'),
            backgroundColor: Colors.amber));
      }
      return;
    }
    // Sort by appointment time (which is stored in arrivalTime for these pseudo-items)
    scheduledPatients.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
    final nextScheduled = scheduledPatients.first;

    // The queueEntryId for these is 'appt_ORIGINAL_ID'
    if (nextScheduled.queueEntryId.startsWith('appt_')) {
      String originalAppointmentId = nextScheduled.queueEntryId.substring(5); // Remove 'appt_'
      await _activateAndCallScheduledPatient(originalAppointmentId);
    } else {
      // This case should ideally not happen if data is consistent
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error: Selected scheduled item has an invalid ID format.'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _nextPatient() async {
    if (!mounted) return;
    try {
      final queue = await widget.queueService.getActiveQueueItems(statuses: ['waiting']);
      
      if (queue.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No walk-in patients currently waiting.'),
            backgroundColor: Colors.amber));
        return;
      }

      queue.sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
      
      final nextPatientToCall = queue.first;

      bool success = await widget.queueService
          .markPatientAsInConsultation(nextPatientToCall.queueEntryId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${nextPatientToCall.patientName} is now In Consultation.'
              : 'Failed to move ${nextPatientToCall.patientName}.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        _refreshAllData(); 
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error processing next walk-in patient: $e'),
          backgroundColor: Colors.red));
    }
  }

  static String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting': return 'Waiting';
      case 'in_consultation': return 'In Consultation';
      case 'served': return 'Served';
      case 'removed': return 'Removed';
      case 'scheduled': return 'Scheduled (Today)';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting': return Colors.orange.shade700;
      case 'in_consultation': return Colors.blue.shade700;
      case 'served': return Colors.green.shade700;
      case 'removed': return Colors.red.shade700;
      case 'scheduled': return Colors.purple.shade400;
      default: return Colors.grey.shade700;
    }
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.cyan.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome',
                  style: TextStyle(
                      fontSize: 16, color: Colors.white.withOpacity(0.9)),
                ),
                const Text(
                  'Valued User',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'To keep the body in good health is a duty... otherwise we shall not be able to keep our mind strong and clear.',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4),
                ),
              ],
            ),
          ),
          Opacity(
            opacity: 0.2,
            child: Icon(Icons.medical_services_outlined,
                size: 100, color: Colors.white.withOpacity(0.5)),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryMetricsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildMetricCard('Appointments', '105', Icons.calendar_today, Colors.blue)),
          const SizedBox(width: 16),
          Expanded(child: _buildMetricCard('Urgent Resolve', '40', Icons.warning_amber_rounded, Colors.red)),
          const SizedBox(width: 16),
          Expanded(child: _buildMetricCard('Available Doctors', '37', Icons.person_search, Colors.green)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text('TODAY',
                style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysDoctorsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Doctors",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700]),
          ),
          const SizedBox(height: 10),
          Container(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDoctorCard('Dr. James Wilson', 'Orthopedic',
                    'assets/images/doctor_male1.png', '11:30 am to 3:30 pm'),
                _buildDoctorCard('Dr. Eric Rodriguez', 'Cardiology',
                    'assets/images/doctor_male2.png', '10:00 am to 2:30 pm'),
                _buildDoctorCard('Dr. Lora Wallace', 'Neurology',
                    'assets/images/doctor_female1.png', '3:00 pm to 6:00 pm'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(
      String name, String specialty, String imagePath, String availability) {
    Widget imageWidget;
    if (imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(
        imagePath,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.person, size: 30, color: Colors.grey[400])),
      );
    } else {
      imageWidget = CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, size: 30, color: Colors.grey[400]));
    }
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.teal[50],
              child: ClipOval(
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 10),
            Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(specialty,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (index) =>
                      Icon(Icons.star, color: Colors.amber[600], size: 13)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 11, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(availability,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarAppointmentsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            child: TableCalendar<Appointment>(
              firstDay: DateTime.utc(DateTime.now().year - 5, 1, 1),
              lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
              focusedDay: _calendarFocusedDay,
              selectedDayPredicate: (day) => isSameDay(_calendarSelectedDate, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 17.0, color: Colors.teal[800], fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal[700], size: 24),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal[700], size: 24),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.teal[400],
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.teal[100]?.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.pinkAccent[200],
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
                outsideDaysVisible: false,
              ),
              eventLoader: (day) {
                return _allAppointmentsForCalendar
                    .where((appointment) => isSameDay(appointment.date, day))
                    .toList();
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_calendarSelectedDate, selectedDay)) {
                  setState(() {
                    _calendarSelectedDate = selectedDay;
                    _calendarFocusedDay = focusedDay;
                    _filterDailyAppointments();
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _calendarFocusedDay = focusedDay;
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Appointments for ${DateFormat.yMMMd().format(_calendarSelectedDate)}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[700]),
              ),
              Text(
                "${_dailyAppointmentsForDisplay.length} scheduled",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _dailyAppointmentsForDisplay.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          "No appointments scheduled for this day.",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _dailyAppointmentsForDisplay.length,
                  itemBuilder: (context, index) {
                    final appointment = _dailyAppointmentsForDisplay[index];
                    return _buildImageStyledAppointmentCard(
                        appointment.patientId,
                        appointment.notes ?? appointment.consultationType ?? 'Scheduled',
                        appointment.time.format(context),
                        false);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildImageStyledAppointmentCard(
      String patientName, String details, String time, bool isHighlighted) {
    return Card(
        color: isHighlighted ? Colors.deepPurple.shade300 : Colors.white,
        elevation: isHighlighted ? 3 : 1.5,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isHighlighted
                    ? Colors.white.withOpacity(0.2)
                    : Colors.teal.withOpacity(0.1),
                child: Icon(
                  Icons.person_outline,
                  color: isHighlighted ? Colors.white : Colors.teal[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isHighlighted ? Colors.white : Colors.grey[800],
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: TextStyle(
                          color: isHighlighted
                              ? Colors.white.withOpacity(0.85)
                              : Colors.grey[600],
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                time,
                style: TextStyle(
                    color: isHighlighted
                        ? Colors.white.withOpacity(0.9)
                        : Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ));
  }

  Widget _buildYearMonthScroller() {
    final currentYear = _calendarSelectedDate.year.toString();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final currentMonthIndex = _calendarSelectedDate.month - 1;

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(currentYear,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                  fontSize: 15)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: months.length,
            itemBuilder: (context, index) {
              bool isSelectedMonth = index == currentMonthIndex;
              return InkWell(
                onTap: () {
                  setState(() {
                    _calendarSelectedDate = DateTime(
                        _calendarSelectedDate.year,
                        index + 1,
                        _calendarSelectedDate.day);
                    _calendarFocusedDay = _calendarSelectedDate; // Keep focused day in sync
                    _filterDailyAppointments(); // Update appointment list
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  color: isSelectedMonth
                      ? Colors.teal.withOpacity(0.2)
                      : Colors.transparent,
                  child: Text(
                    months[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelectedMonth
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelectedMonth
                          ? Colors.teal[800]
                          : Colors.grey[700],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeSection(),
                _buildSummaryMetricsSection(),
                _buildTodaysDoctorsSection(),
                const SizedBox(height: 16), // Added spacing before the queue
                _buildLiveQueueDisplaySection(), // Correct placement of the live queue
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
            flex: 2,
            child: Container(
                color: Colors.grey[50],
                child: SingleChildScrollView(
                  // Ensure this child is a Row for calendar and scroller side-by-side
                  child: Row( 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildCalendarAppointmentsSection(),
                      ),
                      _buildYearMonthScroller(),
                    ],
                  ),
                ))),
      ],
    );
  }

  Widget _buildTableHeader() {
    final headers = ['No.', 'Name', 'Arrival', 'Condition', 'Payment', 'Status & Actions'];
    return Container(
      color: Colors.teal[600],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: headers.map((text) {
          int flex = 1;
          if (text == 'Name' || text == 'Condition') flex = 2;
          if (text == 'Status & Actions') flex = 3;
          if (text == 'Payment') flex = 1; 

          return Expanded(
              flex: flex,
              child: TableCellWidget(
                  text: text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)));
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(ActivePatientQueueItem item) {
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';
    
    bool isRepresentingScheduledAppointment = item.queueEntryId.startsWith('appt_');
    String originalAppointmentId = isRepresentingScheduledAppointment ? item.queueEntryId.substring(5) : '';

    final dataCells = [
      isRepresentingScheduledAppointment ? arrivalDisplayTime : (item.queueNumber).toString(),
      item.patientName,
      isRepresentingScheduledAppointment ? "-" : arrivalDisplayTime,
      item.conditionOrPurpose ?? 'N/A',
      item.paymentStatus,
    ];

    TextStyle paymentStatusStyle = TextStyle(
        fontSize: cellStyle.fontSize,
        fontWeight: FontWeight.w500,
        color: item.paymentStatus == 'Paid' 
            ? Colors.green.shade700 
            : (item.paymentStatus == 'Pending' ? Colors.orange.shade800 : Colors.grey.shade700)
    );
    if (isRepresentingScheduledAppointment && item.status == 'Scheduled'){
        paymentStatusStyle = paymentStatusStyle.copyWith(color: Colors.purple.shade700);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
          color: isRepresentingScheduledAppointment && item.status == 'Scheduled' ? Colors.purple[50] : (item.status == 'removed'
              ? Colors.grey.shade200
              : (item.status == 'served' ? Colors.lightGreen[50] : Colors.white)),
          border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex = 1;
            TextStyle currentCellStyle = cellStyle;

            switch (idx) {
              case 0:
                flex = 1;
                currentCellStyle = cellStyle.copyWith(fontWeight: FontWeight.bold);
                if (isRepresentingScheduledAppointment) currentCellStyle = currentCellStyle.copyWith(color: Colors.purple[700]);
                break;
              case 1:
                flex = 2;
                break;
              case 2:
                flex = 1;
                break;
              case 3:
                flex = 2;
                break;
              case 4:
                flex = 1;
                currentCellStyle = paymentStatusStyle;
                break;
            }

            return Expanded(
                flex: flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TableCellWidget(
                    child: Text(text, style: currentCellStyle, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                ));
          }).toList(),
          Expanded(
            flex: 3,
            child: isRepresentingScheduledAppointment && item.status == 'Scheduled' 
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton.icon(
                        icon: Icon(Icons.play_circle_outline, size: 16),
                        label: Text("Activate", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          if (item.paymentStatus != 'Paid' && item.paymentStatus != 'Waived') {
                          }
                          _activateAndCallScheduledPatient(originalAppointmentId);
                        },
                    ), 
                  )
                : TableCellWidget(
                    child: Text(_getDisplayStatus(item.status),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(item.status),
                            fontSize: cellStyle.fontSize),
                        textAlign: TextAlign.center)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveQueueDisplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Live Patient Queue (Today)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700])),
            IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _refreshAllData, // Make sure _refreshAllData exists
                tooltip: 'Refresh Queue & Appointments',
                color: Colors.teal[700]),
          ],
        ),
        const SizedBox(height: 8),
        _buildTableHeader(), // Make sure _buildTableHeader exists
        _isLoadingQueueAndAppointments
            ? const Center(child: CircularProgressIndicator(key: Key('liveQueueLoadingIndicator')))
            : _combinedQueueForDisplayList.isEmpty
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                        child: Text('No patients in queue or scheduled for today.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center)))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), // Important for nested scrolling
                    itemCount: _combinedQueueForDisplayList.length,
                    itemBuilder: (context, index) {
                        final item = _combinedQueueForDisplayList[index];
                        // Assuming item is always ActivePatientQueueItem due to list construction in _loadCombinedQueueData
                        return _buildTableRow(item as ActivePatientQueueItem); // Make sure _buildTableRow exists and handles item
                    },
                  ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_walk, size: 18),
              label: const Text('Next Walk-In'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  textStyle:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              onPressed: _nextPatient, 
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Call Scheduled'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  textStyle:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              onPressed: _callNextScheduled, 
            ),
          ],
        ),
        const SizedBox(height: 16), // Optional: Add some padding at the bottom of the section
      ],
    );
  }
}
