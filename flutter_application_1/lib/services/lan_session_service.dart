import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Session management logic for LAN, now integrated with ShelfLanServer
class LanSessionService {
  static final Map<String, UserSession> _activeSessions = {};
  static final StreamController<Map<String, dynamic>> _sessionUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  // Session configuration
  static const Duration _sessionTimeout = Duration(hours: 8);
  
  // Compatibility with old service - since we use ShelfLanServer now
  static bool get isServerRunning => false; // This service no longer runs servers

  // Getters
  static Stream<Map<String, dynamic>> get sessionUpdates =>
      _sessionUpdates.stream;
  static Map<String, UserSession> get activeSessions =>
      Map.unmodifiable(_activeSessions);

  /// Initialize the session service (no server)
  static Future<void> initialize() async {
    try {
      debugPrint('LanSessionService: Starting initialization...');
      debugPrint('LAN Session Service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize LAN Session Service: $e');
    }
  }

  /// Set integrated mode (no-op, for compatibility)
  static void setIntegratedMode(bool integrated) {
    debugPrint('LanSessionService: Integrated mode set to $integrated');
  }

  /// Register a new user session
  static Future<UserSession?> registerUserSession({
    required String username,
    required String deviceId,
    required String deviceName,
    required String accessLevel,
    String? ipAddress,
    bool forceLogoutExisting = false,
  }) async {
    try {
      debugPrint(
          'LanSessionService: Registering session for $username on $deviceName');
      debugPrint(
          'LanSessionService: Current active sessions: \\${_activeSessions.length}');

      // Check if user is already logged in on another device
      final existingSession = _findUserSession(username);
      if (existingSession != null) {
        debugPrint(
            'LanSessionService: Found existing session for $username on \\${existingSession.deviceName}');
        if (forceLogoutExisting) {
          debugPrint(
              'LanSessionService: Force logout enabled, ending existing session');
          // Force logout the existing session
          await endUserSession(existingSession.sessionId);

          // Broadcast session invalidation to force logout on the other device
          _broadcastSessionUpdate({
            'type': 'session_invalidated',
            'username': username,
            'reason': 'User logged in from another device',
            'deviceId': existingSession.deviceId,
          });

          debugPrint('Forced logout of existing session for $username');
        } else {
          throw Exception(
              'User "$username" is already logged in on device "\\${existingSession.deviceName}"');
        }
      }

      final sessionId = _generateSessionId();
      final sessionToken = _generateSessionToken();

      final session = UserSession(
        sessionId: sessionId,
        token: sessionToken,
        username: username,
        deviceId: deviceId,
        deviceName: deviceName,
        accessLevel: accessLevel,
        ipAddress: ipAddress,
        loginTime: DateTime.now(),
        lastActivity: DateTime.now(),
      );

      _activeSessions[sessionId] = session;

      // Log session activity
      await _logSessionActivity(
        sessionId,
        'SESSION_START',
        'User logged in from $deviceName',
      );

      _broadcastSessionUpdate({
        'type': 'user_login',
        'session': session.toMap(),
      });

      debugPrint('Registered session for $username on $deviceName');
      return session;
    } catch (e) {
      debugPrint('Failed to register user session: $e');
      rethrow;
    }
  }

  /// End a user session
  static Future<bool> endUserSession(String sessionId) async {
    try {
      final session = _activeSessions[sessionId];
      if (session == null) return false;

      // Log session activity
      await _logSessionActivity(
        sessionId,
        'SESSION_END',
        'User logged out from \\${session.deviceName}',
      );

      final username = session.username;
      _activeSessions.remove(sessionId);

      _broadcastSessionUpdate({
        'type': 'user_logout',
        'sessionId': sessionId,
        'username': username,
      });

      debugPrint('Ended session for $username');
      return true;
    } catch (e) {
      debugPrint('Failed to end user session: $e');
      return false;
    }
  }

