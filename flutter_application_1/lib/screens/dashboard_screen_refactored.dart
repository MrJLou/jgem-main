// Refactored dashboard screen with modular components
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import '../services/queue_service.dart';
import '../widgets/dashboard/dashboard_menu_config.dart';
import '../widgets/dashboard/dashboard_navigation_item.dart';
import '../widgets/appointments/appointment_form.dart';
import '../screens/settings/user_profile_screen.dart';
import '../screens/settings/appearance_settings_screen.dart';
import '../screens/settings/system_settings_screen.dart';
import '../screens/logs/user_activity_log_screen.dart';
import '../screens/lan_client_connection_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String accessLevel;
  const DashboardScreen({super.key, required this.accessLevel});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isHovered = false;
  final Map<int, bool> _hoveredItems = {};

  final DateTime _selectedDate = DateTime.now();
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

  @override
  void initState() {
    if (kDebugMode) {
      print('DEBUG: DashboardScreen initState START');
    }
    super.initState();
    _queueService = QueueService();
    _configureMenuForRole();
    _loadInitialData();
    if (kDebugMode) {
      print('DEBUG: DashboardScreen initState END');
    }
  }

  void _configureMenuForRole() {
    if (kDebugMode) {
      print('DEBUG: Received accessLevel in _configureMenuForRole: ${widget.accessLevel}');
    }
    
    final menuConfig = DashboardMenuConfig.configureMenuForRole(widget.accessLevel);
    
    setState(() {
      _menuTitles = menuConfig.titles;
      _screens = menuConfig.screens;
      _menuIcons = menuConfig.icons;

      if (_selectedIndex >= _menuTitles.length) {
        _selectedIndex = 0;
      }
    });
  }

  String _generatePatientId() {
    return 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  Future<void> _loadAppointments() async {
    if (kDebugMode) {
      print('DEBUG: DashboardScreen _loadAppointments START');
    }
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      final appointments = await ApiService.getAllAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('DEBUG: DashboardScreen _loadAppointments ERROR: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appointments: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // Load appointments
    await _loadAppointments();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAppointment() async {
    if (_appointmentFormKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final newAppointment = Appointment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: _patientIdController.text,
          doctorId: _doctorController.text,
          date: _selectedDate,
          time: _selectedTime,
          status: 'Pending',
          consultationType: _notesController.text.isNotEmpty ? _notesController.text : 'General',
          selectedServices: [],
          totalPrice: 0.0,
        );
        
        // Save appointment via API
        await ApiService.createAppointment(newAppointment);
        
        if (mounted) {
          setState(() {
            _appointments.add(newAppointment);
            _isAddingAppointment = false;
          });
          
          // Clear form
          _patientNameController.clear();
          _patientIdController.clear();
          _doctorController.clear();
          _notesController.clear();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment saved successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Failed to save appointment: $e');
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
        setState(() {
          final index = _appointments.indexWhere((apt) => apt.id == id);
          if (index != -1) {
            _appointments[index] = _appointments[index].copyWith(status: newStatus);
          }
        });
      }
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to update appointment: $e');
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
              if (_isAddingAppointment)
                AppointmentForm(
                  formKey: _appointmentFormKey,
                  patientNameController: _patientNameController,
                  patientIdController: _patientIdController,
                  doctorController: _doctorController,
                  notesController: _notesController,
                  selectedDate: _selectedDate,
                  selectedTime: _selectedTime,
                  onTimeChanged: (time) => setState(() => _selectedTime = time),
                  onSave: _saveAppointment,
                  onCancel: () => setState(() => _isAddingAppointment = false),
                  generatePatientId: _generatePatientId,
                ),
              if (!_isAddingAppointment)
                ElevatedButton(
                  onPressed: () => setState(() => _isAddingAppointment = true),
                  child: const Text('Add New Appointment'),
                ),
            ],
          );
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildNavigationItem(int index) {
    return DashboardNavigationItem(
      index: index,
      selectedIndex: _selectedIndex,
      isHovered: _isHovered,
      icon: _menuIcons[index],
      title: _menuTitles[index],
      hoveredItems: _hoveredItems,
      onTap: () => setState(() => _selectedIndex = index),
      onHover: (index, isHovered) => setState(() => _hoveredItems[index] = isHovered),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_menuTitles.isEmpty && widget.accessLevel != 'patient') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('J-Gem Medical and Diagnostic Clinic'),
          backgroundColor: Colors.teal[700],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_menuTitles.isEmpty && widget.accessLevel == 'patient') {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Patient Dashboard"),
          backgroundColor: Colors.teal[700],
        ),
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
                    color: Colors.black.withAlpha(26),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/slide1.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.medical_services_outlined,
                    color: Colors.teal,
                    size: 28,
                  ),
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
                    MaterialPageRoute(builder: (context) => const SystemSettingsScreen()),
                  );
                  break;
                case 'activity_log':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserActivityLogScreen()),
                  );
                  break;
                case 'lan_connection':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LanClientConnectionScreen()),
                  );
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'user_profile',
                child: ListTile(
                  leading: Icon(Icons.account_circle_outlined),
                  title: Text('User Profile'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'appearance_settings',
                child: ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Appearance'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'system_settings',
                child: ListTile(
                  leading: Icon(Icons.settings_applications),
                  title: Text('System Settings'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'activity_log',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Activity Log'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'lan_connection',
                child: ListTile(
                  leading: Icon(Icons.wifi),
                  title: Text('LAN Connection'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
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
              width: _isHovered ? 220 : 72, // Increased width when hovered
              constraints: BoxConstraints(
                minWidth: 72,
                maxWidth: _isHovered ? 220 : 72, // Ensure max width constraint
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 2)
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // First two navigation items
                    ...List.generate(
                      2,
                      (index) => _buildNavigationItem(index),
                    ),
                    // Divider before Analytics Hub
                    if (_isHovered)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Divider(thickness: 1, color: Colors.grey),
                      )
                    else
                      const SizedBox(height: 8),

                    // Analytics Hub and Report
                    ...List.generate(
                      2,
                      (index) => _buildNavigationItem(index + 2),
                    ),
                    
                    // Divider after Report
                    if (_isHovered)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Divider(thickness: 1, color: Colors.grey),
                      )
                    else
                      const SizedBox(height: 8),
                    // Remaining navigation items
                    ...List.generate(
                      _menuTitles.length - 4,
                      (index) => _buildNavigationItem(index + 4),
                    ),
                  ],
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
