import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'database_helper.dart';
import 'auth_service.dart';

/// Enhanced LAN Session Service for multi-device user session management
class LanSessionService {
  static final Map<String, UserSession> _activeSessions = {};
  static final Map<String, WebSocketChannel> _deviceConnections = {};
  static final StreamController<Map<String, dynamic>> _sessionUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  static HttpServer? _sessionServer;
  static Timer? _sessionMonitor;
  static String? _serverToken;
  static bool _isServerRunning = false;
  static bool _integratedMode = false; // Flag for integrated mode

  // Session configuration
  static const Duration _sessionTimeout = Duration(hours: 8);
  static const Duration _heartbeatInterval = Duration(minutes: 1);
  static const int _defaultSessionPort = 8081;

  // Getters
  static Stream<Map<String, dynamic>> get sessionUpdates =>
      _sessionUpdates.stream;
  static bool get isServerRunning => _isServerRunning;
  static Map<String, UserSession> get activeSessions =>
      Map.unmodifiable(_activeSessions);

  /// Initialize the session service
  static Future<void> initialize() async {
    try {
      debugPrint('LanSessionService: Starting initialization...');
      await _loadServerConfiguration();
      await _startSessionMonitoring();

      // Register session callbacks with auth service
      AuthService.registerSessionCallbacks(
        getActiveSessions: () => _activeSessions,
        endSession: endUserSession,
      );

      debugPrint('LAN Session Service initialized successfully');
      debugPrint('Session server running: $_isServerRunning');
    } catch (e) {
      debugPrint('Failed to initialize LAN Session Service: $e');
    }
  }

  /// Set integrated mode (called by LAN sync service)
  static void setIntegratedMode(bool integrated) {
    _integratedMode = integrated;
    debugPrint('LanSessionService: Integrated mode set to $integrated');
  }

  /// Start the session server
  static Future<bool> startSessionServer(
      {int port = _defaultSessionPort}) async {
    try {
      if (_sessionServer != null) {
        await stopSessionServer();
      }

      _generateServerToken();
      _sessionServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;

      debugPrint(
          'Session server started on port $port with token: $_serverToken');

      _sessionServer!.listen(_handleSessionRequest);
      await _startSessionMonitoring();

      // Save configuration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('session_server_enabled', true);
      await prefs.setInt('session_server_port', port);
      await prefs.setString('session_server_token', _serverToken!);

      _broadcastSessionUpdate({'type': 'server_started', 'port': port});
      return true;
    } catch (e) {
      debugPrint('Failed to start session server: $e');
      _isServerRunning = false;
      return false;
    }
  }

  /// Stop the session server
  static Future<void> stopSessionServer() async {
    try {
      await _sessionServer?.close(force: true);
      _sessionServer = null;
      _isServerRunning = false;

      // Close all device connections
      for (final connection in _deviceConnections.values) {
        await connection.sink.close();
      }
      _deviceConnections.clear();

      // Clear all sessions
      _activeSessions.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('session_server_enabled', false);

      _broadcastSessionUpdate({'type': 'server_stopped'});
      debugPrint('Session server stopped');
    } catch (e) {
      debugPrint('Error stopping session server: $e');
    }
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
          'LanSessionService: Current active sessions: ${_activeSessions.length}');

      // Check if user is already logged in on another device
      final existingSession = _findUserSession(username);
      if (existingSession != null) {
        debugPrint(
            'LanSessionService: Found existing session for $username on ${existingSession.deviceName}');
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
              'User "$username" is already logged in on device "${existingSession.deviceName}"');
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

      // Close device connection if exists
      final connection = _deviceConnections[session.deviceId];
      if (connection != null) {
        await connection.sink.close();
        _deviceConnections.remove(session.deviceId);
      }

      // Log session activity
      await _logSessionActivity(
        sessionId,
        'SESSION_END',
        'User logged out from ${session.deviceName}',
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

  /// Handle session requests
  static void _handleSessionRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final method = request.method;

      // Add CORS headers
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers
          .add('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
      request.response.headers
          .add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      if (method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      // Validate server token
      if (!_validateServerToken(request)) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write(jsonEncode({'error': 'Invalid server token'}));
        await request.response.close();
        return;
      }

      switch (path) {
        case '/sessions':
          if (method == 'GET') {
            await _handleGetSessions(request);
          } else if (method == 'POST') {
            await _handleCreateSession(request);
          }
          break;

        case '/sessions/validate':
          if (method == 'POST') {
            await _handleValidateSession(request);
          }
          break;

        case '/sessions/activity':
          if (method == 'POST') {
            await _handleUpdateActivity(request);
          }
          break;

        case '/ws':
          await _handleWebSocketUpgrade(request);
          break;

        default:
          if (path.startsWith('/sessions/')) {
            final sessionId = path.split('/').last;
            if (method == 'DELETE') {
              await _handleEndSession(request, sessionId);
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
      }
    } catch (e) {
      debugPrint('Error handling session request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': 'Internal server error'}));
      await request.response.close();
    }
  }

  /// Handle get sessions request
  static Future<void> _handleGetSessions(HttpRequest request) async {
    final sessions = _activeSessions.values.map((s) => s.toMap()).toList();

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'sessions': sessions,
      'count': sessions.length,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    await request.response.close();
  }

