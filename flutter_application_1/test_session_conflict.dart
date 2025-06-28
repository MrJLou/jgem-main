/// Comprehensive test script for session conflict handling
/// This script will simulate multiple device login scenarios and verify the conflict resolution
import 'dart:async';
import 'dart:io';
import 'lib/services/database_helper.dart';
import 'lib/services/auth_service.dart';

Future<void> main() async {
  print('🔧 INITIALIZING SESSION CONFLICT TEST ENVIRONMENT...');
  print('');
  
  // Initialize database for testing
  final dbHelper = DatabaseHelper();
  await dbHelper.database; // Initialize database
  
  print('✅ Test environment initialized');
  print('');
  
  // Test user credentials
  const testUsername = 'test_user';
  const testPassword = 'test_password_123';
  
  print('🧪 RUNNING SESSION CONFLICT TESTS...');
  print('');
  
  try {
    await _runSessionConflictTests(testUsername, testPassword);
    print('');
    print('🎉 ALL SESSION CONFLICT TESTS PASSED!');
  } catch (e) {
    print('❌ TEST FAILED: $e');
    exit(1);
  }
}

Future<void> _runSessionConflictTests(String username, String password) async {
  print('TEST 1: Normal login (no existing session)');
  print('----------------------------------------');
  
  // Clear any existing sessions
  await _clearExistingSessions(username);
  
  // Attempt normal login
  try {
    await AuthService.loginWithSessionManagement(username, password);
    print('✅ Normal login successful');
  } catch (e) {
    print('❌ Normal login failed: $e');
    throw Exception('Normal login test failed');
  }
  
  print('');
  print('TEST 2: Session conflict detection');
  print('----------------------------------');
  
  // Try to login again (should detect session conflict)
  try {
    await AuthService.loginWithSessionManagement(username, password);
    print('❌ Session conflict not detected! This should have failed.');
    throw Exception('Session conflict detection failed');
  } on SessionConflictException catch (e) {
    print('✅ Session conflict detected correctly: ${e.message}');
    print('   Existing sessions: ${e.activeSessions.length}');
  }
  
  print('');
  print('TEST 3: Force login and session invalidation');
  print('--------------------------------------------');
  
  // Force login to invalidate existing sessions
  try {
    await AuthService.loginWithSessionManagement(username, password, forceLogoutExisting: true);
    print('✅ Force login successful');
    
    // Verify old sessions were invalidated
    final activeSessions = await _getActiveSessions(username);
    if (activeSessions.length == 1) {
      print('✅ Old sessions invalidated, only 1 active session remains');
    } else {
      print('❌ Session cleanup failed: ${activeSessions.length} sessions still active');
      throw Exception('Session cleanup test failed');
    }
  } catch (e) {
    print('❌ Force login failed: $e');
    throw Exception('Force login test failed');
  }
  
  print('');
  print('TEST 4: Multiple device simulation');
  print('----------------------------------');
  
  // Simulate multiple devices trying to login
  for (int device = 1; device <= 3; device++) {
    print('Device $device attempting login...');
    
    try {
      if (device == 1) {
        // First device should succeed
        await AuthService.loginWithSessionManagement(username, password);
        print('✅ Device $device login successful');
      } else {
        // Subsequent devices should detect conflict and force login
        try {
          await AuthService.loginWithSessionManagement(username, password);
          print('❌ Device $device should have detected session conflict');
          throw Exception('Multi-device test failed');
        } on SessionConflictException {
          // Force login for subsequent devices
          await AuthService.loginWithSessionManagement(username, password, forceLogoutExisting: true);
          print('✅ Device $device force login successful');
        }
      }
      
      // Verify only one session is active
      final activeSessions = await _getActiveSessions(username);
      if (activeSessions.length == 1) {
        print('✅ Only 1 active session for device $device');
      } else {
        print('❌ Multiple sessions detected: ${activeSessions.length}');
        throw Exception('Multi-device session isolation failed');
      }
    } catch (e) {
      print('❌ Device $device test failed: $e');
      throw Exception('Multi-device test failed');
    }
  }
  
  print('');
  print('TEST 5: Session data verification');
  print('---------------------------------');
  
  final activeSessions = await _getActiveSessions(username);
  if (activeSessions.isNotEmpty) {
    final session = activeSessions.first;
    print('✅ Active session found:');
    print('   Session ID: ${session['session_id']}');
    print('   Device ID: ${session['device_id']}');
    print('   Created: ${session['created_at']}');
    print('   Last Activity: ${session['last_activity']}');
  } else {
    print('❌ No active session found');
    throw Exception('Session data verification failed');
  }
  
  print('');
  print('TEST 6: Session cleanup');
  print('----------------------');
  
  // Test session logout
  await AuthService.logout();
  
  final remainingSessions = await _getActiveSessions(username);
  if (remainingSessions.isEmpty) {
    print('✅ All sessions cleaned up after logout');
  } else {
    print('❌ Sessions not cleaned up: ${remainingSessions.length} remaining');
    throw Exception('Session cleanup test failed');
  }
}

Future<void> _clearExistingSessions(String username) async {
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;
  
  // Clear any existing sessions for the test user
  await db.delete(
    'user_sessions',
    where: 'username = ?',
    whereArgs: [username],
  );
  
  print('🧹 Cleared existing sessions for $username');
}

Future<List<Map<String, dynamic>>> _getActiveSessions(String username) async {
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;
  
  // Get active sessions for the user
  final sessions = await db.query(
    'user_sessions',
    where: 'username = ? AND expires_at > ?',
    whereArgs: [username, DateTime.now().toIso8601String()],
  );
  
  return sessions;
}
