import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'services/auth_service.dart';
import 'services/real_time_sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dashboard_overview_screen.dart';
import 'screens/laboratory/laboratory_hub_screen.dart';
import 'screens/lan_client_connection_screen.dart';
import 'services/lan_connection_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize appropriate database factory based on platform
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await ApiService.initializeDatabaseForLan();

  // Initialize real-time sync service for persistent connection
  await RealTimeSyncService.initialize();

  runApp(const PatientRecordManagementApp());
}

class PatientRecordManagementApp extends StatelessWidget {
  const PatientRecordManagementApp({super.key});

  @override // Added missing override annotation
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patient Record Management',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _AuthWrapper(), // Changed to auth wrapper
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardScreen(
              accessLevel: 'admin',
            ), // Add route for DashboardScreen
        '/laboratory-hub': (context) =>
            LaboratoryHubScreen(), // Add route for LaboratoryHubScreen
        '/lan-connection': (context) => const LanConnectionScreen(),
        '/lan-client': (context) => const LanClientConnectionScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data == true) {
          return DashboardOverviewScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