  /// Handle create session request
  static Future<void> _handleCreateSession(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    try {
      final session = await registerUserSession(
        username: data['username'],
        deviceId: data['deviceId'],
        deviceName: data['deviceName'],
        accessLevel: data['accessLevel'],
        ipAddress: request.connectionInfo?.remoteAddress.address,
      );

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': true,
        'session': session?.toMap(),
      }));
    } catch (e) {
      request.response.statusCode = HttpStatus.conflict;
      request.response.write(jsonEncode({
        'success': false,
        'error': e.toString(),
      }));
    }

    await request.response.close();
  }

  /// Handle validate session request
  static Future<void> _handleValidateSession(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final session = validateSession(data['sessionId'], data['token']);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'valid': session != null,
      'session': session?.toMap(),
    }));
    await request.response.close();
  }

  /// Handle update activity request
  static Future<void> _handleUpdateActivity(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    await updateSessionActivity(data['sessionId']);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true}));
    await request.response.close();
  }

  /// Handle end session request
  static Future<void> _handleEndSession(
      HttpRequest request, String sessionId) async {
    final success = await endUserSession(sessionId);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': success}));
    await request.response.close();
  }

  /// Handle WebSocket upgrade
  static Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final deviceId = request.uri.queryParameters['deviceId'];
    if (deviceId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final channel = IOWebSocketChannel(socket);

    _deviceConnections[deviceId] = channel;

    // Send current sessions to newly connected device
    channel.sink.add(jsonEncode({
      'type': 'initial_sessions',
      'sessions': _activeSessions.values.map((s) => s.toMap()).toList(),
    }));

    // Listen for device messages
    channel.stream.listen(
      (message) => _handleDeviceMessage(deviceId, message),
      onDone: () => _deviceConnections.remove(deviceId),
      onError: (error) {
        debugPrint('WebSocket error for device $deviceId: $error');
        _deviceConnections.remove(deviceId);
      },
    );
  }

  /// Handle device messages
  static void _handleDeviceMessage(String deviceId, dynamic message) async {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'];

      switch (type) {
        case 'heartbeat':
          final sessionId = data['sessionId'];
          if (sessionId != null) {
            await updateSessionActivity(sessionId);
          }
          break;
        case 'logout':
          final sessionId = data['sessionId'];
          if (sessionId != null) {
            await endUserSession(sessionId);
          }
          break;
      }
    } catch (e) {
      debugPrint('Error handling device message: $e');
    }
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

  /// Generate server token
  static void _generateServerToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    _serverToken = base64Url.encode(bytes);
  }

  /// Validate server token
  static bool _validateServerToken(HttpRequest request) {
    final authHeader = request.headers.value('Authorization');
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return false;
    }

    final token = authHeader.substring(7);
    return token == _serverToken;
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

  /// Start session monitoring
  static Future<void> _startSessionMonitoring() async {
    _sessionMonitor?.cancel();

    _sessionMonitor = Timer.periodic(_heartbeatInterval, (timer) async {
      final now = DateTime.now();
      final expiredSessions = <String>[];

      // Find expired sessions
      for (final entry in _activeSessions.entries) {
        if (now.difference(entry.value.lastActivity) > _sessionTimeout) {
          expiredSessions.add(entry.key);
        }
      }

      // Remove expired sessions
      for (final sessionId in expiredSessions) {
        await endUserSession(sessionId);
      }
    });
  }

  /// Load server configuration
  static Future<void> _loadServerConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('session_server_enabled') ?? false;
    final port = prefs.getInt('session_server_port') ?? _defaultSessionPort;
    _serverToken = prefs.getString('session_server_token');

    debugPrint(
        'LanSessionService: Loading configuration - enabled: $isEnabled, port: $port, hasToken: ${_serverToken != null}, integratedMode: $_integratedMode');

    // Only start standalone server if not in integrated mode
    if (isEnabled && _serverToken != null && !_integratedMode) {
      debugPrint('LanSessionService: Starting standalone session server...');
      await startSessionServer(port: port);
    } else if (_integratedMode) {
      debugPrint(
          'LanSessionService: Running in integrated mode - skipping standalone server start');
      // Generate token for integrated mode if needed
      if (_serverToken == null) {
        _generateServerToken();
        await prefs.setString('session_server_token', _serverToken!);
      }
    } else {
      debugPrint(
          'LanSessionService: Session server not enabled or token missing');
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

  /// Broadcast session update
  static void _broadcastSessionUpdate(Map<String, dynamic> update) {
    debugPrint(
        'LanSessionService: Broadcasting session update: ${update['type']}');
    _sessionUpdates.add(update);

    // Send to all connected devices
    for (final connection in _deviceConnections.values) {
      try {
        connection.sink.add(jsonEncode(update));
        debugPrint('LanSessionService: Sent update to device');
      } catch (e) {
        debugPrint('Error broadcasting to device: $e');
      }
    }
  }

  /// Get server token
  static String? getServerToken() => _serverToken;

  /// Dispose the service
  static Future<void> dispose() async {
    _sessionMonitor?.cancel();
    await stopSessionServer();
    await _sessionUpdates.close();
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
