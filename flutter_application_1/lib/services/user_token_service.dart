import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'auth_service.dart';

/// Service to manage user session tokens for single-device authentication
/// Ensures only one device can be logged in per user account at a time
class UserTokenService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();
  
  /// Generate a secure random token for user session
  static String _generateSecureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return sha256.convert(bytes).toString();
  }

  /// Create a new user session token and invalidate any existing ones
  static Future<String> createUserSession(String username, String deviceId) async {
    try {
      final db = await _dbHelper.database;
      
      // First, invalidate any existing sessions for this user
      await invalidateUserSessions(username);
      
      // Generate new secure token
      final sessionToken = _generateSecureToken();
      final currentTime = DateTime.now().toIso8601String();
      final expiryTime = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
      
      // Insert new session
      await db.insert(
        'user_sessions',
        {
          'session_id': const Uuid().v4(),
          'username': username,
          'device_id': deviceId,
          'session_token': sessionToken,
          'created_at': currentTime,
          'last_activity': currentTime,
          'expires_at': expiryTime,
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('USER_TOKEN_SERVICE: Created new session for user: $username');
      return sessionToken;
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error creating session: $e');
      rethrow;
    }
  }

  /// Validate if a session token is active and valid
  static Future<bool> validateSessionToken(String username, String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      final result = await db.query(
        'user_sessions',
        where: 'username = ? AND session_token = ? AND is_active = 1',
        whereArgs: [username, sessionToken],
      );

      if (result.isEmpty) {
        debugPrint('USER_TOKEN_SERVICE: No active session found for user: $username');
        return false;
      }

      final session = result.first;
      final expiryTime = DateTime.parse(session['expires_at'] as String);
      
      // Check if session has expired
      if (DateTime.now().isAfter(expiryTime)) {
        debugPrint('USER_TOKEN_SERVICE: Session expired for user: $username');
        await invalidateSession(sessionToken);
        return false;
      }

      // Update last activity
      await _updateLastActivity(sessionToken);
      
      debugPrint('USER_TOKEN_SERVICE: Valid session found for user: $username');
      return true;
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error validating session: $e');
      return false;
    }
  }

  /// Check if user has an active session (used before login attempt)
  static Future<bool> hasActiveSession(String username) async {
    try {
      final db = await _dbHelper.database;
      
      final result = await db.query(
        'user_sessions',
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
      );

      if (result.isEmpty) {
        return false;
      }

      // Check if any active sessions are still valid
      for (final session in result) {
        final expiryTime = DateTime.parse(session['expires_at'] as String);
        if (DateTime.now().isBefore(expiryTime)) {
          return true; // Found at least one valid session
        }
      }

      // All sessions expired, clean them up
      await _cleanupExpiredSessions(username);
      return false;
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error checking active session: $e');
      return false;
    }
  }

  /// Get active session details for a user
  static Future<Map<String, dynamic>?> getActiveSessionDetails(String username) async {
    try {
      final db = await _dbHelper.database;
      
      final result = await db.query(
        'user_sessions',
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        final session = result.first;
        final expiryTime = DateTime.parse(session['expires_at'] as String);
        
        if (DateTime.now().isBefore(expiryTime)) {
          return session;
        } else {
          // Session expired, invalidate it
          await invalidateSession(session['session_token'] as String);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error getting session details: $e');
      return null;
    }
  }

  /// Invalidate all sessions for a specific user
  static Future<void> invalidateUserSessions(String username) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        'user_sessions',
        {'is_active': 0, 'invalidated_at': DateTime.now().toIso8601String()},
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
      );

      debugPrint('USER_TOKEN_SERVICE: Invalidated all sessions for user: $username');
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error invalidating user sessions: $e');
      rethrow;
    }
  }

  /// Invalidate a specific session token
  static Future<void> invalidateSession(String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        'user_sessions',
        {'is_active': 0, 'invalidated_at': DateTime.now().toIso8601String()},
        where: 'session_token = ?',
        whereArgs: [sessionToken],
      );

      debugPrint('USER_TOKEN_SERVICE: Invalidated session token');
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error invalidating session: $e');
      rethrow;
    }
  }

  /// Update last activity timestamp for a session
  static Future<void> _updateLastActivity(String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        'user_sessions',
        {'last_activity': DateTime.now().toIso8601String()},
        where: 'session_token = ? AND is_active = 1',
        whereArgs: [sessionToken],
      );
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error updating last activity: $e');
    }
  }

  /// Clean up expired sessions for a user
  static Future<void> _cleanupExpiredSessions(String username) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        'user_sessions',
        {'is_active': 0, 'invalidated_at': DateTime.now().toIso8601String()},
        where: 'username = ? AND expires_at < ?',
        whereArgs: [username, DateTime.now().toIso8601String()],
      );

      debugPrint('USER_TOKEN_SERVICE: Cleaned up expired sessions for user: $username');
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error cleaning up expired sessions: $e');
    }
  }

  /// Clean up all expired sessions in the database
  static Future<void> cleanupAllExpiredSessions() async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        'user_sessions',
        {'is_active': 0, 'invalidated_at': DateTime.now().toIso8601String()},
        where: 'expires_at < ? AND is_active = 1',
        whereArgs: [DateTime.now().toIso8601String()],
      );

      debugPrint('USER_TOKEN_SERVICE: Cleaned up all expired sessions');
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error cleaning up all expired sessions: $e');
    }
  }

  /// Get current session token for a logged-in user
  static Future<String?> getCurrentSessionToken(String username) async {
    try {
      final sessionDetails = await getActiveSessionDetails(username);
      return sessionDetails?['session_token'] as String?;
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error getting current session token: $e');
      return null;
    }
  }

  /// Extend session expiry time (useful for active users)
  static Future<bool> extendSession(String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      final newExpiryTime = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
      
      final result = await db.update(
        'user_sessions',
        {
          'expires_at': newExpiryTime,
          'last_activity': DateTime.now().toIso8601String(),
        },
        where: 'session_token = ? AND is_active = 1',
        whereArgs: [sessionToken],
      );

      debugPrint('USER_TOKEN_SERVICE: Extended session expiry');
      return result > 0;
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error extending session: $e');
      return false;
    }
  }

  /// Force logout user by invalidating their session
  static Future<void> forceLogoutUser(String username) async {
    try {
      await invalidateUserSessions(username);
      
      // Also clear any local auth credentials
      await AuthService.clearCredentials();
      
      debugPrint('USER_TOKEN_SERVICE: Force logged out user: $username');
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error force logging out user: $e');
      rethrow;
    }
  }

  /// Get session statistics for monitoring
  static Future<Map<String, dynamic>> getSessionStatistics() async {
    try {
      final db = await _dbHelper.database;
      
      final activeSessionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_sessions WHERE is_active = 1 AND expires_at > ?',
        [DateTime.now().toIso8601String()],
      );
      
      final totalSessionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_sessions',
      );
      
      final uniqueUsersResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT username) as count FROM user_sessions WHERE is_active = 1 AND expires_at > ?',
        [DateTime.now().toIso8601String()],
      );

      return {
        'activeSessions': activeSessionsResult.first['count'] ?? 0,
        'totalSessions': totalSessionsResult.first['count'] ?? 0,
        'activeUsers': uniqueUsersResult.first['count'] ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('USER_TOKEN_SERVICE: Error getting session statistics: $e');
      return {
        'activeSessions': 0,
        'totalSessions': 0,
        'activeUsers': 0,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
