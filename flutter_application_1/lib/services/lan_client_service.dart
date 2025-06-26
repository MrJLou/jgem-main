import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lan_session_service.dart';
import 'auth_service.dart';

class LanClientService {
  static String? _serverUrl;
  static String? _accessCode;
  static String? _sessionServerUrl;
  static String? _sessionToken;
  static bool _isConnected = false;
  static UserSession? _currentSession;

  // Auto-reconnection variables
  static Timer? _reconnectionTimer;
  static bool _autoReconnectEnabled = true;
  static const Duration _reconnectionInterval =
      Duration(seconds: 10); // More frequent attempts
  static int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 30; // More attempts

  // Connection to session server
  static const Duration _heartbeatInterval = Duration(minutes: 1);
  static Timer? _heartbeatTimer;

  /// Initialize the service with auto-reconnection
  static Future<void> initialize() async {
    try {
      await _loadSavedConnectionInfo();
      _startAutoReconnection();
      debugPrint('LAN Client Service initialized with auto-reconnection');
    } catch (e) {
      debugPrint('Failed to initialize LAN Client Service: $e');
    }
  }

  /// Load previously saved connection information
  static Future<void> _loadSavedConnectionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverIp = prefs.getString('lan_server_ip');
      
      // Handle both int and string values for port
      final serverPortValue = prefs.get('lan_server_port');
      String? serverPort;
      if (serverPortValue is int) {
        serverPort = serverPortValue.toString();
      } else if (serverPortValue is String) {
        serverPort = serverPortValue;
      }
      
      final accessCode = prefs.getString('lan_access_code');
      final wasConnected = prefs.getBool('was_connected') ?? false;

