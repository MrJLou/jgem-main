import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/dashboard_screen_refactored.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'services/auth_service.dart';
import 'services/real_time_sync_service.dart';
import 'screens/auth_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_overview_screen.dart';
import 'screens/laboratory/laboratory_hub_screen.dart';
import 'screens/lan_client_connection_screen.dart';
import 'services/lan_connection_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'screens/analytics/analytics_hub_screen.dart';
import 'screens/settings_screen.dart';

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
      ),      home: const _AuthWrapper(), // Changed to auth wrapper
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(
              accessLevel: 'admin',
            ), // Add route for DashboardScreen
        '/analytics-hub': (context) => const AnalyticsHubScreen(),
        '/settings':(context) => const SettingsScreen(),
        '/laboratory-hub': (context) =>
            const LaboratoryHubScreen(), // Provide default accessLevel
        '/lan-connection': (context) => const LanConnectionScreen(),
        '/lan-client': (context) => const LanClientConnectionScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  late final Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();

    _isLoggedInFuture = AuthService.isLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data == true) {
          return const DashboardOverviewScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
