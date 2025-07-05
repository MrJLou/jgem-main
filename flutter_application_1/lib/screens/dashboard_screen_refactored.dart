import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/authentication_manager.dart';
import '../widgets/dashboard/dashboard_menu_config.dart';
import '../widgets/dashboard/dashboard_navigation_item.dart';
import '../services/help_manual_pdf_service.dart';
import 'dart:async';

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

  final bool _isLoading = false;

  late List<String> _menuTitles;
  late List<Widget> _screens;
  late List<IconData> _menuIcons;

  StreamSubscription? _sessionSubscription;

  @override
  void initState() {
    if (kDebugMode) {
      print('DEBUG: DashboardScreen initState START');
    }
    super.initState();
    _configureMenuForRole();
    if (kDebugMode) {
      print('DEBUG: DashboardScreen initState END');
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _configureMenuForRole() {
    if (kDebugMode) {
      print(
          'DEBUG: Received accessLevel in _configureMenuForRole: ${widget.accessLevel}');
    }

    final menuConfig =
        DashboardMenuConfig.configureMenuForRole(widget.accessLevel);

    setState(() {
      _menuTitles = menuConfig.titles;
      _screens = menuConfig.screens;
      _menuIcons = menuConfig.icons;

      if (_selectedIndex >= _menuTitles.length) {
        _selectedIndex = 0;
      }
    });
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Confirm Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout? You will be redirected to the login screen.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true) {
      await AuthenticationManager.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_menuTitles.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'User Manual',
            onPressed: () => _showHelpManualOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
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
              clipBehavior: Clip.hardEdge,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _isHovered ? 240 : 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                border: Border(
                  right: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1.0,
                  ),
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 16),
                itemCount: _menuTitles.length,
                itemBuilder: (context, index) {
                  if (_menuTitles[index] == '---') {
                    return const Divider(
                      color: Colors.white30,
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                    );
                  }
                  return DashboardNavigationItem(
                    index: index,
                    selectedIndex: _selectedIndex,
                    isHovered: _isHovered,
                    icon: _menuIcons[index],
                    title: _menuTitles[index],
                    hoveredItems: _hoveredItems,
                    onTap: () => setState(() => _selectedIndex = index),
                    onHover: (index, isHovered) =>
                        setState(() => _hoveredItems[index] = isHovered),
                  );
                },
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
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

  void _showHelpManualOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.description, color: Colors.teal[700]),
              const SizedBox(width: 10),
              const Text('User Manual Options'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose how you would like to access the user manual:',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await HelpManualPdfService.printHelpManual();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error printing manual: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Print Manual'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await HelpManualPdfService.saveHelpManual();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving manual: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