      if (serverIp != null && serverPort != null && accessCode != null) {
        final port = int.tryParse(serverPort) ?? 8080;
        debugPrint(
            'Found saved connection info: $serverIp:$port (wasConnected: $wasConnected)');

        // Store connection info for auto-reconnection
        _serverUrl = 'http://$serverIp:$port';
        _accessCode = accessCode;

        // Try to reconnect automatically if was previously connected
        if (wasConnected) {
          debugPrint('Attempting immediate reconnection...');
          await _attemptReconnection(serverIp, port, accessCode);
        }
      } else {
        debugPrint('No saved connection info found');
      }
    } catch (e) {
      debugPrint('Error loading saved connection info: $e');
    }
  }

  /// Start auto-reconnection timer
  static void _startAutoReconnection() {
    _reconnectionTimer?.cancel();

    if (!_autoReconnectEnabled) return;

    _reconnectionTimer = Timer.periodic(_reconnectionInterval, (timer) async {
      if (!_isConnected && _reconnectionAttempts < _maxReconnectionAttempts) {
        await _checkAndReconnect();
      }
    });
  }

  /// Check if server is available and reconnect if possible
  static Future<void> _checkAndReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverIp = prefs.getString('lan_server_ip');
      
      // Handle both int and string values for port
      final serverPortValue = prefs.get('lan_server_port');
      String? serverPort;
      if (serverPortValue is int) {
        serverPort = serverPortValue.toString();
      } else if (serverPortValue is String) {
        serverPort = serverPortValue;
      }
      
      final accessCode = prefs.getString('lan_access_code');

      if (serverIp != null && serverPort != null && accessCode != null) {
        final port = int.tryParse(serverPort) ?? 8080;

        // Check if server is reachable
        if (await _isServerReachable(serverIp, port)) {
          debugPrint('Server is back online, attempting reconnection...');
          await _attemptReconnection(serverIp, port, accessCode);
        }
      }
    } catch (e) {
      debugPrint('Auto-reconnection check failed: $e');
    }
  }

  /// Check if server is reachable
  static Future<bool> _isServerReachable(String serverIp, int port) async {
    try {
      final response = await http.get(
        Uri.parse('http://$serverIp:$port/status'),
        headers: {'Authorization': 'Bearer ${_accessCode ?? ''}'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Attempt to reconnect with session management
  static Future<void> _attemptReconnection(
      String serverIp, int port, String accessCode) async {
    try {
      _reconnectionAttempts++;
      debugPrint(
          'Reconnection attempt $_reconnectionAttempts/$_maxReconnectionAttempts');

      final connected =
          await connectToServerWithSession(serverIp, port, accessCode);

      if (connected) {
        debugPrint('Successfully reconnected to server');
        _reconnectionAttempts = 0;

        // Save successful connection state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('was_connected', true);
      } else {
        debugPrint('Reconnection attempt failed');
      }
    } catch (e) {
      debugPrint('Reconnection attempt error: $e');
    }
  }

  /// Save connection state when connected
  static Future<void> _saveConnectionState(
      String serverIp, int port, String accessCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lan_server_ip', serverIp);
      await prefs.setInt('lan_server_port', port);
      await prefs.setString('lan_access_code', accessCode);
      await prefs.setBool('was_connected', true);
    } catch (e) {
      debugPrint('Error saving connection state: $e');
    }
  }

  /// Clear connection state when disconnected
  static Future<void> _clearConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('was_connected', false);
    } catch (e) {
      debugPrint('Error clearing connection state: $e');
    }
  }

  /// Enable or disable auto-reconnection
  static void setAutoReconnection(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (enabled) {
      _startAutoReconnection();
    } else {
      _reconnectionTimer?.cancel();
    }
  }

  /// Connect to a LAN server with integrated session management
  static Future<bool> connectToServerWithSession(
      String serverIp, int port, String accessCode) async {
    try {
      debugPrint(
          'Attempting to connect to $serverIp:$port with session management...');

      // First, enable sync features if not already enabled
      await enableSyncFeatures();

      // Test basic network connectivity first
      final networkReachable = await testConnection(serverIp, port);
      if (!networkReachable) {
        debugPrint('Network connectivity test failed to $serverIp:$port');
        return false;
      }

      debugPrint('Network connectivity test passed');

      // Connect to the server (now with integrated session management)
      final connected = await connectToServer(serverIp, port, accessCode);
      if (!connected) {
        debugPrint('Failed to connect to server during basic connection test');
        return false;
      }

      // Use the same server URL for session management
      _sessionServerUrl = 'http://$serverIp:$port';

      // Get current user info
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Get device info
      final deviceId = await AuthService.getDeviceId();
      final deviceName = await _getDeviceName();

      // Register session with integrated server
      await _registerSessionWithIntegratedServer(
        currentUser.username,
        deviceId,
        deviceName,
        currentUser.role,
      );

      // Start heartbeat
      _startHeartbeat();

      // Save connection state for auto-reconnection
      await _saveConnectionState(serverIp, port, accessCode);

      _isConnected = true;
      _reconnectionAttempts = 0;

      debugPrint(
          'Successfully connected to server with integrated session management');
      debugPrint('Session ID: ${_currentSession?.sessionId}');
      return true;
    } catch (e) {
      debugPrint('Failed to connect with session: $e');
      return false;
    }
  }

  /// Disconnect from server and clear session
  static Future<void> disconnect() async {
    try {
      _isConnected = false;
      _heartbeatTimer?.cancel();

      // End session if active
      if (_currentSession != null &&
          _sessionServerUrl != null &&
          _sessionToken != null) {
        try {
          await http.delete(
            Uri.parse(
                '$_sessionServerUrl/sessions/${_currentSession!.sessionId}'),
            headers: {
              'Authorization': 'Bearer $_sessionToken',
            },
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('Error ending session: $e');
        }
      }

      // Clear connection state
      await _clearConnectionState();

      _currentSession = null;
      _sessionToken = null;
      _serverUrl = null;
      _sessionServerUrl = null;

      debugPrint('Disconnected from LAN server');
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    }
  }

  /// Register session with integrated server (using same port)
  static Future<void> _registerSessionWithIntegratedServer(
    String username,
    String deviceId,
    String deviceName,
    String accessLevel,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_sessionServerUrl/session/create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessCode',
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
          _sessionToken = data['session']['token'];
          _currentSession = UserSession.fromMap(data['session']);
          debugPrint('Session registered successfully with integrated server');
        } else {
          throw Exception('Session registration failed: ${data['error']}');
        }
      } else {
        throw Exception('Session registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to register session with integrated server: $e');
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
      debugPrint('Connecting to LAN server at $serverIp:$port...');

      _serverUrl = 'http://$serverIp:$port';
      _accessCode = accessCode;

      // Test connection by checking server status
      debugPrint('Testing server status...');
      final response = await http.get(
        Uri.parse('$_serverUrl/status'),
        headers: {
          'Authorization': 'Bearer $accessCode',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Server response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isConnected = true;
        debugPrint('Connected to LAN server successfully');
        debugPrint('Server status: ${data['status']}');

        // Save connection state for auto-reconnection
        await _saveConnectionState(serverIp, port, accessCode);

        return true;
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed - invalid access code');
        return false;
      } else {
        debugPrint('Server returned error status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Connection error details: $e');

      if (e.toString().contains('SocketException')) {
        debugPrint('Network error - server may not be running or unreachable');
      } else if (e.toString().contains('TimeoutException')) {
        debugPrint('Connection timeout - server is not responding');
      } else if (e.toString().contains('FormatException')) {
        debugPrint('Server response format error - may not be our server');
      }

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
  static Future<void> disconnectOld() async {
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

  /// Test network connectivity to a specific IP and port
  static Future<bool> testConnection(String serverIp, int port) async {
    try {
      debugPrint('Testing connection to $serverIp:$port...');

      // Try to establish a socket connection
      final socket = await Socket.connect(
        serverIp,
        port,
        timeout: const Duration(seconds: 5),
      );

      socket.destroy();
      debugPrint('Socket connection successful to $serverIp:$port');
      return true;
    } catch (e) {
      debugPrint('Socket connection failed to $serverIp:$port: $e');
      return false;
    }
  }

  /// Scan for available LAN servers on common ports
  static Future<List<Map<String, dynamic>>> scanForServers() async {
    final List<Map<String, dynamic>> foundServers = [];

    try {
      // Get local network info
      final interfaces = await NetworkInterface.list();
      final localNetworks = <String>[];

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Extract network prefix (assuming /24 subnet)
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
              if (!localNetworks.contains(networkPrefix)) {
                localNetworks.add(networkPrefix);
                debugPrint('Scanning network: $networkPrefix.x');
              }
            }
          }
        }
      }

      // Common ports to check
      final ports = [8080, 3000, 8000, 9000];

      // Scan common IP ranges in each network
      for (final network in localNetworks) {
        final commonIps = [
          1,
          2,
          100,
          101,
          102,
          254
        ]; // Common router/server IPs

        for (final ip in commonIps) {
          final serverIp = '$network.$ip';

          for (final port in ports) {
            try {
              if (await testConnection(serverIp, port)) {
                // Try to get server status
                final serverInfo = await _getServerInfo(serverIp, port);
                if (serverInfo != null) {
                  foundServers.add({
                    'ip': serverIp,
                    'port': port,
                    'info': serverInfo,
                  });
                  debugPrint('Found server at $serverIp:$port');
                }
              }
            } catch (e) {
              // Ignore connection failures during scan
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error during server scan: $e');
    }

    return foundServers;
  }

  /// Get server information from a discovered server
  static Future<Map<String, dynamic>?> _getServerInfo(
      String serverIp, int port) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$serverIp:$port/status'),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Server might require authentication or not be our server
    }
    return null;
  }

  /// Get detailed connection diagnostics
  static Future<Map<String, dynamic>> getConnectionDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      // Check saved connection info
      final prefs = await SharedPreferences.getInstance();
      final serverIp = prefs.getString('lan_server_ip');
      
      // Handle both int and string values for port
      final serverPortValue = prefs.get('lan_server_port');
      String? serverPort;
      if (serverPortValue is int) {
        serverPort = serverPortValue.toString();
      } else if (serverPortValue is String) {
        serverPort = serverPortValue;
      }
      
      final accessCode = prefs.getString('lan_access_code');
      final syncEnabled = prefs.getBool('sync_enabled') ?? false;
      final lanServerEnabled = prefs.getBool('lan_server_enabled') ?? false;

      diagnostics['savedServerIp'] = serverIp;
      diagnostics['savedServerPort'] = serverPort;
      diagnostics['hasAccessCode'] = accessCode != null;
      diagnostics['syncEnabled'] = syncEnabled;
      diagnostics['lanServerEnabled'] = lanServerEnabled;
      diagnostics['isConnected'] = _isConnected;
      diagnostics['currentSession'] = _currentSession?.toMap();

      // Test network connectivity
      if (serverIp != null && serverPort != null) {
        final port = int.tryParse(serverPort) ?? 8080;
        diagnostics['networkReachable'] = await testConnection(serverIp, port);

        // Test HTTP connectivity
        try {
          final response = await http
              .get(
                Uri.parse('http://$serverIp:$port/status'),
                headers: accessCode != null
                    ? {'Authorization': 'Bearer $accessCode'}
                    : {},
              )
              .timeout(const Duration(seconds: 5));

          diagnostics['httpReachable'] = true;
          diagnostics['httpStatusCode'] = response.statusCode;

          if (response.statusCode == 200) {
            try {
              diagnostics['serverResponse'] = jsonDecode(response.body);
            } catch (e) {
              diagnostics['serverResponse'] = response.body;
            }
          }
        } catch (e) {
          diagnostics['httpReachable'] = false;
          diagnostics['httpError'] = e.toString();
        }
      }

      // Get network interfaces
      final interfaces = await NetworkInterface.list();
      final networkInfo = <Map<String, dynamic>>[];

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            networkInfo.add({
              'interface': interface.name,
              'address': addr.address,
              'isLoopback': addr.isLoopback,
            });
          }
        }
      }

      diagnostics['networkInterfaces'] = networkInfo;
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    return diagnostics;
  }

  /// Enable sync and LAN features
  static Future<void> enableSyncFeatures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_enabled', true);
      await prefs.setBool('lan_server_enabled', true);
      debugPrint('Sync and LAN features enabled');
    } catch (e) {
      debugPrint('Failed to enable sync features: $e');
    }
  }

  /// Comprehensive connection troubleshooting method
  static Future<Map<String, dynamic>> troubleshootConnection() async {
    final report = <String, dynamic>{};
    report['timestamp'] = DateTime.now().toIso8601String();
    report['issues'] = <String>[];
    report['recommendations'] = <String>[];

    try {
      debugPrint('Starting connection troubleshooting...');

      // Get current diagnostics
      final diagnostics = await getConnectionDiagnostics();
      report['diagnostics'] = diagnostics;

      // Check sync settings
      if (!diagnostics['syncEnabled']) {
        report['issues'].add('Sync is disabled in settings');
        report['recommendations'].add('Enable sync in app settings');
      }

      if (!diagnostics['lanServerEnabled']) {
        report['issues'].add('LAN server is disabled in settings');
        report['recommendations'].add('Enable LAN server in app settings');
      }

      // Check if we have server configuration
      if (diagnostics['savedServerIp'] == null) {
        report['issues'].add('No server IP configured');
        report['recommendations']
            .add('Configure server IP in LAN connection settings');
      }

      if (diagnostics['savedServerPort'] == null) {
        report['issues'].add('No server port configured');
        report['recommendations']
            .add('Configure server port in LAN connection settings');
      }

      if (!diagnostics['hasAccessCode']) {
        report['issues'].add('No access code configured');
        report['recommendations']
            .add('Enter the correct access code provided by the server');
      }

      // Test network connectivity if we have server info
      if (diagnostics['savedServerIp'] != null &&
          diagnostics['savedServerPort'] != null) {
        final serverIp = diagnostics['savedServerIp'];
        final port = int.tryParse(diagnostics['savedServerPort']) ?? 8080;

        if (diagnostics['networkReachable'] == false) {
          report['issues'].add('Server is not reachable on network');
          report['recommendations'].addAll([
            'Check if server device is on the same network',
            'Verify server IP address: $serverIp',
            'Verify server port: $port',
            'Check firewall settings on both devices',
            'Try pinging the server: ping $serverIp'
          ]);
        }

        if (diagnostics['httpReachable'] == false) {
          report['issues'].add('HTTP connection to server failed');
          report['recommendations'].addAll([
            'Server application may not be running',
            'Check if LAN server is started on host device',
            'Verify port $port is not blocked by firewall',
            'Try accessing http://$serverIp:$port/status in a web browser'
          ]);
        }

        if (diagnostics['httpStatusCode'] == 401) {
          report['issues'].add('Authentication failed - invalid access code');
          report['recommendations']
              .add('Check and re-enter the access code from the server');
        }
      }

      // Check network interfaces
      final interfaces =
          diagnostics['networkInterfaces'] as List<dynamic>? ?? [];
      final localIps = interfaces
          .where((i) => !i['isLoopback'])
          .map((i) => i['address'])
          .toList();

      if (localIps.isEmpty) {
        report['issues'].add('No network connections found');
        report['recommendations']
            .add('Check network connection (WiFi/Ethernet)');
      } else {
        report['localIpAddresses'] = localIps;
      }

      // Suggest server scanning
      if (diagnostics['savedServerIp'] == null) {
        report['recommendations'].add(
            'Use the "Scan for Servers" feature to automatically discover servers');
      }

      // Auto-fix simple issues
      int autoFixCount = 0;
      if (!diagnostics['syncEnabled'] || !diagnostics['lanServerEnabled']) {
        await enableSyncFeatures();
        autoFixCount++;
      }

      if (autoFixCount > 0) {
        report['autoFixesApplied'] = autoFixCount;
        report['message'] =
            'Applied $autoFixCount automatic fixes. Please try connecting again.';
      }
    } catch (e) {
      report['error'] = 'Troubleshooting failed: $e';
    }

    return report;
  }

  /// Quick connection test with a specific server
  static Future<Map<String, dynamic>> quickConnectionTest(
      String serverIp, int port, String accessCode) async {
    final testResult = <String, dynamic>{};
    testResult['timestamp'] = DateTime.now().toIso8601String();
    testResult['serverIp'] = serverIp;
    testResult['port'] = port;

    try {
      debugPrint('Quick connection test to $serverIp:$port');

      // Step 1: Network connectivity
      testResult['networkTest'] = await testConnection(serverIp, port);
      if (!testResult['networkTest']) {
        testResult['result'] = 'FAILED';
        testResult['reason'] = 'Network connectivity failed';
        return testResult;
      }

      // Step 2: HTTP connectivity
      try {
        final response = await http.get(
          Uri.parse('http://$serverIp:$port/status'),
          headers: {'Authorization': 'Bearer $accessCode'},
        ).timeout(const Duration(seconds: 5));

        testResult['httpStatusCode'] = response.statusCode;
        testResult['httpTest'] = response.statusCode == 200;

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            testResult['serverInfo'] = data;
            testResult['result'] = 'SUCCESS';
          } catch (e) {
            testResult['result'] = 'PARTIAL';
            testResult['reason'] = 'Server responded but with invalid JSON';
          }
        } else if (response.statusCode == 401) {
          testResult['result'] = 'FAILED';
          testResult['reason'] = 'Authentication failed - invalid access code';
        } else {
          testResult['result'] = 'FAILED';
          testResult['reason'] =
              'Server returned error: ${response.statusCode}';
        }
      } catch (e) {
        testResult['httpTest'] = false;
        testResult['result'] = 'FAILED';
        testResult['reason'] = 'HTTP request failed: $e';
      }
    } catch (e) {
      testResult['result'] = 'ERROR';
      testResult['reason'] = 'Test failed: $e';
    }

    return testResult;
  }
}
