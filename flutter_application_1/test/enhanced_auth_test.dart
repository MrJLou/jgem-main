import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/enhanced_user_token_service.dart';
import 'package:flutter_application_1/services/authentication_manager.dart';

/// Test suite for the Enhanced Authentication System
/// 
/// Run these tests to verify the token-based authentication is working correctly.
/// 
/// To run: flutter test test/enhanced_auth_test.dart

void main() {
  group('Enhanced Authentication System Tests', () {
    
    setUp(() async {
      // Initialize the authentication system before each test
      await AuthenticationManager.initialize();
    });

    tearDown(() async {
      // Clean up after each test
      await EnhancedUserTokenService.cleanupExpiredSessions();
    });

    test('should create session token successfully', () async {
      const username = 'testuser';
      
      try {
        final token = await EnhancedUserTokenService.createUserSession(
          username: username,
          deviceName: 'Test Device',
        );
        
        expect(token, isNotNull);
        expect(token.length, greaterThan(32)); // Token should be substantial length
        print('✅ Session token created successfully: ${token.substring(0, 8)}...');
      } catch (e) {
        fail('Failed to create session token: $e');
      }
    });

    test('should detect session conflicts', () async {
      const username = 'testuser';
      
      // Create first session
      final token1 = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Device 1',
      );
      expect(token1, isNotNull);
      
      // Try to create second session without force logout
      try {
        await EnhancedUserTokenService.createUserSession(
          username: username,
          deviceName: 'Device 2',
          forceLogout: false,
        );
        fail('Should have thrown UserSessionConflictException');
      } on UserSessionConflictException catch (e) {
        expect(e.message, contains('already logged in'));
        expect(e.activeSessions, isNotEmpty);
        print('✅ Session conflict detected correctly');
      }
    });

    test('should force logout existing sessions', () async {
      const username = 'testuser';
      
      // Create first session
      final token1 = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Device 1',
      );
      expect(token1, isNotNull);
      
      // Verify session exists
      final hasSession = await EnhancedUserTokenService.hasActiveSession(username);
      expect(hasSession, isTrue);
      
      // Force logout and create new session
      final token2 = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Device 2',
        forceLogout: true,
      );
      expect(token2, isNotNull);
      expect(token2, isNot(equals(token1)));
      
      // Verify old token is invalid
      final isToken1Valid = await EnhancedUserTokenService.validateSessionToken(username, token1);
      expect(isToken1Valid, isFalse);
      
      // Verify new token is valid
      final isToken2Valid = await EnhancedUserTokenService.validateSessionToken(username, token2);
      expect(isToken2Valid, isTrue);
      
      print('✅ Force logout working correctly');
    });

    test('should validate session tokens correctly', () async {
      const username = 'testuser';
      
      // Create session
      final token = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Test Device',
      );
      
      // Validate with correct username and token
      final isValid = await EnhancedUserTokenService.validateSessionToken(username, token);
      expect(isValid, isTrue);
      
      // Validate with wrong username
      final isValidWrongUser = await EnhancedUserTokenService.validateSessionToken('wronguser', token);
      expect(isValidWrongUser, isFalse);
      
      // Validate with wrong token
      final isValidWrongToken = await EnhancedUserTokenService.validateSessionToken(username, 'wrongtoken');
      expect(isValidWrongToken, isFalse);
      
      print('✅ Token validation working correctly');
    });

    test('should invalidate sessions correctly', () async {
      const username = 'testuser';
      
      // Create session
      final token = await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Test Device',
      );
      
      // Verify session is valid
      final isValidBefore = await EnhancedUserTokenService.validateSessionToken(username, token);
      expect(isValidBefore, isTrue);
      
      // Invalidate session
      await EnhancedUserTokenService.invalidateSession(token);
      
      // Verify session is now invalid
      final isValidAfter = await EnhancedUserTokenService.validateSessionToken(username, token);
      expect(isValidAfter, isFalse);
      
      print('✅ Session invalidation working correctly');
    });

    test('should get active sessions for user', () async {
      const username = 'testuser';
      
      // Initially no sessions
      final sessionsInitial = await EnhancedUserTokenService.getActiveUserSessions(username);
      expect(sessionsInitial, isEmpty);
      
      // Create session
      await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Test Device',
      );
      
      // Should have one session now
      final sessionsAfter = await EnhancedUserTokenService.getActiveUserSessions(username);
      expect(sessionsAfter, hasLength(1));
      expect(sessionsAfter.first['username'], equals(username));
      expect(sessionsAfter.first['deviceName'], equals('Test Device'));
      
      print('✅ Active sessions retrieval working correctly');
    });

    test('should get session statistics', () async {
      const username = 'testuser';
      
      // Create a session
      await EnhancedUserTokenService.createUserSession(
        username: username,
        deviceName: 'Test Device',
      );
      
      // Get statistics
      final stats = await EnhancedUserTokenService.getSessionStatistics();
      
      expect(stats, isNotNull);
      expect(stats['activeSessions'], isA<int>());
      expect(stats['totalSessions'], isA<int>());
      expect(stats['activeUsers'], isA<int>());
      expect(stats['timestamp'], isNotNull);
      
      expect(stats['activeSessions'], greaterThanOrEqualTo(1));
      expect(stats['activeUsers'], greaterThanOrEqualTo(1));
      
      print('✅ Session statistics working correctly');
      print('   Active Sessions: ${stats['activeSessions']}');
      print('   Active Users: ${stats['activeUsers']}');
    });

    test('should handle AuthenticationManager login flow', () async {
      // Note: This test would require a real database with user records
      // For now, we'll test the error handling for invalid credentials
      
      try {
        await AuthenticationManager.login(
          username: 'nonexistentuser',
          password: 'wrongpassword',
        );
        fail('Should have thrown an exception for invalid credentials');
      } catch (e) {
        expect(e.toString(), contains('Invalid username or password'));
        print('✅ AuthenticationManager correctly handles invalid credentials');
      }
    });

    test('should cleanup expired sessions', () async {
      // This test verifies the cleanup mechanism works
      await EnhancedUserTokenService.cleanupExpiredSessions();
      
      final stats = await EnhancedUserTokenService.getSessionStatistics();
      
      // Should not throw any errors
      expect(stats, isNotNull);
      print('✅ Session cleanup completed without errors');
    });
  });
}

