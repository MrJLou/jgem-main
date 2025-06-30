import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/dashboard_screen_refactored.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/enhanced_auth_integration.dart';
import 'services/authentication_manager.dart';
import 'services/enhanced_shelf_lan_server.dart';
import 'services/database_helper.dart';
import 'services/session_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/laboratory/laboratory_hub_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'screens/analytics/analytics_hub_screen.dart';
import 'services/database_sync_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'services/cross_device_session_monitor.dart';

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

  // Clear any stale sync settings that might cause connection to non-existent servers
  await _clearStaleSyncSettings();

  // Initialize database helper with error handling
  DatabaseHelper? dbHelper;
  try {
    dbHelper = DatabaseHelper();
    await dbHelper.database.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('Database initialization timed out');
        throw Exception('Database initialization timeout');
      },
    );
    debugPrint('Database helper initialized successfully');
  } catch (e) {
    debugPrint('Database helper initialization failed: $e');
    // Create a fallback database helper instance
    dbHelper = DatabaseHelper();
  }

  // Initialize ONLY the enhanced Shelf server (consolidated)
  await EnhancedShelfServer.initialize(dbHelper);
  
  // Connect DatabaseHelper to EnhancedShelfServer for automatic sync
  DatabaseHelper.setDatabaseChangeCallback((table, operation, recordId, data) async {
    try {
      // Call the database change handler in EnhancedShelfServer
      await EnhancedShelfServer.onDatabaseChange(table, operation, recordId, data);
      debugPrint('Database change notification sent to Enhanced Shelf Server: $table.$operation');
    } catch (e) {
      debugPrint('Error notifying Enhanced Shelf Server of database change: $e');
    }
  });
  
  // Initialize sync client for connecting to other servers
  await DatabaseSyncClient.initialize(dbHelper);
  
  // Set up session sync listener for cross-device session management
  DatabaseSyncClient.syncUpdates.listen((update) {
    if (update['type'] == 'session_invalidated' || 
        (update['type'] == 'remote_change_applied' && 
         update['change']?['table'] == 'user_sessions')) {
      debugPrint('Session change detected from network: ${update['type']}');
      // The AuthenticationManager will handle session validation during its monitoring
    }
  });
  
  // Initialize authentication manager and cross-device session monitoring
  await EnhancedAuthIntegration.initialize();
  
  // Initialize cross-device session monitor for real-time session tracking
  await CrossDeviceSessionMonitor.initialize();
  
  // Set up enhanced session sync every 5 seconds for critical auth consistency
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      if (DatabaseSyncClient.isConnected || EnhancedShelfServer.isRunning) {
        // Force session table sync more frequently for authentication integrity
        await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
        debugPrint('MAIN: Periodic session sync triggered (every 5s)');
      }
    } catch (e) {
      debugPrint('MAIN: Error during periodic session sync: $e');
    }
  });
  
  // Trigger immediate session sync if connected to ensure all devices have current state
  if (DatabaseSyncClient.isConnected || EnhancedShelfServer.isRunning) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
        debugPrint('Initial session sync triggered successfully');
      } catch (e) {
        debugPrint('Error triggering initial session sync: $e');
      }
    });
  }

  runApp(const PatientRecordManagementApp());
}

class PatientRecordManagementApp extends StatelessWidget {
  const PatientRecordManagementApp({super.key});

  // Create a global navigator key for session notifications
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override // Added missing override annotation
  Widget build(BuildContext context) {
    // Initialize session notification service with navigator key
    SessionNotificationService.initialize(navigatorKey);
    
    return MaterialApp(
      title: 'Patient Record Management',
      navigatorKey: navigatorKey, // Add navigator key for notifications
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const _AuthWrapper(), // Changed to auth wrapper
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(
              accessLevel: 'admin',
            ), // Add route for DashboardScreen
        '/analytics-hub': (context) => const AnalyticsHubScreen(),
        '/laboratory-hub': (context) =>
            const LaboratoryHubScreen(), 
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

    _isLoggedInFuture = AuthenticationManager.isLoggedIn();
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
          return const DashboardScreen(accessLevel: 'admin');
        }
        return const LoginScreen();
      },
    );
  }
}

// Clear any stale sync settings that might cause connection to non-existent servers
Future<void> _clearStaleSyncSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current stored sync settings
    final serverIp = prefs.getString('lan_server_ip');
    final serverPort = prefs.get('lan_server_port');
    
    if (serverIp != null) {
      debugPrint('Found cached sync settings: $serverIp:$serverPort');
      
      // Test if the server is still reachable
      try {
        final port = serverPort is int ? serverPort : (serverPort is String ? int.tryParse(serverPort) ?? 8080 : 8080);
        final socket = await Socket.connect(serverIp, port, timeout: const Duration(seconds: 3));
        socket.destroy();
        debugPrint('Cached server is still reachable - keeping settings');
      } catch (e) {
        debugPrint('Cached server $serverIp:$serverPort is no longer reachable: $e');
        debugPrint('Clearing stale sync settings...');
        
        // Clear the stale settings
        await prefs.remove('lan_server_ip');
        await prefs.remove('lan_server_port');
        await prefs.remove('lan_access_code');
        await prefs.setBool('sync_enabled', false);
        
        debugPrint('Stale sync settings cleared');
      }
    } else {
      debugPrint('No cached sync settings found');
    }
  } catch (e) {
    debugPrint('Error checking/clearing sync settings: $e');
  }
}
