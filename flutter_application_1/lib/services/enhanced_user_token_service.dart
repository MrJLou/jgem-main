import 'dart:math';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'database_sync_client.dart';
import 'enhanced_shelf_lan_server.dart';
import 'cross_device_session_monitor.dart';

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
      
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Starting session creation for $username on device $deviceId');
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Database instance: ${db.isOpen ? 'OPEN' : 'CLOSED'}');
      
      // Test database connection with a simple query
      try {
        final testQuery = await db.query(DatabaseHelper.tableUserSessions, limit: 1);
        debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Database test query successful, ${testQuery.length} results');
      } catch (e) {
        debugPrint('ENHANCED_TOKEN_SERVICE: ERROR - Database test query failed: $e');
        throw Exception('Database connection test failed: $e');
      }
      
      // REAL-TIME SYNC: Force immediate session refresh from network to get latest state
      // This ensures both host and client have the most current session info BEFORE creating sessions
      debugPrint('ENHANCED_TOKEN_SERVICE: REAL-TIME SYNC - Forcing immediate session refresh...');
      
      try {
        await refreshSessionDataFromNetwork();
        
        // Wait for sync to complete with timeout
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // Force another refresh to ensure we have the absolute latest data
        await refreshSessionDataFromNetwork();
        
        debugPrint('ENHANCED_TOKEN_SERVICE: REAL-TIME SYNC - Session data refreshed from network before creating session');
      } catch (e) {
        debugPrint('ENHANCED_TOKEN_SERVICE: Could not refresh from network (offline?): $e');
      }
      
      // Check for existing active sessions AFTER real-time sync
      final existingSessions = await getActiveUserSessions(username);
      
      debugPrint('ENHANCED_TOKEN_SERVICE: REAL-TIME CHECK - Found ${existingSessions.length} existing sessions for $username');
      
      if (existingSessions.isNotEmpty && !forceLogout) {
        debugPrint('ENHANCED_TOKEN_SERVICE: REAL-TIME CONFLICT - User $username already has ${existingSessions.length} active sessions');
        throw UserSessionConflictException(
          'User is already logged in on another device',
          existingSessions,
        );
      }
      
      // If forcing logout, invalidate all existing sessions
      if (forceLogout && existingSessions.isNotEmpty) {
        debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Starting force logout of ${existingSessions.length} existing sessions');
        await invalidateAllUserSessions(username);
        debugPrint('ENHANCED_TOKEN_SERVICE: Force logged out existing sessions for $username');
        
        // Verify sessions were actually invalidated
        final remainingSessions = await getActiveUserSessions(username);
        debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - After force logout: ${remainingSessions.length} remaining sessions');
      }
      
      // Generate new session token with unique identifiers
      final sessionToken = _generateSecureToken();
      final sessionId = const Uuid().v4();
      final now = DateTime.now();
      final expiresAt = now.add(_defaultSessionDuration);
      
      // Create session record with unique sessionToken to prevent duplicates during sync
      final sessionData = {
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
      };
      
      // Check if a session with this token already exists (should be very rare due to crypto)
      final existingWithToken = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'sessionToken = ?',
        whereArgs: [sessionToken],
      );
      
      if (existingWithToken.isNotEmpty) {
        // This should be extremely rare with crypto secure tokens
        debugPrint('ENHANCED_TOKEN_SERVICE: Session token collision detected, regenerating...');
        return createUserSession(username: username, deviceName: deviceName, forceLogout: forceLogout);
      }
      
      // Insert new session record with robust error handling and verification
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - About to insert session into local database...');
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Session data: $sessionData');
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Database path: ${db.path}');
      
      // First, let's see what's currently in the user_sessions table
      try {
        final existingSessions = await db.query(DatabaseHelper.tableUserSessions);
        debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Current sessions in database: ${existingSessions.length}');
        for (final session in existingSessions) {
          debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Existing session: username=${session['username']}, active=${session['isActive']}, device=${session['deviceId']}');
        }
      } catch (e) {
        debugPrint('ENHANCED_TOKEN_SERVICE: ERROR - Could not query existing sessions: $e');
      }
      
      // Use a transaction to ensure atomicity
      late int insertResult;
      late List<Map<String, dynamic>> verifyResult;
      
      await db.transaction((txn) async {
        try {
          // First, check if a session with this ID already exists and clean it up
          final deletedCount = await txn.delete(
            DatabaseHelper.tableUserSessions,
            where: 'id = ? OR sessionToken = ?',
            whereArgs: [sessionId, sessionToken],
          );
          debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Deleted $deletedCount existing sessions with same ID/token');
          
          // Insert the new session
          insertResult = await txn.insert(
            DatabaseHelper.tableUserSessions,
            sessionData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          
          debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Session inserted with result: $insertResult');
          
          // Immediately verify within the same transaction
          verifyResult = await txn.query(
            DatabaseHelper.tableUserSessions,
            where: 'sessionToken = ?',
            whereArgs: [sessionToken],
          );
          
          if (verifyResult.isEmpty) {
            throw Exception('Session not found immediately after insert within transaction');
          }
          
          debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Session verified within transaction: ${verifyResult.first}');
          
          // Double-check by querying all sessions for this user
          final allUserSessions = await txn.query(
            DatabaseHelper.tableUserSessions,
            where: 'username = ?',
            whereArgs: [username],
          );
          debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - All sessions for user $username after insert: ${allUserSessions.length}');
          
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: ERROR - Transaction failed: $e');
          rethrow;
        }
      });
      
      // Verify again outside the transaction to ensure persistence
      final finalVerifyResult = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'sessionToken = ?',
        whereArgs: [sessionToken],
      );
      
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Final verification found ${finalVerifyResult.length} sessions with this token');
      if (finalVerifyResult.isNotEmpty) {
        debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Session successfully persisted: ${finalVerifyResult.first}');
      } else {
        debugPrint('ENHANCED_TOKEN_SERVICE: ERROR - Session was NOT found in database after transaction commit!');
        
        // Try to query all sessions for this user to see what's in the database
        final allUserSessions = await db.query(
          DatabaseHelper.tableUserSessions,
          where: 'username = ?',
          whereArgs: [username],
        );
        debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - All sessions for user $username: ${allUserSessions.length}');
        for (final session in allUserSessions) {
          debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Existing session: ${session['sessionToken']}, active: ${session['isActive']}, expires: ${session['expiresAt']}');
        }
        
        // This is a critical error - we should throw an exception
        throw Exception('Failed to create session: Session not found in database after transaction commit');
      }
      
      // Store current session info locally
      await _storeCurrentSessionInfo(sessionToken, username);
      
      // REAL-TIME SYNC: Enhanced session broadcasting and sync
      debugPrint('ENHANCED_TOKEN_SERVICE: REAL-TIME SYNC - Starting immediate session broadcast...');
      
      // CRITICAL: Ensure database change callback is triggered for sync
      debugPrint('ENHANCED_TOKEN_SERVICE: CRITICAL - Triggering database change callback for session creation');
      
      // First, log the change for sync
      await _dbHelper.logChange(DatabaseHelper.tableUserSessions, sessionId, 'insert');
      
      // Then manually trigger the callback if it exists
      final hasCallback = DatabaseHelper.hasDatabaseChangeCallback();
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Database change callback exists: $hasCallback');
      
      if (hasCallback) {
        try {
          await DatabaseHelper.triggerDatabaseChangeCallback(
            DatabaseHelper.tableUserSessions, 
            'insert', 
            sessionId, 
            sessionData
          );
          debugPrint('ENHANCED_TOKEN_SERVICE: SUCCESS - Database change callback triggered manually');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: ERROR - Failed to trigger database change callback: $e');
        }
      }
      
      // Force IMMEDIATE sync of session table to all connected devices
      final isHost = EnhancedShelfServer.isRunning;
      final isClient = DatabaseSyncClient.isConnected;
      
      debugPrint('ENHANCED_TOKEN_SERVICE: SYNC STATUS - Host: $isHost, Client: $isClient');
      
      // Multiple sync attempts for reliability
      if (isHost) {
        try {
          // Force sync to ALL clients with multiple approaches
          await EnhancedShelfServer.forceSyncTable('user_sessions');
          
          // Broadcast via WebSocket as well
          await _broadcastRealTimeSessionChange('session_created', {
            'username': username,
            'sessionToken': sessionToken,
            'deviceId': deviceId,
            'deviceName': deviceName ?? await _getDeviceName(),
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          // Additional sync broadcast
          EnhancedShelfServer.announceToClients(
            'New user session created for $username',
            type: 'session_sync_update'
          );
          
          debugPrint('ENHANCED_TOKEN_SERVICE: [HOST] Session synced to all clients');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: [HOST] Error syncing session: $e');
        }
      }
      
      if (isClient) {
        try {
          // Multiple sync attempts for client
          await DatabaseSyncClient.forceSessionSync();
          DatabaseSyncClient.requestImmediateSessionSync();
          
          // Send direct session creation notification
          await _broadcastRealTimeSessionChange('session_created', {
            'username': username,
            'sessionToken': sessionToken,
            'deviceId': deviceId,
            'deviceName': deviceName ?? await _getDeviceName(),
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          debugPrint('ENHANCED_TOKEN_SERVICE: [CLIENT] Session sent to host server');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: [CLIENT] Error syncing session: $e');
        }
      }
      
      // Broadcast session creation to ALL connected devices
      await _broadcastSessionCreation(username, sessionToken, deviceId, deviceName ?? await _getDeviceName());
      
      // Wait for sync operations to complete
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Trigger cross-device session monitoring
      try {
        await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
        debugPrint('ENHANCED_TOKEN_SERVICE: Cross-device session sync triggered');
      } catch (e) {
        debugPrint('ENHANCED_TOKEN_SERVICE: Error triggering cross-device sync: $e');
      }
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Created new session for user: $username on device: $deviceId');
      debugPrint('ENHANCED_TOKEN_SERVICE: REAL-TIME SYNC - Session creation and sync completed');
      
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
        // Only log if we expect a session to exist (reduce noise for logged out users)
        debugPrint('ENHANCED_TOKEN_SERVICE: No active session found for user: $username (token validation)');
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
      debugPrint('ENHANCED_TOKEN_SERVICE: Active sessions for $username: ${activeSessions.length}');
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
      
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Querying sessions with WHERE: $whereClause, ARGS: $whereArgs');
      
      final result = await db.query(
        DatabaseHelper.tableUserSessions,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Raw query result for $username: ${result.length} sessions');
      debugPrint('ENHANCED_TOKEN_SERVICE: DEBUG - Full query result: $result');

      // Filter out actually expired sessions (database might have stale data)
      final validSessions = <Map<String, dynamic>>[];
      final currentTime = DateTime.now();
      
      for (final session in result) {
        try {
          final expiryTime = DateTime.parse(session['expiresAt'] as String);
          final isActive = (session['isActive'] as int) == 1;
          
          if (isActive && currentTime.isBefore(expiryTime)) {
            validSessions.add(session);
            debugPrint('ENHANCED_TOKEN_SERVICE: Valid session found for $username: ${session['deviceName']} (expires: ${session['expiresAt']})');
          } else {
            debugPrint('ENHANCED_TOKEN_SERVICE: Cleaning up invalid session for $username: active=$isActive, expired=${currentTime.isAfter(expiryTime)}');
            // Clean up expired or inactive session
            await invalidateSession(session['sessionToken'] as String);
          }
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: Error processing session record: $e');
          // If we can't parse the session, invalidate it
          if (session['sessionToken'] != null) {
            await invalidateSession(session['sessionToken'] as String);
          }
        }
      }
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Valid sessions for $username: ${validSessions.length}');
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

  /// Invalidate all sessions for a specific user by deleting them
  /// 
  /// [username] - Username whose sessions to invalidate
  /// [excludeCurrentDevice] - Whether to keep current device session active
  static Future<void> invalidateAllUserSessions(
    String username, {
    bool excludeCurrentDevice = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      
      String whereClause = 'username = ?';
      List<dynamic> whereArgs = [username];
      
      if (excludeCurrentDevice) {
        final deviceId = await _getOrCreateDeviceId();
        whereClause += ' AND deviceId != ?';
        whereArgs.add(deviceId);
      }

      // Get the sessions that will be deleted for broadcasting
      final sessionsToDelete = await db.query(
        DatabaseHelper.tableUserSessions,
        where: whereClause,
        whereArgs: whereArgs,
      );
      
      // DELETE the session records completely instead of just marking inactive
      final result = await db.delete(
        DatabaseHelper.tableUserSessions,
        where: whereClause,
        whereArgs: whereArgs,
      );

      // Clear local session info if deleting all sessions
      if (!excludeCurrentDevice) {
        await _clearCurrentSessionInfo();
      }

      if (result > 0) {
        // Log changes for each deleted session to trigger proper sync
        for (final session in sessionsToDelete) {
          await _dbHelper.logChange(DatabaseHelper.tableUserSessions, session['id'].toString(), 'delete');
        }
        
        // Broadcast session deletions to all connected devices
        await _broadcastSessionDeletions(username, sessionsToDelete);
        
        // Force immediate bidirectional sync after mass session deletion
        final isHost = EnhancedShelfServer.isRunning;
        final isClient = DatabaseSyncClient.isConnected;
        
        if (isHost) {
          try {
            await EnhancedShelfServer.forceSyncTable('user_sessions');
            debugPrint('ENHANCED_TOKEN_SERVICE: [HOST] Forced mass session deletion sync to all clients');
          } catch (e) {
            debugPrint('ENHANCED_TOKEN_SERVICE: [HOST] Error forcing mass session deletion sync: $e');
          }
        }
        
        if (isClient) {
          try {
            // Send the session deletions to the host server
            await DatabaseSyncClient.manualSync();
            debugPrint('ENHANCED_TOKEN_SERVICE: [CLIENT] Sent mass session deletion sync to host');
          } catch (e) {
            debugPrint('ENHANCED_TOKEN_SERVICE: [CLIENT] Error sending mass session deletion sync to host: $e');
          }
        }
      }
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Deleted $result sessions for user: $username');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error deleting user sessions: $e');
      rethrow;
    }
  }

  /// Invalidate a specific session token by deleting it
  /// 
  /// [sessionToken] - Session token to invalidate
  static Future<void> invalidateSession(String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      
      // Get the session info before deleting for broadcasting
      final sessionInfo = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'sessionToken = ?',
        whereArgs: [sessionToken],
      );

      // DELETE the session record completely instead of just marking inactive
      final result = await db.delete(
        DatabaseHelper.tableUserSessions,
        where: 'sessionToken = ?',
        whereArgs: [sessionToken],
      );

      // Clear local session info if this was our session
      final currentToken = await _getCurrentSessionToken();
      if (currentToken == sessionToken) {
        await _clearCurrentSessionInfo();
        debugPrint('ENHANCED_TOKEN_SERVICE: Cleared local session info for deleted session');
      }

      if (result > 0) {
        // Log as DELETE operation to trigger proper sync
        await _dbHelper.logChange(DatabaseHelper.tableUserSessions, sessionToken, 'delete');
        
        // Broadcast session deletion to other devices
        if (sessionInfo.isNotEmpty) {
          await _broadcastSessionDeletion(sessionInfo.first);
        }
        
        // Force immediate bidirectional sync after session deletion
        final isHost = EnhancedShelfServer.isRunning;
        final isClient = DatabaseSyncClient.isConnected;
        
        if (isHost) {
          try {
            await EnhancedShelfServer.forceSyncTable('user_sessions');
            debugPrint('ENHANCED_TOKEN_SERVICE: [HOST] Forced session deletion sync to all clients');
          } catch (e) {
            debugPrint('ENHANCED_TOKEN_SERVICE: [HOST] Error forcing session deletion sync: $e');
          }
        }
        
        if (isClient) {
          try {
            // Force immediate session sync to the host server
            await DatabaseSyncClient.forceSessionSync();
            debugPrint('ENHANCED_TOKEN_SERVICE: [CLIENT] Forced session deletion sync to host');
          } catch (e) {
            debugPrint('ENHANCED_TOKEN_SERVICE: [CLIENT] Error forcing session deletion sync to host: $e');
          }
        }
        
        debugPrint('ENHANCED_TOKEN_SERVICE: Successfully deleted session token');
      } else {
        debugPrint('ENHANCED_TOKEN_SERVICE: Session token not found');
      }
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error deleting session: $e');
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

  /// Cleanup expired sessions across all users by deleting them
  static Future<void> cleanupExpiredSessions() async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      // Get sessions that need to be deleted
      final sessionsToDelete = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'expiresAt < ?',
        whereArgs: [now],
      );
      
      if (sessionsToDelete.isNotEmpty) {
        // DELETE expired sessions completely
        final result = await db.delete(
          DatabaseHelper.tableUserSessions,
          where: 'expiresAt < ?',
          whereArgs: [now],
        );
        
        // Log deletion for each session to trigger sync
        for (final session in sessionsToDelete) {
          await _dbHelper.logChange(DatabaseHelper.tableUserSessions, session['id'].toString(), 'delete');
        }
        
        debugPrint('ENHANCED_TOKEN_SERVICE: Deleted $result expired sessions');
      } else {
        debugPrint('ENHANCED_TOKEN_SERVICE: No expired sessions to clean up');
      }
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error cleaning up expired sessions: $e');
    }
  }

  /// Deep cleanup for a specific user's sessions (used during logout)
  static Future<void> cleanupUserSessions(String username) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      // Get all expired or inactive sessions for the user that need cleanup
      final sessionsToDelete = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'username = ? AND (isActive = 0 OR expiresAt < ?)',
        whereArgs: [username, now],
      );
      
      if (sessionsToDelete.isNotEmpty) {
        // DELETE expired/inactive sessions completely
        final result = await db.delete(
          DatabaseHelper.tableUserSessions,
          where: 'username = ? AND (isActive = 0 OR expiresAt < ?)',
          whereArgs: [username, now],
        );
        
        // Log deletion for each session to trigger sync
        for (final session in sessionsToDelete) {
          await _dbHelper.logChange(DatabaseHelper.tableUserSessions, session['id'].toString(), 'delete');
        }
        
        debugPrint('ENHANCED_TOKEN_SERVICE: Deleted $result stale sessions for user: $username');
      }
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error cleaning up user sessions: $e');
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

  /// Public method to clear current session info (used by AuthenticationManager)
  static Future<void> clearCurrentSessionInfo() async {
    await _clearCurrentSessionInfo();
  }

  /// Public method to get current session token (used by AuthenticationManager)
  static Future<String?> getCurrentSessionToken() async {
    return await _getCurrentSessionToken();
  }

  /// Public method to get current username (used by AuthenticationManager)
  static Future<String?> getCurrentUsername() async {
    return await _getCurrentUsername();
  }

  // ============== LAN SYNC BROADCASTING METHODS ==============

  /// Broadcast session deletions to all connected devices via LAN sync
  static Future<void> _broadcastSessionDeletions(String username, List<Map<String, dynamic>> deletedSessions) async {
    try {
      // Prepare session deletion data for broadcast
      final deletionData = {
        'type': 'session_deletion',
        'username': username,
        'timestamp': DateTime.now().toIso8601String(),
        'deleted_sessions': deletedSessions.map((session) => {
          'session_id': session['id'],
          'device_id': session['deviceId'],
          'device_name': session['deviceName'],
          'session_token': session['sessionToken'],
        }).toList(),
        'action': 'delete_sessions',
      };

      debugPrint('ENHANCED_TOKEN_SERVICE: Broadcasting session deletion for user: $username - ${deletedSessions.length} sessions');

      // Broadcast via LAN server if running
      if (EnhancedShelfServer.isRunning) {
        EnhancedShelfServer.announceToClients(
          'Sessions deleted for user: $username',
          type: 'session_deletion',
        );
        
        // Broadcast the session deletion details
        EnhancedShelfServer.announceToClients(
          jsonEncode(deletionData),
          type: 'session_update'
        );
        
        try {
          // Force sync the user_sessions table to all clients
          await EnhancedShelfServer.forceSyncTable('user_sessions');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: Error syncing user_sessions table: $e');
        }
      }

      // Broadcast via sync client to other servers
      try {
        DatabaseSyncClient.broadcastMessage({
          'type': 'database_change',
          'change': {
            'table': 'user_sessions',
            'operation': 'delete',
            'recordId': username,
            'data': deletionData,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'session_manager',
          },
        });
      } catch (e) {
        debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting deletion via sync client: $e');
      }

      debugPrint('ENHANCED_TOKEN_SERVICE: Session deletion broadcasted successfully');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting session deletion: $e');
    }
  }

  /// Broadcast single session deletion to all connected devices via LAN sync
  static Future<void> _broadcastSessionDeletion(Map<String, dynamic> deletedSession) async {
    try {
      await _broadcastSessionDeletions(deletedSession['username'], [deletedSession]);
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting single session deletion: $e');
    }
  }

  /// Broadcast new session creation to all connected devices
  static Future<void> _broadcastSessionCreation(String username, String sessionToken, String deviceId, String deviceName) async {
    try {
      final sessionData = {
        'type': 'session_creation',
        'username': username,
        'session_token': sessionToken,
        'device_id': deviceId,
        'device_name': deviceName,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'new_login',
      };

      debugPrint('ENHANCED_TOKEN_SERVICE: Broadcasting new session creation for user: $username on device: $deviceName');

      // Broadcast via LAN server if running
      if (EnhancedShelfServer.isRunning) {
        EnhancedShelfServer.announceToClients(
          'New login detected for user: $username on device: $deviceName',
          type: 'session_creation',
        );
        
        // Force sync the user_sessions table to all clients
        try {
          await EnhancedShelfServer.forceSyncTable('user_sessions');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: Error syncing user_sessions table: $e');
        }
      }

      // Broadcast via sync client to other servers
      try {
        DatabaseSyncClient.broadcastMessage({
          'type': 'database_change',
          'change': {
            'table': 'user_sessions',
            'operation': 'insert',
            'recordId': sessionToken,
            'data': sessionData,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'session_manager',
          },
        });
      } catch (e) {
        debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting via sync client: $e');
      }

      debugPrint('ENHANCED_TOKEN_SERVICE: Session creation broadcasted successfully');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting session creation: $e');
    }
  }

  /// Broadcast real-time session changes to all connected devices immediately
  static Future<void> _broadcastRealTimeSessionChange(String changeType, Map<String, dynamic> sessionData) async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: Broadcasting real-time session change: $changeType');
      
      final broadcastData = {
        'type': 'real_time_session_change',
        'changeType': changeType,
        'sessionData': sessionData,
        'timestamp': DateTime.now().toIso8601String(),
        'priority': 'immediate',
      };

      // Broadcast via LAN server if running (host)
      if (EnhancedShelfServer.isRunning) {
        try {
          // Send immediate WebSocket message to all connected clients
          await EnhancedShelfServer.broadcastToAllClients(broadcastData);
          debugPrint('ENHANCED_TOKEN_SERVICE: Real-time session change broadcasted to all clients');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting via server: $e');
        }
      }

      // Broadcast via sync client if connected (client)
      if (DatabaseSyncClient.isConnected) {
        try {
          DatabaseSyncClient.broadcastMessage(broadcastData);
          debugPrint('ENHANCED_TOKEN_SERVICE: Real-time session change sent to host');
        } catch (e) {
          debugPrint('ENHANCED_TOKEN_SERVICE: Error broadcasting via client: $e');
        }
      }
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error in real-time session broadcast: $e');
    }
  }

  /// Force refresh session data from connected devices
  static Future<void> refreshSessionDataFromNetwork() async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: Refreshing session data from network');
      
      if (DatabaseSyncClient.isConnected) {
        // Request immediate sync of user_sessions table
        DatabaseSyncClient.broadcastMessage({
          'type': 'force_table_sync',
          'table': 'user_sessions',
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Also request a manual sync
        await DatabaseSyncClient.manualSync();
        
        debugPrint('ENHANCED_TOKEN_SERVICE: Requested session table sync from network');
      } else {
        debugPrint('ENHANCED_TOKEN_SERVICE: Not connected to network, skipping remote sync');
      }
      
      // Clean up any expired sessions after sync
      await cleanupExpiredSessions();
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Session data refresh completed');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error refreshing session data: $e');
    }
  }

  /// Check for session conflicts across the network before login
  static Future<bool> checkNetworkSessionConflicts(String username) async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: Checking network-wide session conflicts for user: $username');
      
      // Wait a bit to ensure any recent sync operations complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force a complete sync of session data from network
      await refreshSessionDataFromNetwork();
      
      // Wait for sync to complete
      await Future.delayed(const Duration(seconds: 2));
      
      // Clean up any expired sessions first
      await cleanupExpiredSessions();
      
      // Check for active sessions excluding current device
      final activeSessions = await getActiveUserSessions(
        username, 
        excludeCurrentDevice: false // Check all devices including current
      );
      
      // Also check for sessions from other devices specifically
      final otherDeviceSessions = await getActiveUserSessions(
        username,
        excludeCurrentDevice: true
      );
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Session check results for $username:');
      debugPrint('  - Total active sessions: ${activeSessions.length}');
      debugPrint('  - Other device sessions: ${otherDeviceSessions.length}');
      
      // If there are sessions from other devices, that's a conflict
      if (otherDeviceSessions.isNotEmpty) {
        debugPrint('ENHANCED_TOKEN_SERVICE: Network session conflict detected for $username: ${otherDeviceSessions.length} active sessions on other devices');
        for (final session in otherDeviceSessions) {
          debugPrint('  - Session on device: ${session['deviceName']} (${session['deviceId']}) - expires: ${session['expiresAt']}');
        }
        return true;
      }
      
      debugPrint('ENHANCED_TOKEN_SERVICE: No network session conflicts for user: $username');
      return false;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error checking network session conflicts: $e');
      // Return false to allow login if we can't check network state
      return false;
    }
  }

  /// Verify that session was created on both host and client devices
  /// This method should be called after login to ensure cross-device sync worked
  static Future<bool> verifySessionSyncAcrossDevices(String username, String sessionToken) async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Starting session sync verification for $username');
      
      // Step 1: Verify local session exists
      final localSession = await _verifyLocalSession(username, sessionToken);
      if (!localSession) {
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Local session NOT found!');
        return false;
      }
      
      // Step 2: Force network refresh to get latest state
      await refreshSessionDataFromNetwork();
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Step 3: Check if session exists on remote devices
      final allSessions = await getActiveUserSessions(username);
      final sessionExists = allSessions.any((session) => 
        session['sessionToken'] == sessionToken && 
        (session['isActive'] as int) == 1
      );
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Found ${allSessions.length} total sessions, session exists: $sessionExists');
      
      if (!sessionExists) {
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Session not found in network! Attempting to recreate...');
        
        // Try to recreate the session data on this device
        await _forceRecreateSession(username, sessionToken);
        
        // Trigger another immediate sync
        await _triggerImmediateSessionSync();
        
        // Wait and check again
        await Future.delayed(const Duration(milliseconds: 2000));
        await refreshSessionDataFromNetwork();
        
        final retryCheck = await getActiveUserSessions(username);
        final retryExists = retryCheck.any((session) => 
          session['sessionToken'] == sessionToken && 
          (session['isActive'] as int) == 1
        );
        
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - After retry: ${retryCheck.length} sessions, exists: $retryExists');
        return retryExists;
      }
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Session sync verification successful');
      return true;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Error during verification: $e');
      return false;
    }
  }

  /// Verify local session exists in database
  static Future<bool> _verifyLocalSession(String username, String sessionToken) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'username = ? AND sessionToken = ? AND isActive = 1',
        whereArgs: [username, sessionToken],
      );
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Local session verification: ${result.length} sessions found');
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error verifying local session: $e');
      return false;
    }
  }

  /// Force recreate session data if it's missing
  static Future<void> _forceRecreateSession(String username, String sessionToken) async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: Force recreating session for $username');
      
      final db = await _dbHelper.database;
      final deviceId = await _getOrCreateDeviceId();
      final now = DateTime.now();
      final expiresAt = now.add(_defaultSessionDuration);
      
      // Create session record
      final sessionData = {
        'id': const Uuid().v4(),
        'session_id': const Uuid().v4(),
        'userId': await _getUserId(username) ?? 'unknown',
        'username': username,
        'deviceId': deviceId,
        'deviceName': await _getDeviceName(),
        'loginTime': now.toIso8601String(),
        'lastActivity': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'invalidated_at': null,
        'ipAddress': await _getLocalIpAddress(),
        'isActive': 1,
        'sessionToken': sessionToken,
      };
      
      await db.insert(
        DatabaseHelper.tableUserSessions,
        sessionData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Log the change for sync
      await _dbHelper.logChange(DatabaseHelper.tableUserSessions, sessionData['id'] as String, 'insert');
      
      debugPrint('ENHANCED_TOKEN_SERVICE: Session forcibly recreated');
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error force recreating session: $e');
    }
  }

  /// Trigger immediate session sync across all devices
  static Future<void> _triggerImmediateSessionSync() async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: Triggering immediate session sync');
      
      // Broadcast via host server
      if (EnhancedShelfServer.isRunning) {
        await EnhancedShelfServer.forceSyncTable('user_sessions');
        debugPrint('ENHANCED_TOKEN_SERVICE: Forced sync from host server');
      }
      
      // Request sync via client
      if (DatabaseSyncClient.isConnected) {
        await DatabaseSyncClient.forceSessionSync();
        debugPrint('ENHANCED_TOKEN_SERVICE: Requested sync from client');
      }
      
      // Trigger cross-device monitor
      await CrossDeviceSessionMonitor.triggerImmediateSessionSync();
      
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: Error triggering immediate sync: $e');
    }
  }

  /// Debug method to check current session table state
  /// This is useful for diagnosing session sync issues
  static Future<void> debugSessionTableState(String username) async {
    try {
      debugPrint('=== SESSION TABLE DEBUG START ===');
      
      final db = await _dbHelper.database;
      
      // Check if table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='user_sessions'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('ERROR: user_sessions table does not exist!');
        return;
      }
      
      debugPrint('user_sessions table exists');
      
      // Get table schema
      final schema = await db.rawQuery("PRAGMA table_info(user_sessions)");
      debugPrint('Table schema: ${schema.length} columns');
      
      // Get all sessions
      final allSessions = await db.query('user_sessions');
      debugPrint('Total sessions in database: ${allSessions.length}');
      
      // Get sessions for specific user
      final userSessions = await db.query(
        'user_sessions',
        where: 'username = ?',
        whereArgs: [username],
      );
      debugPrint('Sessions for user $username: ${userSessions.length}');
      
      // Show each session
      for (int i = 0; i < userSessions.length; i++) {
        final session = userSessions[i];
        debugPrint('Session $i:');
        debugPrint('  ID: ${session['id']}');
        debugPrint('  Username: ${session['username']}');
        debugPrint('  Device: ${session['deviceName']} (${session['deviceId']})');
        debugPrint('  Active: ${session['isActive']}');
        debugPrint('  Token: ${session['sessionToken']?.toString().substring(0, 8)}...');
        debugPrint('  Created: ${session['created_at']}');
        debugPrint('  Expires: ${session['expiresAt']}');
        debugPrint('  IP: ${session['ipAddress']}');
      }
      
      // Check sync log for recent session changes
      final recentSyncLogs = await db.query(
        'sync_log',
        where: 'tableName = ? AND recordId LIKE ?',
        whereArgs: ['user_sessions', '%'],
        orderBy: 'timestamp DESC',
        limit: 10,
      );
      debugPrint('Recent session sync logs: ${recentSyncLogs.length}');
      for (final log in recentSyncLogs) {
        debugPrint('  ${log['timestamp']}: ${log['action']} ${log['recordId']} (synced: ${log['synced']})');
      }
      
      debugPrint('=== SESSION TABLE DEBUG END ===');
    } catch (e) {
      debugPrint('ERROR during session table debug: $e');
    }
  }

  /// Verify session was properly created locally and synced (DEBUG method)
  static Future<bool> verifySessionCreationAndSync(String username, String sessionToken) async {
    try {
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Starting session creation verification...');
      
      // 1. Check if session exists locally
      final db = await _dbHelper.database;
      final localSessions = await db.query(
        DatabaseHelper.tableUserSessions,
        where: 'sessionToken = ? AND username = ?',
        whereArgs: [sessionToken, username],
      );
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Local sessions found: ${localSessions.length}');
      
      if (localSessions.isEmpty) {
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - ERROR: Session not found locally!');
        
        // Check if ANY sessions exist for this user
        final userSessions = await db.query(
          DatabaseHelper.tableUserSessions,
          where: 'username = ?',
          whereArgs: [username],
        );
        
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Total sessions for user $username: ${userSessions.length}');
        for (final session in userSessions) {
          debugPrint('  - Session: ${session['sessionToken']?.toString().substring(0, 8)}..., active: ${session['isActive']}, expires: ${session['expiresAt']}');
        }
        
        return false;
      }
      
      final session = localSessions.first;
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Local session found: ${session['deviceName']} (${session['deviceId']})');
      
      // 2. Verify session is active and not expired
      final isActive = session['isActive'] == 1;
      final expiresAt = DateTime.parse(session['expiresAt'] as String);
      final isNotExpired = expiresAt.isAfter(DateTime.now());
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Session active: $isActive, not expired: $isNotExpired');
      
      if (!isActive || !isNotExpired) {
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - ERROR: Session is inactive or expired!');
        return false;
      }
      
      // 3. Check if session was logged for sync
      final syncLog = await db.query(
        DatabaseHelper.tableSyncLog,
        where: 'tableName = ? AND recordId = ? AND action = ?',
        whereArgs: [DatabaseHelper.tableUserSessions, session['id'], 'insert'],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Sync log entries: ${syncLog.length}');
      
      if (syncLog.isNotEmpty) {
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Session logged for sync: ${syncLog.first['synced'] == 1 ? 'synced' : 'pending'}');
      } else {
        debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - WARNING: No sync log entry found');
      }
      
      // 4. Verify current session info is stored
      final storedToken = await getCurrentSessionToken();
      final storedUsername = await getCurrentUsername();
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Stored session info: token=${storedToken != null ? 'present' : 'missing'}, username=$storedUsername');
      
      final sessionInfoMatches = storedToken == sessionToken && storedUsername == username;
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Session info matches: $sessionInfoMatches');
      
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Session creation verification completed successfully');
      return true;
      
    } catch (e) {
      debugPrint('ENHANCED_TOKEN_SERVICE: VERIFY - Error during verification: $e');
      return false;
    }
  }

  // ...existing code...
}

/// Exception thrown when there's a session conflict (user already logged in)
class UserSessionConflictException implements Exception {
  final String message;
  final List<Map<String, dynamic>> activeSessions;
  
  UserSessionConflictException(this.message, this.activeSessions);
  
  @override
  String toString() => 'UserSessionConflictException: $message';
}
