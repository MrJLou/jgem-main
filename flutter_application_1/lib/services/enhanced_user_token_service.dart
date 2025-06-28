import 'dart:math';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

/// Enhanced Token-based Authentication Service
/// 
/// This service ensures only one device can be logged in per user account at a time.
/// Key features:
/// - Secure token generation and validation
/// - Automatic session expiration
/// - Force logout capability for other devices
/// - Device-specific session tracking
/// - Real-time session monitoring
class EnhancedUserTokenService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _currentSessionTokenKey = 'current_session_token';
  static const String _currentUsernameKey = 'current_username';
  static const Duration _defaultSessionDuration = Duration(hours: 8);
  
  /// Generate a cryptographically secure session token
  static String _generateSecureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = bytes + utf8.encode(timestamp);
    return sha256.convert(combined).toString();
  }

  /// Generate a unique device identifier
  static String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Create a new user session and invalidate any existing sessions
  /// 
  /// [username] - Username of the user logging in
  /// [deviceName] - Human-readable device name (optional)
  /// [forceLogout] - Whether to force logout existing sessions
  /// 
  /// Returns the session token if successful, throws exception if conflict
  static Future<String> createUserSession({
    required String username,
    String? deviceName,
    bool forceLogout = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final deviceId = await _getOrCreateDeviceId();
      
      // Check for existing active sessions
      final existingSessions = await getActiveUserSessions(username);
      
      if (existingSessions.isNotEmpty && !forceLogout) {
        throw UserSessionConflictException(
          'User is already logged in on another device',
          existingSessions,
        );
      }
      
      // If forcing logout, invalidate all existing sessions
      if (forceLogout && existingSessions.isNotEmpty) {
        await invalidateAllUserSessions(username);
        debugPrint('ENHANCED_TOKEN_SERVICE: Force logged out existing sessions for $username');
      }
      
      // Generate new session token
      final sessionToken = _generateSecureToken();
      final sessionId = const Uuid().v4();
      final now = DateTime.now();
      final expiresAt = now.add(_defaultSessionDuration);
      
      // Insert new session record
      await db.insert(
        DatabaseHelper.tableUserSessions,
        {
          'id': sessionId,
          'session_id': sessionId,
          'userId': await _getUserId(username) ?? 'unknown',
          'username': username,
          'deviceId': deviceId,
          'deviceName': deviceName ?? await _getDeviceName(),
          'loginTime': now.toIso8601String(),
          'lastActivity': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'invalidated_at': null,
          'ipAddress': await _getLocalIpAddress(),
          'isActive': 1,
          'sessionToken': sessionToken,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Store current session info locally
      await _storeCurrentSessionInfo(sessionToken, username);
      
      // Log the change for sync
      await _dbHelper.logChange(DatabaseHelper.tableUserSessions, sessionId, 'insert');
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Created new session for user: $username on device: $deviceId');
      
      return sessionToken;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error creating session: $e');
      rethrow;
    }
  }

  /// Validate if a session token is active and valid
  /// 
  /// [username] - Username to validate against
  /// [sessionToken] - Session token to validate
  /// 
  /// Returns true if session is valid and active
  static Future<bool> validateSessionToken(String username, String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      final result = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'username = ? AND sessionToken = ? AND isActive = 1',
        whereArgs: [username, sessionToken],
      );

      if (result.isEmpty) {
        debugPrint('ENHANCED_TOKEN_SERVICE: No active session found for user: $username');
        return false;
      }

      final session = result.first;
      final expiryTime = DateTime.parse(session['expiresAt'] as String);
      
      // Check if session has expired
      if (DateTime.now().isAfter(expiryTime)) {
        debugPrint('ENHANCED_TOKEN_SERVICE: Session expired for user: $username');
        await invalidateSession(sessionToken);
        return false;
      }

      // Update last activity if session is still valid
      await _updateLastActivity(sessionToken);
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Valid session confirmed for user: $username');
      return true;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error validating session: $e');
      return false;
    }
  }

  /// Check if user has any active sessions
  /// 
  /// [username] - Username to check
  /// 
  /// Returns true if user has at least one active session
  static Future<bool> hasActiveSession(String username) async {
    try {
      final activeSessions = await getActiveUserSessions(username);
      return activeSessions.isNotEmpty;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error checking active session: $e');
      return false;
    }
  }

  /// Get all active sessions for a user
  /// 
  /// [username] - Username to query sessions for
  /// [excludeCurrentDevice] - Whether to exclude current device from results
  /// 
  /// Returns list of active session records
  static Future<List<Map<String, dynamic>>> getActiveUserSessions(
    String username, {
    bool excludeCurrentDevice = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      String whereClause = 'username = ? AND isActive = 1 AND expiresAt > ?';
      List<dynamic> whereArgs = [username, now];
      
      if (excludeCurrentDevice) {
        final deviceId = await _getOrCreateDeviceId();
        whereClause += ' AND deviceId != ?';
        whereArgs.add(deviceId);
      }
      
      final result = await db.query(
        DatabaseHelper.tableUserSessions,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      // Filter out actually expired sessions (database might have stale data)
      final validSessions = <Map<String, dynamic>>[];
      for (final session in result) {
        final expiryTime = DateTime.parse(session['expiresAt'] as String);
        if (DateTime.now().isBefore(expiryTime)) {
          validSessions.add(session);
        } else {
          // Clean up expired session
          await invalidateSession(session['sessionToken'] as String);
        }
      }
      
      return validSessions;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting active sessions: $e');
      return [];
    }
  }

  /// Get current device's session details
  /// 
  /// [username] - Username to query for
  /// 
  /// Returns session details if found
  static Future<Map<String, dynamic>?> getCurrentDeviceSession(String username) async {
    try {
      final db = await _dbHelper.database;
      final deviceId = await _getOrCreateDeviceId();
      final now = DateTime.now().toIso8601String();
      
      final result = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'username = ? AND deviceId = ? AND isActive = 1 AND expiresAt > ?',
        whereArgs: [username, deviceId, now],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting current device session: $e');
      return null;
    }
  }

  /// Invalidate all sessions for a specific user
  /// 
  /// [username] - Username whose sessions to invalidate
  /// [excludeCurrentDevice] - Whether to keep current device session active
  static Future<void> invalidateAllUserSessions(
    String username, {
    bool excludeCurrentDevice = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      String whereClause = 'username = ? AND isActive = 1';
      List<dynamic> whereArgs = [username];
      
      if (excludeCurrentDevice) {
        final deviceId = await _getOrCreateDeviceId();
        whereClause += ' AND deviceId != ?';
        whereArgs.add(deviceId);
      }
      
      await db.update(
        DatabaseHelper.tableUserSessions,
        {
          'isActive': 0,
          'invalidated_at': now,
        },
        where: whereClause,
        whereArgs: whereArgs,
      );

      // Clear local session info if invalidating all sessions
      if (!excludeCurrentDevice) {
        await _clearCurrentSessionInfo();
      }

      await _dbHelper.logChange(DatabaseHelper.tableUserSessions, username, 'update');
      debugPrint('ENHANCED_TOKEN_SERVICE: Invalidated sessions for user: $username');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error invalidating user sessions: $e');
      rethrow;
    }
  }

  /// Invalidate a specific session token
  /// 
  /// [sessionToken] - Session token to invalidate
  static Future<void> invalidateSession(String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        DatabaseHelper.tableUserSessions,
        {
          'isActive': 0,
          'invalidated_at': DateTime.now().toIso8601String(),
        },
        where: 'sessionToken = ?',
        whereArgs: [sessionToken],
      );

      // Clear local session info if this was our session
      final currentToken = await _getCurrentSessionToken();
      if (currentToken == sessionToken) {
        await _clearCurrentSessionInfo();
      }

      await _dbHelper.logChange(DatabaseHelper.tableUserSessions, sessionToken, 'update');
      debugPrint('ENHANCED_TOKEN_SERVICE: Invalidated session token');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error invalidating session: $e');
      rethrow;
    }
  }

  /// Extend session expiry time
  /// 
  /// [sessionToken] - Session token to extend
  /// [duration] - Duration to extend by (default: 8 hours)
  /// 
  /// Returns true if session was extended successfully
  static Future<bool> extendSession(
    String sessionToken, {
    Duration? duration,
  }) async {
    try {
      final db = await _dbHelper.database;
      
      final newExpiryTime = DateTime.now()
          .add(duration ?? _defaultSessionDuration)
          .toIso8601String();
      
      final result = await db.update(
        DatabaseHelper.tableUserSessions,
        {
          'expiresAt': newExpiryTime,
          'expires_at': newExpiryTime,
          'lastActivity': DateTime.now().toIso8601String(),
        },
        where: 'sessionToken = ? AND isActive = 1',
        whereArgs: [sessionToken],
      );

      debugPrint('ENHANCED_TOKEN_SERVICE: Extended session expiry');
      return result > 0;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error extending session: $e');
      return false;
    }
  }

  /// Cleanup expired sessions across all users
  static Future<void> cleanupExpiredSessions() async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      await db.update(
        DatabaseHelper.tableUserSessions,
        {
          'isActive': 0,
          'invalidated_at': now,
        },
        where: 'expiresAt < ? AND isActive = 1',
        whereArgs: [now],
      );

      debugPrint('ENHANCED_TOKEN_SERVICE: Cleaned up expired sessions');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error cleaning up expired sessions: $e');
    }
  }

  /// Check if current stored session is valid
  static Future<bool> isCurrentSessionValid() async {
    try {
      final token = await _getCurrentSessionToken();
      final username = await _getCurrentUsername();
      
      if (token == null || username == null) {
        return false;
      }
      
      return await validateSessionToken(username, token);
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error checking current session: $e');
      return false;
    }
  }

  /// Get session statistics for monitoring
  static Future<Map<String, dynamic>> getSessionStatistics() async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      final activeSessionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableUserSessions} WHERE isActive = 1 AND expiresAt > ?',
        [now],
      );
      
      final totalSessionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableUserSessions}',
      );
      
      final uniqueUsersResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT username) as count FROM ${DatabaseHelper.tableUserSessions} WHERE isActive = 1 AND expiresAt > ?',
        [now],
      );

      final expiredSessionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableUserSessions} WHERE expiresAt <= ? OR isActive = 0',
        [now],
      );

      return {
        'activeSessions': activeSessionsResult.first['count'] ?? 0,
        'totalSessions': totalSessionsResult.first['count'] ?? 0,
        'activeUsers': uniqueUsersResult.first['count'] ?? 0,
        'expiredSessions': expiredSessionsResult.first['count'] ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting session statistics: $e');
      return {
        'activeSessions': 0,
        'totalSessions': 0,
        'activeUsers': 0,
        'expiredSessions': 0,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Update last activity timestamp for a session
  static Future<void> _updateLastActivity(String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        DatabaseHelper.tableUserSessions,
        {'lastActivity': DateTime.now().toIso8601String()},
        where: 'sessionToken = ? AND isActive = 1',
        whereArgs: [sessionToken],
      );
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error updating last activity: $e');
    }
  }

  /// Get or create device ID
  static Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = _generateDeviceId();
        await prefs.setString('device_id', deviceId);
      }
      
      return deviceId;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting device ID: $e');
      return _generateDeviceId();
    }
  }

  /// Get user ID from username
  static Future<String?> _getUserId(String username) async {
    try {
      final user = await _dbHelper.getUserByUsername(username);
      return user?.id;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting user ID: $e');
      return null;
    }
  }

  /// Get device name
  static Future<String> _getDeviceName() async {
    try {
      if (!kIsWeb) {
        if (Platform.isWindows) {
          return 'Windows Device';
        } else if (Platform.isAndroid) {
          return 'Android Device';
        } else if (Platform.isIOS) {
          return 'iOS Device';
        } else if (Platform.isMacOS) {
          return 'macOS Device';
        } else if (Platform.isLinux) {
          return 'Linux Device';
        }
      }
      return 'Web Browser';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Get local IP address
  static Future<String?> _getLocalIpAddress() async {
    try {
      // This is a simplified implementation
      // In a real app, you might want to use a more sophisticated method
      return '127.0.0.1';
    } catch (e) {
      return null;
    }
  }

  /// Store current session info locally
  static Future<void> _storeCurrentSessionInfo(String sessionToken, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentSessionTokenKey, sessionToken);
      await prefs.setString(_currentUsernameKey, username);
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error storing session info: $e');
    }
  }

  /// Get current session token
  static Future<String?> _getCurrentSessionToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSessionTokenKey);
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting session token: $e');
      return null;
    }
  }

  /// Get current username
  static Future<String?> _getCurrentUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentUsernameKey);
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error getting username: $e');
      return null;
    }
  }

  /// Clear current session info
  static Future<void> _clearCurrentSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentSessionTokenKey);
      await prefs.remove(_currentUsernameKey);
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error clearing session info: $e');
    }
  }
}

/// Exception thrown when there's a session conflict (user already logged in)
class UserSessionConflictException implements Exception {
  final String message;
  final List<Map<String, dynamic>> activeSessions;
  
  UserSessionConflictException(this.message, this.activeSessions);
  
  @override
  String toString() => 'UserSessionConflictException: $message';
}
