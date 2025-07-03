import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/dashboard_screen_refactored.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/enhanced_auth_integration.dart';
import 'services/authentication_manager.dart';
import 'services/enhanced_shelf_lan_server.dart';
import 'services/database_helper.dart';
import 'services/backup_service.dart';
import 'services/session_notification_service.dart';
import 'services/enhanced_user_token_service.dart';
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
  
  // Initialize backup service for database backup/restore functionality
  BackupService.initialize(dbHelper);
  
  // Connect DatabaseHelper to BOTH EnhancedShelfServer AND DatabaseSyncClient for automatic sync
  DatabaseHelper.setDatabaseChangeCallback((table, operation, recordId, data) async {
    try {
      debugPrint('MAIN: Database change detected: $table.$operation for record $recordId');
      
      // Extra debug for queue changes
      if (table == 'active_patient_queue') {
        debugPrint('MAIN: QUEUE CHANGE DETECTED - operation=$operation, recordId=$recordId');
        if (data != null) {
          final patientName = data['patientName'] ?? 'Unknown';
          final status = data['status'] ?? 'Unknown';
          debugPrint('MAIN: QUEUE CHANGE DETAILS - Patient: $patientName, Status: $status');
        }
      }
      
      // CRITICAL FIX: Determine if this is a local change or a remote change being applied
      // If the change has 'source' info, it means it came from a remote client
      final isRemoteChange = data != null && (data.containsKey('source') || data.containsKey('clientInfo'));
      
      debugPrint('MAIN: Change analysis - isRemoteChange: $isRemoteChange, hasData: ${data != null}');
      
      // CRITICAL: Handle BOTH host and client scenarios correctly
      
      // 1. If we're running as a HOST (server), notify OTHER clients (not the sender)
      if (EnhancedShelfServer.isRunning && !isRemoteChange) {
        try {
          debugPrint('MAIN: [HOST] Sending LOCAL change to clients: $table.$operation');
          await EnhancedShelfServer.onDatabaseChange(table, operation, recordId, data);
          debugPrint('MAIN: [HOST] Local database change sent to all clients via Enhanced Shelf Server');
        } catch (e) {
          debugPrint('MAIN: [HOST] Error notifying clients via Enhanced Shelf Server: $e');
        }
      } else if (EnhancedShelfServer.isRunning && isRemoteChange) {
        debugPrint('MAIN: [HOST] Skipping notification for REMOTE change (already handled by WebSocket)');
      }
      
      // 2. If we're running as a CLIENT, notify server ONLY for local changes
      if (DatabaseSyncClient.isConnected && !isRemoteChange && !EnhancedShelfServer.isRunning) {
        try {
          debugPrint('MAIN: [CLIENT] Sending LOCAL change to host: $table.$operation');
          await DatabaseSyncClient.notifyLocalDatabaseChange(table, operation, recordId, data);
          debugPrint('MAIN: [CLIENT] Local database change sent to host server via Database Sync Client');
        } catch (e) {
          debugPrint('MAIN: [CLIENT] Error notifying host server via Database Sync Client: $e');
        }
      } else if (DatabaseSyncClient.isConnected && isRemoteChange) {
        debugPrint('MAIN: [CLIENT] Skipping notification for REMOTE change (came from server)');
      } else if (DatabaseSyncClient.isConnected && EnhancedShelfServer.isRunning) {
        debugPrint('MAIN: [CLIENT] Device is both host and client - not sending to self');
      }
      
      // Special handling for user_sessions table - CRITICAL for authentication sync
      if (table == 'user_sessions' && !isRemoteChange) {
        debugPrint('MAIN: CRITICAL LOCAL SESSION CHANGE - Operation: $operation, Record: $recordId');
        if (data != null) {
          debugPrint('MAIN: Session data: username=${data['username']}, deviceId=${data['deviceId']}, isActive=${data['isActive']}');
        }
        
        // Force immediate session table sync for both host and client (only for local changes)
        if (EnhancedShelfServer.isRunning) {
          try {
            await EnhancedShelfServer.forceSyncTable('user_sessions');
            debugPrint('MAIN: [HOST] Forced immediate user_sessions sync to all clients');
          } catch (e) {
            debugPrint('MAIN: [HOST] Error in forced session sync: $e');
          }
        }
        
        if (DatabaseSyncClient.isConnected && !EnhancedShelfServer.isRunning) {
          try {
            await DatabaseSyncClient.forceSessionSync();
            debugPrint('MAIN: [CLIENT] Forced immediate user_sessions sync to host');
          } catch (e) {
            debugPrint('MAIN: [CLIENT] Error in forced session sync: $e');
          }
        }
      } else if (table == 'user_sessions' && isRemoteChange) {
        debugPrint('MAIN: CRITICAL REMOTE SESSION CHANGE - Skipping additional sync (already handled)');
      }
      
    } catch (e) {
      debugPrint('MAIN: Error handling database change: $e');
    }
  });
  
  // Verify the callback was set
  final hasCallback = DatabaseHelper.hasDatabaseChangeCallback();
  debugPrint('MAIN: Database change callback set successfully: $hasCallback');
  
  // Initialize sync client for connecting to other servers
  await DatabaseSyncClient.initialize(dbHelper);
  
  // Set a timer to verify queue sync in 5 seconds after app startup
  Future.delayed(const Duration(seconds: 5), () async {
    debugPrint('SYNC DEBUG: Running comprehensive sync verification test');
    final isClient = DatabaseSyncClient.isConnected && !EnhancedShelfServer.isRunning;
    final isHost = EnhancedShelfServer.isRunning;
    
    debugPrint('SYNC DEBUG: Device status - isClient: $isClient, isHost: $isHost');
    debugPrint('SYNC DEBUG: Client connected: ${DatabaseSyncClient.isConnected}');
    debugPrint('SYNC DEBUG: Database callback set: ${DatabaseHelper.hasDatabaseChangeCallback()}');
    
    if (isClient) {
      debugPrint('SYNC DEBUG: This is a CLIENT device, testing queue sync chain...');
      
      // Test 1: Verify database change callback works
      try {
        final queueItemId = 'test-queue-item-${DateTime.now().millisecondsSinceEpoch}';
        final testData = {
          'queueEntryId': queueItemId,
          'patientName': 'Test Patient',
          'status': 'waiting'
        };
        debugPrint('SYNC DEBUG: TEST 1 - Testing database change callback');
        await DatabaseHelper.triggerDatabaseChangeCallback(
          'active_patient_queue',
          'insert',
          queueItemId,
          testData
        );
        debugPrint('SYNC DEBUG: TEST 1 - Database change callback test complete');
      } catch (e) {
        debugPrint('SYNC DEBUG: TEST 1 FAILED - Database change callback error: $e');
      }
      
      // Test 2: Verify WebSocket connection status
      debugPrint('SYNC DEBUG: TEST 2 - WebSocket connection verification');
      if (DatabaseSyncClient.isConnected) {
        debugPrint('SYNC DEBUG: TEST 2 PASSED - WebSocket is connected');
      } else {
        debugPrint('SYNC DEBUG: TEST 2 FAILED - WebSocket is NOT connected');
      }
      
    } else if (isHost) {
      debugPrint('SYNC DEBUG: This is a HOST device, server should be ready for client connections');
    } else {
      debugPrint('SYNC DEBUG: This device is not configured as host or client');
    }
  });
  
  // Set up session sync listener for cross-device session management
  DatabaseSyncClient.syncUpdates.listen((update) {
    if (update['type'] == 'session_invalidated' || 
        (update['type'] == 'remote_change_applied' && 
         update['change']?['table'] == 'user_sessions')) {
      debugPrint('MAIN: Session change detected from network: ${update['type']}');
      // Force immediate session refresh to ensure consistency
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final isLoggedIn = await AuthenticationManager.isLoggedIn();
          if (isLoggedIn) {
            final username = await AuthenticationManager.getCurrentUsername();
            if (username != null) {
              // Check for session conflicts and handle appropriately
              final hasConflicts = await EnhancedUserTokenService.checkNetworkSessionConflicts(username);
              if (hasConflicts) {
                debugPrint('MAIN: Session conflict detected, triggering validation');
                await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
              }
            }
          }
        } catch (e) {
          debugPrint('MAIN: Error handling session sync update: $e');
        }
      });
    }
  });
  
  // Initialize authentication manager and cross-device session monitoring
  await EnhancedAuthIntegration.initialize();
  
  // Initialize API service current user role
  await ApiService.initializeCurrentUserRole();
  
  // Initialize cross-device session monitor for real-time session tracking
  await CrossDeviceSessionMonitor.initialize();
  
  // Set up enhanced session sync every 5 minutes for auth consistency (increased from 2min to prevent loops)
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    try {
      // CRITICAL: Only sync if we have an ACTIVE user session to prevent login screen loops
      final prefs = await SharedPreferences.getInstance();
      final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
      
      if (!hasStoredSession) {
        debugPrint('MAIN: No stored session state, skipping periodic sync');
        return;
      }
      
      // Double-check we actually have a valid session
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('MAIN: No active session after verification, skipping periodic sync');
        return;
      }
      
      // Only sync if connected and we have verified active session
      if ((DatabaseSyncClient.isConnected || EnhancedShelfServer.isRunning)) {
        debugPrint('MAIN: Triggering periodic session sync (every 5 minutes) - authenticated user detected');
        await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
      }
    } catch (e) {
      debugPrint('MAIN: Error during periodic session sync: $e');
    }
  });
  
  // Trigger initial session sync if connected (with longer delay to let things settle)
  if (DatabaseSyncClient.isConnected || EnhancedShelfServer.isRunning) {
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        // Only sync if we're actually logged in
        final isLoggedIn = await AuthenticationManager.isLoggedIn();
        if (isLoggedIn) {
          await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
          debugPrint('Initial session sync triggered successfully');
        } else {
          debugPrint('Skipping initial session sync - no active session');
        }
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
      builder: (context, child) {
        // Initialize session notification service after MaterialApp is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SessionNotificationService.initialize(navigatorKey);
        });
        return child!;
      },
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _checkAuthAndInitialize();
  }

  Future<bool> _checkAuthAndInitialize() async {
    if (_isInitialized) {
      return await AuthenticationManager.isLoggedIn();
    }
    
    final isLoggedIn = await AuthenticationManager.isLoggedIn();
    if (isLoggedIn) {
      // Initialize the current user role when app starts
      await ApiService.initializeCurrentUserRole();
    }
    _isInitialized = true;
    return isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('AuthWrapper error: ${snapshot.error}');
          return const LoginScreen();
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
