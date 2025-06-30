import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/enhanced_user_token_service.dart';
import 'package:flutter_application_1/services/enhanced_shelf_lan_server.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'package:flutter_application_1/services/cross_device_session_monitor.dart';
import 'package:flutter/foundation.dart';

/// Test suite for session sync fixes
/// 
/// This tests specifically for the issues:
/// 1. Duplicate sessions when syncing between host and client
/// 2. Proper UPSERT handling for user_sessions
/// 3. Session creation vs session deletion sync
/// 4. Single session per user enforcement
void main() {
  group('Session Sync Fix Tests', () {
    late DatabaseHelper hostDbHelper;
    late DatabaseHelper clientDbHelper;
    
    const testUsername = 'test_sync_user';
    
    setUpAll(() async {
      // Initialize test databases
      hostDbHelper = DatabaseHelper();
      clientDbHelper = DatabaseHelper();
      
      await hostDbHelper.database;
      await clientDbHelper.database;
      
      // Create test user on both databases
      final testUser = {
        'id': 'test_sync_user_id',
        'username': testUsername,
        'password': '\$2b\$10\$dummyhash', // Dummy bcrypt hash
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
      
      await hostDbHelper.insertUser(testUser);
      await clientDbHelper.insertUser(testUser);
    });
    
    setUp(() async {
      // Clean up sessions before each test
      await hostDbHelper.cleanupExpiredSessions();
      await clientDbHelper.cleanupExpiredSessions();
      
      // Clear all sessions for test user
      final hostDb = await hostDbHelper.database;
      final clientDb = await clientDbHelper.database;
      
      await hostDb.delete('user_sessions', where: 'username = ?', whereArgs: [testUsername]);
      await clientDb.delete('user_sessions', where: 'username = ?', whereArgs: [testUsername]);
    });
    
    tearDownAll(() async {
      // Cleanup
      await EnhancedShelfServer.stopServer();
      await DatabaseSyncClient.disconnect();
      CrossDeviceSessionMonitor.dispose();
    });
    
    test('Single session per user is enforced', () async {
      // Initialize server on host
      await EnhancedShelfServer.initialize(hostDbHelper);
      final serverStarted = await EnhancedShelfServer.startServer(port: 8082);
      expect(serverStarted, isTrue);
      
      // Connect client to host
      final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      await DatabaseSyncClient.initialize(clientDbHelper);
      final connected = await DatabaseSyncClient.connectToServer(
        'localhost', 
        8082, 
        accessCode
      );
      expect(connected, isTrue);
      
      // Initialize session monitor
      await CrossDeviceSessionMonitor.initialize();
      
      // Create session on host
      final sessionToken1 = await EnhancedUserTokenService.createUserSession(
        username: testUsername,
        deviceName: 'Host Device',
        forceLogout: false,
      );
      
      expect(sessionToken1, isNotNull);
      
      // Wait for sync to propagate
      await Future.delayed(const Duration(seconds: 3));
      
      // Check that only one session exists on host
      final hostSessions = await hostDbHelper.getActiveUserSessions(testUsername);
      expect(hostSessions.length, equals(1));
      
      // Check that session is synced to client
      final clientSessions = await clientDbHelper.getActiveUserSessions(testUsername);
      expect(clientSessions.length, equals(1));
      expect(clientSessions.first['sessionToken'], equals(sessionToken1));
      
      // Try to create another session with force logout
      final sessionToken2 = await EnhancedUserTokenService.createUserSession(
        username: testUsername,
        deviceName: 'Host Device 2',
        forceLogout: true,
      );
      
      expect(sessionToken2, isNotNull);
      expect(sessionToken2, isNot(equals(sessionToken1)));
      
      // Wait for sync
      await Future.delayed(const Duration(seconds: 3));
      
      // Verify only one session exists on both devices
      final hostSessionsAfter = await hostDbHelper.getActiveUserSessions(testUsername);
      final clientSessionsAfter = await clientDbHelper.getActiveUserSessions(testUsername);
      
      expect(hostSessionsAfter.length, equals(1));
      expect(clientSessionsAfter.length, equals(1));
      expect(hostSessionsAfter.first['sessionToken'], equals(sessionToken2));
      expect(clientSessionsAfter.first['sessionToken'], equals(sessionToken2));
      
      if (kDebugMode) {
        print('✅ Single session per user enforcement working correctly');
      }
    });
    
    test('Session deletion syncs properly', () async {
      // Create a session
      final sessionToken = await EnhancedUserTokenService.createUserSession(
        username: testUsername,
        deviceName: 'Test Device',
        forceLogout: false,
      );
      
      // Wait for sync
      await Future.delayed(const Duration(seconds: 2));
      
      // Verify session exists on both databases
      final hostSessionsBefore = await hostDbHelper.getActiveUserSessions(testUsername);
      final clientSessionsBefore = await clientDbHelper.getActiveUserSessions(testUsername);
      
      expect(hostSessionsBefore.length, equals(1));
      expect(clientSessionsBefore.length, equals(1));
      
      // Delete the session
      await EnhancedUserTokenService.invalidateSession(sessionToken);
      
      // Wait for sync
      await Future.delayed(const Duration(seconds: 3));
      
      // Verify session is deleted from both databases
      final hostSessionsAfter = await hostDbHelper.getActiveUserSessions(testUsername);
      final clientSessionsAfter = await clientDbHelper.getActiveUserSessions(testUsername);
      
      expect(hostSessionsAfter.length, equals(0));
      expect(clientSessionsAfter.length, equals(0));
      
      if (kDebugMode) {
        print('✅ Session deletion sync working correctly');
      }
    });
    
    test('No duplicate sessions during rapid sync operations', () async {
      // Create multiple sessions rapidly to test race conditions
      final futures = <Future<String>>[];
      
      for (int i = 0; i < 3; i++) {
        futures.add(
          EnhancedUserTokenService.createUserSession(
            username: testUsername,
            deviceName: 'Device $i',
            forceLogout: true, // Each should force logout the previous
          ).catchError((e) {
            // Some may fail due to conflicts - that's expected
            debugPrint('Session creation $i failed (expected): $e');
            return 'failed';
          })
        );
        
        // Small delay to create race condition
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Wait for all to complete
      final results = await Future.wait(futures);
      final successfulSessions = results.where((r) => r != 'failed').toList();
      
      // Wait for sync to complete
      await Future.delayed(const Duration(seconds: 5));
      
      // Check final state - should have exactly 1 session
      final hostSessions = await hostDbHelper.getActiveUserSessions(testUsername);
      final clientSessions = await clientDbHelper.getActiveUserSessions(testUsername);
      
      expect(hostSessions.length, equals(1));
      expect(clientSessions.length, equals(1));
      
      // Sessions should match
      expect(hostSessions.first['sessionToken'], equals(clientSessions.first['sessionToken']));
      
      if (kDebugMode) {
        print('✅ No duplicate sessions during rapid operations - final count: ${hostSessions.length}');
        print('Successful session creations: ${successfulSessions.length}');
      }
    });
    
    test('Client device properly receives host sessions', () async {
      // Simulate a scenario where client should receive session from host, not create its own
      
      // Create session directly on host database (bypass token service to simulate host-only creation)
      final hostDb = await hostDbHelper.database;
      const sessionId = 'test_session_id';
      const sessionToken = 'test_session_token_host';
      final now = DateTime.now();
      
      await hostDb.insert('user_sessions', {
        'id': sessionId,
        'session_id': sessionId,
        'userId': 'test_sync_user_id',
        'username': testUsername,
        'deviceId': 'host_device_id',
        'deviceName': 'Host Device',
        'loginTime': now.toIso8601String(),
        'lastActivity': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 8)).toIso8601String(),
        'expiresAt': now.add(const Duration(hours: 8)).toIso8601String(),
        'invalidated_at': null,
        'ipAddress': '192.168.1.1',
        'isActive': 1,
        'sessionToken': sessionToken,
      });
      
      // Trigger sync to client
      await DatabaseSyncClient.manualSync();
      await Future.delayed(const Duration(seconds: 2));
      
      // Verify client received the session
      final clientSessions = await clientDbHelper.getActiveUserSessions(testUsername);
      expect(clientSessions.length, equals(1));
      expect(clientSessions.first['sessionToken'], equals(sessionToken));
      expect(clientSessions.first['deviceName'], equals('Host Device'));
      
      if (kDebugMode) {
        print('✅ Client properly received host session without creating duplicate');
      }
    });
  });
}
