import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'server_management_screen.dart';
import 'lan_client_connection_screen.dart';

class LanConnectionScreen extends StatefulWidget {
  const LanConnectionScreen({super.key});

  @override
  State<LanConnectionScreen> createState() => _LanConnectionScreenState();
}

class _LanConnectionScreenState extends State<LanConnectionScreen> {
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final accessLevel = await AuthService.getCurrentUserAccessLevel();
      setState(() {
        _userRole = accessLevel;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userRole = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('LAN Connection'),
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Admin gets server management, others get client connection
    if (_userRole == 'admin') {
      return const ServerManagementScreen();
    } else {
      return const LanClientConnectionScreen();
    }
  }
}