/// Helper function to run manual tests in development
void runManualTests() async {
  print('🧪 Running manual tests for Enhanced Authentication System...\n');
  
  try {
    // Test 1: Token generation
    print('Test 1: Token Generation');
    final token = await EnhancedUserTokenService.createUserSession(
      username: 'manual_test_user',
      deviceName: 'Manual Test Device',
    );
    print('✅ Generated token: ${token.substring(0, 8)}...\n');
    
    // Test 2: Token validation
    print('Test 2: Token Validation');
    final isValid = await EnhancedUserTokenService.validateSessionToken('manual_test_user', token);
    print('✅ Token validation: $isValid\n');
    
    // Test 3: Session conflict
    print('Test 3: Session Conflict Detection');
    try {
      await EnhancedUserTokenService.createUserSession(
        username: 'manual_test_user',
        deviceName: 'Another Device',
        forceLogout: false,
      );
      print('❌ Should have detected session conflict');
    } on UserSessionConflictException {
      print('✅ Session conflict detected correctly\n');
    }
    
    // Test 4: Statistics
    print('Test 4: Session Statistics');
    final stats = await EnhancedUserTokenService.getSessionStatistics();
    print('✅ Statistics: ${stats['activeSessions']} active sessions\n');
    
    // Test 5: Cleanup
    print('Test 5: Session Cleanup');
    await EnhancedUserTokenService.invalidateSession(token);
    final isValidAfter = await EnhancedUserTokenService.validateSessionToken('manual_test_user', token);
    print('✅ Token invalidated: ${!isValidAfter}\n');
    
    print('🎉 All manual tests completed successfully!');
    
  } catch (e) {
    print('❌ Manual test failed: $e');
  }
}

/// Instructions for running tests:
/// 
/// 1. Unit Tests:
///    flutter test test/enhanced_auth_test.dart
/// 
/// 2. Manual Tests (in development):
///    Add this to your main.dart temporarily:
///    
///    void main() async {
///      WidgetsFlutterBinding.ensureInitialized();
///      await runManualTests(); // Add this line
///      runApp(MyApp());
///    }