  /// Validate a session token
  static UserSession? validateSession(String sessionId, String token) {
    final session = _activeSessions[sessionId];
    if (session == null || session.token != token) {
      return null;
    }

    // Check if session has expired
    if (DateTime.now().difference(session.lastActivity) > _sessionTimeout) {
      endUserSession(sessionId);
      return null;
    }

    // Update last activity
    session.lastActivity = DateTime.now();
    return session;
  }

  /// Update session activity
  static Future<void> updateSessionActivity(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session != null) {
      session.lastActivity = DateTime.now();
    }
  }

  /// Update user activity (alias for compatibility)
  static Future<bool> updateUserActivity(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session != null) {
      session.lastActivity = DateTime.now();
      return true;
    }
    return false;
  }

  /// Get session by device ID
  static UserSession? getSessionByDevice(String deviceId) {
    try {
      return _activeSessions.values
          .firstWhere((session) => session.deviceId == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in
  static bool isUserLoggedIn(String username) {
    return _findUserSession(username) != null;
  }

  /// Force end user session by username (for logout cleanup)
  static Future<bool> forceEndUserSession(String username) async {
    try {
      final session = _findUserSession(username);
      if (session == null) return false;

      return await endUserSession(session.sessionId);
    } catch (e) {
      debugPrint('Error force ending user session: $e');
      return false;
    }
  }

  /// Get logged in users count
  static int getLoggedInUsersCount() {
    return _activeSessions.length;
  }

  /// Find user session
  static UserSession? _findUserSession(String username) {
    try {
      return _activeSessions.values
          .firstWhere((session) => session.username == username);
    } catch (e) {
      return null;
    }
  }

  /// Log session activity
  static Future<void> _logSessionActivity(
    String sessionId,
    String action,
    String details,
  ) async {
    try {
      final session = _activeSessions[sessionId];
      if (session == null) return;

      final dbHelper = DatabaseHelper();
      await dbHelper.logUserActivity(
        session.username,
        action,
        details: details,
        targetRecordId: sessionId,
        targetTable: 'user_sessions',
      );
    } catch (e) {
      debugPrint('Failed to log session activity: $e');
    }
  }

  /// Broadcast session update (local only)
  static void _broadcastSessionUpdate(Map<String, dynamic> update) {
    debugPrint(
        'LanSessionService: Broadcasting session update: \\${update['type']}');
    _sessionUpdates.add(update);
  }

  /// Dispose the service
  static Future<void> dispose() async {
    await _sessionUpdates.close();
  }

  /// Generate session ID
  static String _generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate session token
  static String _generateSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

/// User session model
class UserSession {
  final String sessionId;
  final String token;
  final String username;
  final String deviceId;
  final String deviceName;
  final String accessLevel;
  final String? ipAddress;
  final DateTime loginTime;
  DateTime lastActivity;

  UserSession({
    required this.sessionId,
    required this.token,
    required this.username,
    required this.deviceId,
    required this.deviceName,
    required this.accessLevel,
    this.ipAddress,
    required this.loginTime,
    required this.lastActivity,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'token': token,
      'username': username,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessLevel': accessLevel,
      'ipAddress': ipAddress,
      'loginTime': loginTime.toIso8601String(),
      'lastActivity': lastActivity.toIso8601String(),
      'duration': DateTime.now().difference(loginTime).inMinutes,
    };
  }

  /// Convert to JSON format
  Map<String, dynamic> toJson() => toMap();

  /// Check if session is expired
  bool get isExpired {
    final now = DateTime.now();
    return now.difference(lastActivity) > LanSessionService._sessionTimeout;
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      sessionId: map['sessionId'],
      token: map['token'],
      username: map['username'],
      deviceId: map['deviceId'],
      deviceName: map['deviceName'],
      accessLevel: map['accessLevel'],
      ipAddress: map['ipAddress'],
      loginTime: DateTime.parse(map['loginTime']),
      lastActivity: DateTime.parse(map['lastActivity']),
    );
  }
}
