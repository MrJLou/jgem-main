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

  // Define all possible menu items with their screens and icons
  final Map<String, Map<String, dynamic>> _allMenuItems = {
    'Registration': {
      'screen': RegistrationHubScreen(),
      'icon': Icons.app_registration
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
    'About': {'screen': AboutScreen(), 'icon': Icons.info_outline},
  };

  // Define which menu items each role can access
  final Map<String, List<String>> _rolePermissions = {
    'admin': [
      'Registration',
      'User Management',
      'Maintenance',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Patient Analytics',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'medtech': [
      'Registration',
      'Maintenance',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Patient Analytics',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'doctor': [
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Patient Analytics',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'patient': ['Help', 'About']
  };

  late List<String> _menuTitles;
  late List<Widget> _screens;
  late List<IconData> _menuIcons;

  @override
  void initState() {
    super.initState();
    _configureMenuForRole();
  }

  void _configureMenuForRole() {
    List<String> allowedMenuKeys = _rolePermissions[widget.accessLevel] ??
        _rolePermissions['patient']!;

    List<String> tempTitles = [];
    List<Widget> tempScreens = [];
    List<IconData> tempIcons = [];

    for (String key in _allMenuItems.keys) {
      if (allowedMenuKeys.contains(key)) {
        tempTitles.add(key);
        tempScreens.add(_allMenuItems[key]!['screen'] as Widget);
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

  void _logout() async {
    await AuthService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
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
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.teal.withOpacity(0.15) : 
                       isItemHovered ? Colors.teal.withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _menuIcons[index],
                    color: isSelected || isItemHovered ? Theme.of(context).primaryColor : Colors.grey[600],
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
                              color: isSelected || isItemHovered ? Theme.of(context).primaryColor : Colors.grey[600],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_menuTitles.isEmpty && widget.accessLevel == 'patient') {
      return Scaffold(
        appBar: AppBar(title: const Text("Patient Dashboard")),
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
                    MaterialPageRoute(builder: (context) => const UserActivityLogScreen()),
                  );
                  break;
                case 'lan_connection':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LanClientConnectionScreen()),
                  );
                  break;
                case 'system_settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SystemSettingsScreen()),
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
                    title: Text('Activity Log')
                  ),
                ),
              );
              items.add(
                const PopupMenuItem<String>(
                  value: 'lan_connection',
                  child: ListTile(
                    leading: Icon(Icons.wifi),
                    title: Text('LAN Connection')
                  ),
                ),
              );
              items.add(
                const PopupMenuItem<String>(
                  value: 'system_settings',
                  child: ListTile(
                      leading: Icon(Icons.settings_applications),
                    title: Text('System Settings')
                  ),
                ),
              );
              items.add(const PopupMenuDivider());
              items.add(
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout')
                  ),
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  ),
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
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
