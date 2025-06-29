import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/enhanced_user_token_service.dart';
import 'package:flutter_application_1/services/authentication_manager.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/enhanced_shelf_lan_server.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/cross_device_session_monitor.dart';
import 'dart:async';

/// Enhanced Authentication Cross-Device Sync Test
/// 
/// This test verifies that session management works correctly across devices
/// and that the LAN sync properly prevents multiple device logins.
void main() {
  group('Enhanced Authentication Cross-Device Tests', () {
    late DatabaseHelper dbHelper1; // Server/Host
    late DatabaseHelper dbHelper2; // Client
    
    setUpAll(() async {
      // Initialize test databases
      dbHelper1 = DatabaseHelper();
      dbHelper2 = DatabaseHelper();
      
      await dbHelper1.database;
      await dbHelper2.database;
      
      // Initialize and start server on host
      await EnhancedShelfServer.initialize(dbHelper1);
      final serverStarted = await EnhancedShelfServer.startServer(port: 8081);
      expect(serverStarted, isTrue);
    });
    
    tearDownAll(() async {
      // Cleanup
      await EnhancedShelfServer.stopServer();
      await DatabaseSyncClient.disconnect();
      CrossDeviceSessionMonitor.dispose();
    });
    
    test('Server prevents multiple device login attempts', () async {
      // Connect client to server
      final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      await DatabaseSyncClient.initialize(dbHelper2);
      final connected = await DatabaseSyncClient.connectToServer(
        'localhost', 
        8081, 
        accessCode
      );
      expect(connected, isTrue);
      
      // Initialize session monitor on client
      await CrossDeviceSessionMonitor.initialize();
      
      const username = 'test_user_sync';
      const password = 'test_password';
      
      // Create test user in both databases
      final testUser = {
        'id': 'test_user_sync_id',
        'username': username,
        'password': AuthService.hashPassword(password),
        'firstName': 'Test',
        'lastName': 'User',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
        'securityQuestion1': 'Test question 1',
        'securityAnswer1': 'Test answer 1',
        'securityQuestion2': 'Test question 2',
        'securityAnswer2': 'Test answer 2',
      };
      
      await dbHelper1.insertUser(testUser);
      await dbHelper2.insertUser(testUser);
      
      // Test 1: Login on first device (server/host) should succeed
      await AuthenticationManager.initialize();
      final loginResult1 = await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: false,
      );
      
      expect(loginResult1['success'], isTrue);
      expect(loginResult1['user'], isNotNull);
      
      // Wait for session to be created and synced
      await Future.delayed(const Duration(seconds: 2));
      
      // Test 2: Attempt login on second device (client) should fail with session conflict
      try {
        await AuthenticationManager.login(
          username: username,
          password: password,
          forceLogout: false,
        );
        
        // This should not succeed - if it does, the test fails
        fail('Login should have failed due to existing session on another device');
      } on UserSessionConflictException catch (e) {
        // This is expected - session conflict should be detected
        expect(e.activeSessions, isNotEmpty);
        expect(e.message, contains('already logged in'));
        if (kDebugMode) {
          print('✅ Session conflict correctly detected: ${e.message}');
        }
      }
      
      // Test 3: Force login on second device should succeed and invalidate first session
      final forceLoginResult = await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: true,
      );
      
      expect(forceLoginResult['success'], isTrue);
      expect(forceLoginResult['user'], isNotNull);
      
      // Wait for session invalidation to sync
      await Future.delayed(const Duration(seconds: 3));
      
      // Test 4: Check that first device session is now invalid
      final firstDeviceSessionValid = await EnhancedUserTokenService.isCurrentSessionValid();
      expect(firstDeviceSessionValid, isFalse);
      
      if (kDebugMode) {
        print('✅ Cross-device session management working correctly');
      }
    });
    
    test('Session sync broadcasts work correctly', () async {
      const username = 'test_user_broadcast';
      
      // Listen for session broadcast events
      final broadcastCompleter = Completer<Map<String, dynamic>>();
      late StreamSubscription subscription;
      
      subscription = DatabaseSyncClient.syncUpdates.listen((update) {
        if (update['type'] == 'session_change_immediate' && 
            update['table'] == 'user_sessions') {
          subscription.cancel();
          broadcastCompleter.complete(update);
        }
      });
      
      // Create a session on the server
      final sessionToken = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Test Device',
        forceLogout: false,
      );
      
      expect(sessionToken, isNotNull);
      
      // Wait for broadcast to be received by client
      final broadcastUpdate = await broadcastCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Session broadcast timeout'),
      );
      
      expect(broadcastUpdate['type'], equals('session_change_immediate'));
      expect(broadcastUpdate['table'], equals('user_sessions'));
      expect(broadcastUpdate['operation'], equals('insert'));
      
      if (kDebugMode) {
        print('✅ Session broadcast sync working correctly');
      }
    });
    
    test('Cross-device session monitoring detects changes', () async {
      const username = 'test_user_monitor';
      
      // Create initial session
      final sessionToken1 = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Device 1',
        forceLogout: false,
      );
      
      expect(sessionToken1, isNotNull);
      
      // Start monitoring
      await CrossDeviceSessionMonitor.initialize();
      
      // Verify monitor status
      final status = CrossDeviceSessionMonitor.getStatus();
      expect(status['isMonitoring'], isTrue);
      
      // Create conflicting session (force logout)
      await Future.delayed(const Duration(milliseconds: 500));
      
      final sessionToken2 = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Device 2', 
        forceLogout: true,
      );
      
      expect(sessionToken2, isNotNull);
      expect(sessionToken2, isNot(equals(sessionToken1)));
      
      // Wait for monitoring to detect the change
      await Future.delayed(const Duration(seconds: 3));
      
      // Verify first session is now invalid
      final isFirstSessionValid = await EnhancedUserTokenService.validateSessionToken(
        username, 
        sessionToken1
      );
      expect(isFirstSessionValid, isFalse);
      
      // Verify second session is valid
      final isSecondSessionValid = await EnhancedUserTokenService.validateSessionToken(
        username, 
        sessionToken2
      );
      expect(isSecondSessionValid, isTrue);
      
      if (kDebugMode) {
        print('✅ Cross-device session monitoring working correctly');
      }
    });
    
    test('Session statistics are accurate across devices', () async {
      // Clean up any existing sessions
      await EnhancedUserTokenService.cleanupExpiredSessions();
      
      // Get initial statistics
      final initialStats = await EnhancedUserTokenService.getSessionStatistics();
      final initialActiveCount = initialStats['activeSessions'] as int;
      
      // Create sessions for multiple users
      final users = ['user1', 'user2', 'user3'];
      final createdTokens = <String>[];
      
      for (final user in users) {
        final token = await EnhancedUserTokenService.createUserSession(
          username: user,
          deviceName: 'Test Device',
          forceLogout: false,
        );
        createdTokens.add(token);
      }
      
      // Get updated statistics
      final updatedStats = await EnhancedUserTokenService.getSessionStatistics();
      final currentActiveCount = updatedStats['activeSessions'] as int;
      
      // Verify session count increased correctly
      expect(currentActiveCount, equals(initialActiveCount + users.length));
      expect(updatedStats['activeUsers'], greaterThanOrEqualTo(users.length));
      
      if (kDebugMode) {
        print('✅ Session statistics working correctly');
      }
      if (kDebugMode) {
        print('   Initial sessions: $initialActiveCount');
      }
      if (kDebugMode) {
        print('   Final sessions: $currentActiveCount');
      }
      if (kDebugMode) {
        print('   Active users: ${updatedStats['activeUsers']}');
      }
    });
  });
}
