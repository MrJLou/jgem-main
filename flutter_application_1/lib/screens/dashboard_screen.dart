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
    'Live Queue & Analytics': {
      'screen': const SizedBox.shrink(),
      'icon': Icons.ssid_chart_outlined
    },
    'Registration': {
      'screen': RegistrationHubScreen(),
      'icon': Icons.app_registration
    },
    'User Management': {
      'screen': UserManagementScreen(),
      'icon': Icons.manage_accounts
    },
    'User Management': {
      'screen': UserManagementScreen(),
      'icon': Icons.manage_accounts
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
      'screen': const SizedBox.shrink(),
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

  final Map<String, List<String>> _rolePermissions = {
    'admin': [
      'Registration',
      'User Management',
      'User Management',
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
      'Live Queue & Analytics',
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
      'Live Queue & Analytics',
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
    super.initState();
    _queueService = QueueService();
    _configureMenuForRole();
    _loadInitialData();
  }

  void _configureMenuForRole() {
    List<String> allowedMenuKeys =
        _rolePermissions[widget.accessLevel] ?? _rolePermissions['patient']!;

    List<String> tempTitles = [];
    List<Widget> tempScreens = [];
    List<IconData> tempIcons = [];

    String liveQueueAnalyticsKey = 'Live Queue & Analytics';
    if (_allMenuItems.containsKey(liveQueueAnalyticsKey) &&
        allowedMenuKeys.contains(liveQueueAnalyticsKey)) {
      bool prioritize =
          (widget.accessLevel == 'medtech' || widget.accessLevel == 'doctor');
      if (!prioritize) {
        if (allowedMenuKeys.isNotEmpty &&
            allowedMenuKeys.first == liveQueueAnalyticsKey) {
          prioritize = true;
        }
      }

      if (prioritize && !tempTitles.contains(liveQueueAnalyticsKey)) {
        tempTitles.add(liveQueueAnalyticsKey);
        tempScreens.add(LiveQueueDashboardView(queueService: _queueService));
        tempIcons
            .add(_allMenuItems[liveQueueAnalyticsKey]!['icon'] as IconData);
      }
    }

    for (String key in _allMenuItems.keys) {
      if (tempTitles.contains(key)) {
        continue;
      }

      if (allowedMenuKeys.contains(key)) {
        tempTitles.add(key);
        Widget screenToShow;

        if (key == liveQueueAnalyticsKey) {
          screenToShow = LiveQueueDashboardView(queueService: _queueService);
        } else if (key == 'Appointment Schedule') {
          screenToShow = _buildAppointmentModule();
        } else if (key == 'Registration') {
          screenToShow = _allMenuItems[key]!['screen'] as Widget;
        } else {
          screenToShow = _allMenuItems[key]!['screen'] as Widget;
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
        setState(() => _appointments = apiAppointments);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to load appointments: $e (local data shown)')),
        );
      }
      print('Failed to load appointments from API, using local/mock: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadInitialData() async {
    if (!mounted) return;
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
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
    if (_menuTitles == null ||
        (_menuTitles.isEmpty && widget.accessLevel != 'patient')) {
      return Scaffold(
          appBar: AppBar(
              title: Text('Dashboard - ${widget.accessLevel}'),
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
                          builder: (context) => const UserActivityLogScreen()));
                  break;
                case 'lan_connection':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const LanClientConnectionScreen()));
                  break;
                case 'system_settings':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SystemSettingsScreen()));
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
                  children: List.generate(
                    _menuTitles.length,
                    (index) => _buildNavigationItem(index),
                  ),
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
      _queueFuture = widget.queueService
          .getActiveQueueItems(statuses: ['waiting', 'in_consultation']);
    });
  }

  void _refreshQueue() => _loadQueue();

  Future<void> _nextPatient() async {
    if (!mounted) return;
    try {
      final queue = await _queueFuture;
      final waitingPatients =
          queue.where((p) => p.status == 'waiting').toList();
      if (waitingPatients.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No patients currently waiting.'),
            backgroundColor: Colors.amber));
        return;
      }
      waitingPatients.sort((a, b) => (a.queueNumber).compareTo(b.queueNumber));
      final nextPatient = waitingPatients.first;
      bool success = await widget.queueService
          .markPatientAsInConsultation(nextPatient.queueEntryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${nextPatient.patientName} is now In Consultation.'
              : 'Failed to move ${nextPatient.patientName}.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _refreshQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error processing next patient: $e'),
          backgroundColor: Colors.red));
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
      children: [
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Live Patient Queue',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700])),
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshQueue,
                        tooltip: 'Refresh Queue',
                        color: Colors.teal[700]),
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
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                    textAlign: TextAlign.center)));
                      }

                      final queue = snapshot.data!;
                      return ListView.builder(
                        itemCount: queue.length,
                        itemBuilder: (context, index) =>
                            _buildTableRow(queue[index]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.next_plan_outlined),
                    label: const Text('Next Patient'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _nextPatient,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 1,
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
                      color: Colors.teal[700]),
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
      color: Colors.teal[600],
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
                      fontSize: 14)));
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(ActivePatientQueueItem item) {
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';
    final dataCells = [
      (item.queueNumber).toString(),
      item.patientName,
      arrivalDisplayTime,
      item.conditionOrPurpose ?? 'N/A',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value;
            int flex = (idx == 1 || idx == 3) ? 2 : 1;
            return Expanded(
                flex: flex,
                child: TableCellWidget(
                    text: text,
                    style: cellStyle.copyWith(
                        fontWeight:
                            idx == 0 ? FontWeight.bold : FontWeight.normal)));
          }).toList(),
          Expanded(
            flex: 1,
            child: TableCellWidget(
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
}
