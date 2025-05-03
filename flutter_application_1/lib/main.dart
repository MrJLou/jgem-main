import 'package:flutter/material.dart';
import 'services/auth_service.dart'; // Add this import
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart'; // Add this import
import 'screens/dashboard_overview_screen.dart'; // Import the new screen
import 'screens/laboratory/laboratory_hub_screen.dart'; // Import the LaboratoryHubScreen

void main() {
  runApp(PatientRecordManagementApp());
}

class PatientRecordManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patient Record Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _AuthWrapper(), // Changed to auth wrapper
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/dashboard':
            (context) => DashboardScreen(
              accessLevel: 'admin',
            ), // Add route for DashboardScreen
        '/laboratory-hub':
            (context) =>
                LaboratoryHubScreen(), // Add route for LaboratoryHubScreen
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthService.getSavedCredentials(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If credentials exist, go to the new DashboardOverviewScreen
        if (snapshot.hasData && snapshot.data != null) {
          return DashboardOverviewScreen();
        }

        // Otherwise show login screen
        return LoginScreen();
      },
    );
  }
}
