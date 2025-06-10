import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'user_registration_screen.dart';
import 'patient_registration_screen.dart';
import 'service_registration_screen.dart';

class RegistrationHubScreen extends StatefulWidget {
  const RegistrationHubScreen({super.key});

  @override
  State<RegistrationHubScreen> createState() => _RegistrationHubScreenState();
}

class _RegistrationHubScreenState extends State<RegistrationHubScreen> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final credentials = await AuthService.getSavedCredentials();
    if (credentials != null && credentials['accessLevel'] != null) {
      if (mounted) {
        setState(() {
          _userRole = credentials['accessLevel'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Hub',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.app_registration,
                    size: 32,
                    color: Colors.teal[800],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registration',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Select registration type',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  children: _buildRegistrationOptions(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRegistrationOptions(BuildContext context) {
    final List<Widget> allOptions = [
      _buildFeatureCard(
        context,
        icon: Icons.person_add_alt_1,
        title: 'User Registration',
        subtitle: 'Register new staff and administrators',
        color: Colors.teal[700]!,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserRegistrationScreen(),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _buildFeatureCard(
        context,
        icon: Icons.accessible_forward,
        title: 'Patient Registration',
        subtitle: 'Register new patients',
        color: Colors.teal[600]!,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientRegistrationScreen(),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _buildFeatureCard(
        context,
        icon: Icons.medical_services_outlined,
        title: 'Service Registration',
        subtitle: 'Register medical services',
        color: Colors.teal[500]!,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ServiceRegistrationScreen(),
          ),
        ),
      ),
    ];

    if (_userRole == null) {
      // Show a loading indicator or an empty state while role is being determined
      return [const Center(child: CircularProgressIndicator())];
    }

    if (_userRole == 'medtech') {
      // Find the patient registration card and return only it.
      final patientRegistrationCard = allOptions.firstWhere(
        (widget) =>
            widget is Card &&
            (widget.child as InkWell).onTap.toString().contains('PatientRegistrationScreen'),
        orElse: () => const SizedBox.shrink(),
      );
      return [patientRegistrationCard];
    }

    // Admins and other roles see all options.
    return allOptions;
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
