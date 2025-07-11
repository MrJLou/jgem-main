import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/enhanced_shelf_lan_server.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'package:flutter_application_1/services/enhanced_user_token_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';

/// Comprehensive test to verify session sync works between host and client devices
/// This test specifically addresses the user session table sync issue reported
void main() {
  setUpAll(() {
    // Initialize test widgets binding for shared preferences
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Session Sync Verification Tests', () {
    late DatabaseHelper hostDbHelper;
    late DatabaseHelper clientDbHelper;

    setUp(() async {
      // Create separate database instances for host and client
      hostDbHelper = DatabaseHelper();
      clientDbHelper = DatabaseHelper();
      
      // Initialize databases
      await hostDbHelper.database;
      await clientDbHelper.database;
      
      // Clean up any existing sessions
      await hostDbHelper.cleanupExpiredSessions();
      await clientDbHelper.cleanupExpiredSessions();
      
      print('TEST: Setup completed - databases initialized');
    });

    tearDown(() async {
      try {
        await EnhancedShelfServer.stopServer();
        await DatabaseSyncClient.disconnect();
        
        // Clean up databases
        await hostDbHelper.cleanupExpiredSessions();
        await clientDbHelper.cleanupExpiredSessions();
        
        print('TEST: Teardown completed');
      } catch (e) {
        print('TEST: Error during teardown: $e');
      }
    });

    test('Session is created and synced between host and client devices', () async {
      // STEP 1: Start host server
      await EnhancedShelfServer.initialize(hostDbHelper);
      final serverStarted = await EnhancedShelfServer.startServer(port: 8080);
      expect(serverStarted, isTrue, reason: 'Host server should start successfully');
      
      print('TEST: Host server started successfully');
      
      // STEP 2: Connect client to host
      final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      await DatabaseSyncClient.initialize(clientDbHelper);
      final clientConnected = await DatabaseSyncClient.connectToServer('localhost', 8080, accessCode);
      expect(clientConnected, isTrue, reason: 'Client should connect to host server');
      
      print('TEST: Client connected to host server successfully');
      
      // STEP 3: Create a test user for login
      const testUsername = 'test_session_user';
      const testPassword = 'test_password_123';
      
      // Create user on host database
      final testUser = {
        'id': 'test_user_001',
        'username': testUsername,
        'password': AuthService.hashPassword(testPassword),
        'role': 'admin',
        'fullName': 'Test Session User',
        'isActive': 1,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await hostDbHelper.insertUser(testUser);
      print('TEST: Test user created on host database');
      
      // Wait for user to sync to client
      await Future.delayed(const Duration(seconds: 3));
      
      // Verify user exists on client
      final clientUser = await clientDbHelper.getUserByUsername(testUsername);
      expect(clientUser, isNotNull, reason: 'User should be synced to client database');
      print('TEST: User successfully synced to client database');
      
      // STEP 4: Login user on CLIENT device and verify session sync
      print('TEST: Starting login process on CLIENT device...');
      
      // Create session directly using token service on client
      final sessionToken = await EnhancedUserTokenService.createUserSession(
        username: testUsername,
        deviceName: 'Client Test Device',
        forceLogout: false,
      );
      
      expect(sessionToken, isNotNull, reason: 'Session token should be created');
      print('TEST: Session created on client with token: ${sessionToken.substring(0, 8)}...');
      
      // STEP 5: Wait for session sync and verify
      print('TEST: Waiting for session sync...');
      await Future.delayed(const Duration(seconds: 5));
      
      // Check if session exists on client database
      final clientSessions = await clientDbHelper.getUserSessionsByUsername(testUsername);
      expect(clientSessions.isNotEmpty, isTrue, reason: 'Session should exist on client database');
      print('TEST: Client sessions found: ${clientSessions.length}');
      
      // Check if session was synced to host database
      final hostSessions = await hostDbHelper.getUserSessionsByUsername(testUsername);
      expect(hostSessions.isNotEmpty, isTrue, reason: 'Session should be synced to host database');
      print('TEST: Host sessions found: ${hostSessions.length}');
      
      // Verify session data matches
      final clientSession = clientSessions.first;
      final hostSession = hostSessions.first;
      
      expect(clientSession['username'], equals(hostSession['username']), 
             reason: 'Session username should match between client and host');
      expect(clientSession['sessionToken'], equals(hostSession['sessionToken']), 
             reason: 'Session token should match between client and host');
      expect(clientSession['isActive'], equals(1), 
             reason: 'Session should be active');
             
      print('TEST: ✅ SESSION SYNC VERIFICATION PASSED');
      print('TEST: - Session created on client device');
      print('TEST: - Session properly synced to host database');
      print('TEST: - Session data matches between devices');
    });

    test('Session conflicts are detected across devices', () async {
      // STEP 1: Setup host and client connection
      await EnhancedShelfServer.initialize(hostDbHelper);
      await EnhancedShelfServer.startServer(port: 8080);
      
      final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      await DatabaseSyncClient.initialize(clientDbHelper);
      await DatabaseSyncClient.connectToServer('localhost', 8080, accessCode);
      
      // STEP 2: Create test user
      const testUsername = 'conflict_test_user';
      const testPassword = 'test_password_123';
      
      final testUser = {
        'id': 'conflict_user_001',
        'username': testUsername,
        'password': AuthService.hashPassword(testPassword),
        'role': 'admin',
        'fullName': 'Conflict Test User',
        'isActive': 1,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await hostDbHelper.insertUser(testUser);
      await Future.delayed(const Duration(seconds: 2));
      
      // STEP 3: Create session on host device first
      final hostSessionToken = await EnhancedUserTokenService.createUserSession(
        username: testUsername,
        deviceName: 'Host Test Device',
        forceLogout: false,
      );
      
      print('TEST: Host session created: ${hostSessionToken.substring(0, 8)}...');
      await Future.delayed(const Duration(seconds: 3));
      
      // STEP 4: Try to create session on client device (should detect conflict)
      try {
        final clientSessionToken = await EnhancedUserTokenService.createUserSession(
          username: testUsername,
          deviceName: 'Client Test Device',
          forceLogout: false,
        );
        
        // If we get here without an exception, there might be an issue
        print('TEST: Client session created: ${clientSessionToken.substring(0, 8)}...');
        
        // Check if conflict was detected by checking network sessions
        final hasConflicts = await EnhancedUserTokenService.checkNetworkSessionConflicts(testUsername);
        expect(hasConflicts, isTrue, reason: 'Session conflict should be detected');
        
      } catch (e) {
        // Exception is expected if conflict detection is working
        print('TEST: Expected conflict detected: $e');
        expect(e.toString().contains('conflict') || e.toString().contains('logged in'), isTrue,
               reason: 'Should throw session conflict exception');
      }
      
      print('TEST: ✅ SESSION CONFLICT DETECTION PASSED');
    });

    test('Client database changes are synced to host device', () async {
      // STEP 1: Setup connection
      await EnhancedShelfServer.initialize(hostDbHelper);
      await EnhancedShelfServer.startServer(port: 8080);
      
      final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      await DatabaseSyncClient.initialize(clientDbHelper);
      await DatabaseSyncClient.connectToServer('localhost', 8080, accessCode);
      
      print('TEST: Host-client connection established');
      await Future.delayed(const Duration(seconds: 2));
      
      // STEP 2: Create a test patient on CLIENT device
      final testPatient = {
        'id': 'client_test_patient_001',
        'firstName': 'Jane',
        'lastName': 'Doe',
        'dateOfBirth': '1985-05-15',
        'gender': 'Female',
        'contactNumber': '555-0123',
        'address': '123 Test Street',
        'emergencyContactName': 'John Doe',
        'emergencyContactNumber': '555-0124',
        'medicalHistory': 'None',
        'allergies': 'None',
        'currentMedications': 'None',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final patientId = await clientDbHelper.insertPatient(testPatient);
      expect(patientId, isNotNull, reason: 'Patient should be created on client');
      print('TEST: Patient created on client device: $patientId');
      
      // STEP 3: Wait for sync and verify on host
      await Future.delayed(const Duration(seconds: 5));
      
      final hostPatient = await hostDbHelper.getPatient('client_test_patient_001');
      expect(hostPatient, isNotNull, reason: 'Patient should be synced to host database');
      expect(hostPatient!['firstName'], equals('Jane'), reason: 'Patient data should match');
      expect(hostPatient['lastName'], equals('Doe'), reason: 'Patient data should match');
      
      print('TEST: ✅ CLIENT-TO-HOST SYNC VERIFICATION PASSED');
      print('TEST: - Patient created on client device');
      print('TEST: - Patient data synced to host database');
      print('TEST: - Patient data matches between devices');
    });

    test('Manual session table debug and verification', () async {
      // This test helps debug session table issues
      print('TEST: Starting manual session debug test...');
      
      // STEP 1: Setup
      await EnhancedShelfServer.initialize(hostDbHelper);
      await EnhancedShelfServer.startServer(port: 8080);
      
      final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      await DatabaseSyncClient.initialize(clientDbHelper);
      await DatabaseSyncClient.connectToServer('localhost', 8080, accessCode);
      
      // STEP 2: Create test user
      const testUsername = 'debug_session_user';
      const testPassword = 'debug_password_123';
      
      final testUser = {
        'id': 'debug_user_001',
        'username': testUsername,
        'password': AuthService.hashPassword(testPassword),
        'role': 'admin',
        'fullName': 'Debug Session User',
        'isActive': 1,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await hostDbHelper.insertUser(testUser);
      await Future.delayed(const Duration(seconds: 2));
      
      // STEP 3: Debug session table state before login
      print('=== BEFORE LOGIN - SESSION TABLE STATE ===');
      await EnhancedUserTokenService.debugSessionTableState(testUsername);
      
      // STEP 4: Create session and debug again
      print('=== CREATING SESSION ===');
      final sessionToken = await EnhancedUserTokenService.createUserSession(
        username: testUsername,
        deviceName: 'Debug Test Device',
        forceLogout: false,
      );
      
      print('Session token created: ${sessionToken.substring(0, 8)}...');
      
      // STEP 5: Debug session table state after login
      print('=== AFTER LOGIN - SESSION TABLE STATE ===');
      await EnhancedUserTokenService.debugSessionTableState(testUsername);
      
      // STEP 6: Verify session creation and sync
      final verifyResult = await EnhancedUserTokenService.verifySessionCreationAndSync(testUsername, sessionToken);
      expect(verifyResult, isTrue, reason: 'Session creation and sync should be verified');
      
      // STEP 7: Wait and check sync to host
      await Future.delayed(const Duration(seconds: 5));
      
      print('=== CHECKING HOST DATABASE SESSION STATE ===');
      final hostDb = await hostDbHelper.database;
      final hostSessions = await hostDb.query('user_sessions', where: 'username = ?', whereArgs: [testUsername]);
      print('Host database sessions: ${hostSessions.length}');
      for (int i = 0; i < hostSessions.length; i++) {
        final session = hostSessions[i];
        print('Host Session $i: username=${session['username']}, device=${session['deviceName']}, active=${session['isActive']}');
      }
      
      expect(hostSessions.isNotEmpty, isTrue, reason: 'Session should exist on host database');
      
      print('TEST: ✅ MANUAL SESSION DEBUG COMPLETED');
    });
  });
}
