import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'lan_session_service.dart';
import 'auth_service.dart';

class LanClientService {
  static String? _serverUrl;
  static String? _accessCode;
  static String? _sessionServerUrl;
  static String? _sessionToken;
  static bool _isConnected = false;
  static UserSession? _currentSession;

  // Connection to session server
  static const Duration _heartbeatInterval = Duration(minutes: 1);
  static Timer? _heartbeatTimer;

  /// Connect to a LAN server with session management
  static Future<bool> connectToServerWithSession(
      String serverIp, int port, String accessCode,
      {int sessionPort = 8081}) async {
    try {
      // First connect to the regular data server
      final connected = await connectToServer(serverIp, port, accessCode);
      if (!connected) return false;

      // Then connect to session server
      _sessionServerUrl = 'http://$serverIp:$sessionPort';

      // Get current user info
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Get device info
      final deviceId = await AuthService.getDeviceId();
      final deviceName = await _getDeviceName();

      // Register session with server
      await _registerSessionWithServer(
        currentUser.username,
        deviceId,
        deviceName,
        currentUser.role,
      );

      // Start heartbeat
      _startHeartbeat();

      return true;
    } catch (e) {
      debugPrint('Failed to connect with session: $e');
      return false;
    }
  }

  /// Register session with remote server
  static Future<void> _registerSessionWithServer(
    String username,
    String deviceId,
    String deviceName,
    String accessLevel,
  ) async {
    if (_sessionServerUrl == null) return;

    try {
      // Get session server token
      final serverStatus = await getServerStatus();
      _sessionToken = serverStatus?['sessionToken'];

      if (_sessionToken == null) {
        throw Exception('No session token from server');
      }

      final response = await http
          .post(
            Uri.parse('$_sessionServerUrl/sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode({
              'username': username,
              'deviceId': deviceId,
              'deviceName': deviceName,
              'accessLevel': accessLevel,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['session'] != null) {
          _currentSession = UserSession.fromMap(data['session']);
          debugPrint('Session registered: ${_currentSession!.sessionId}');
        } else {
          throw Exception(data['error'] ?? 'Failed to register session');
        }
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Session conflict');
      } else {
        throw Exception('Session server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to register session: $e');
      rethrow;
    }
  }

  /// Start heartbeat to maintain session
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      if (_currentSession != null &&
          _sessionServerUrl != null &&
          _sessionToken != null) {
        try {
          await http
              .post(
                Uri.parse('$_sessionServerUrl/sessions/activity'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_sessionToken',
                },
                body: jsonEncode({
                  'sessionId': _currentSession!.sessionId,
                }),
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('Heartbeat failed: $e');
        }
      }
    });
  }

  /// Get active sessions from server
  static Future<List<Map<String, dynamic>>?> getActiveSessions() async {
    if (_sessionServerUrl == null || _sessionToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_sessionServerUrl/sessions'),
        headers: {
          'Authorization': 'Bearer $_sessionToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      }
    } catch (e) {
      debugPrint('Failed to get active sessions: $e');
    }
    return null;
  }

  /// End session on server
  static Future<void> endSession() async {
    if (_currentSession == null ||
        _sessionServerUrl == null ||
        _sessionToken == null) {
      return;
    }

    try {
      await http.delete(
        Uri.parse('$_sessionServerUrl/sessions/${_currentSession!.sessionId}'),
        headers: {
          'Authorization': 'Bearer $_sessionToken',
        },
      ).timeout(const Duration(seconds: 5));

      _currentSession = null;
    } catch (e) {
      debugPrint('Failed to end session: $e');
    }
  }

  /// Get device name
  static Future<String> _getDeviceName() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('hostname', []);
        return result.stdout.toString().trim();
      } else if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('hostname', []);
        return result.stdout.toString().trim();
      }
    } catch (e) {
      debugPrint('Failed to get device name: $e');
    }
    return 'Unknown Device';
  }

  // Connect to a LAN server
  static Future<bool> connectToServer(
      String serverIp, int port, String accessCode) async {
    try {
      _serverUrl = 'http://$serverIp:$port';
      _accessCode = accessCode;

      // Test connection by checking server status
      final response = await http.get(
        Uri.parse('$_serverUrl/status'),
        headers: {
          'Authorization': 'Bearer $accessCode',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isConnected = true;
        debugPrint('Connected to LAN server: ${data['status']}');
        return true;
      } else {
        debugPrint('Failed to connect: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  // Download database from LAN server
  static Future<String?> downloadDatabase() async {
    if (!_isConnected || _serverUrl == null || _accessCode == null) {
      debugPrint('Not connected to server');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/db'),
        headers: {
          'Authorization': 'Bearer $_accessCode',
        },
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        // Save the database file locally
        final appDir = await getApplicationDocumentsDirectory();
        final dbPath = join(appDir.path, 'patient_management_lan.db');
        final file = File(dbPath);

        await file.writeAsBytes(response.bodyBytes);
        debugPrint('Database downloaded to: $dbPath');
        return dbPath;
      } else {
        debugPrint('Failed to download database: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  // Get server status
  static Future<Map<String, dynamic>?> getServerStatus() async {
    if (_serverUrl == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse('$_serverUrl/status'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Add session information if available
        if (_currentSession != null) {
          data['currentSession'] = _currentSession!.toMap();
        }

        return data;
      }
    } catch (e) {
      debugPrint('Status check error: $e');
    }
    return null;
  }

  // Send changes to server
  static Future<bool> uploadChanges(List<Map<String, dynamic>> changes) async {
    if (!_isConnected || _serverUrl == null || _accessCode == null) {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_serverUrl/sync'),
            headers: {
              'Authorization': 'Bearer $_accessCode',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'changes': changes,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Upload changes error: $e');
      return false;
    }
  }

  // Get changes from server
  static Future<List<Map<String, dynamic>>?> downloadChanges() async {
    if (!_isConnected || _serverUrl == null || _accessCode == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/changes'),
        headers: {
          'Authorization': 'Bearer $_accessCode',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['changes'] ?? []);
      }
    } catch (e) {
      debugPrint('Download changes error: $e');
    }
    return null;
  }

  // Disconnect from server
  static void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // End session on server
    if (_currentSession != null) {
      endSession();
    }

    _serverUrl = null;
    _accessCode = null;
    _sessionServerUrl = null;
    _sessionToken = null;
    _currentSession = null;
    _isConnected = false;
    debugPrint('Disconnected from LAN server');
  }

  // Check if connected
  static bool get isConnected => _isConnected;

  // Get server URL
  static String? get serverUrl => _serverUrl;

  // Get current session
  static UserSession? get currentSession => _currentSession;

  // Check if session is active
  static bool get hasActiveSession => _currentSession != null;
}
