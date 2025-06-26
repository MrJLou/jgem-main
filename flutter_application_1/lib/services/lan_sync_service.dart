import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'lan_session_service.dart';

class LanSyncService {
  static const String _syncIntervalKey = 'sync_interval_minutes';
  static const String _lanServerEnabledKey = 'lan_server_enabled';
  static const String _syncEnabledKey = 'sync_enabled'; // Add this line
  static const String _serverPortKey = 'server_port';
  static const String _accessCodeKey = 'lan_access_code';
  static const int _defaultPort = 8080;

  static Timer? _syncTimer;
  static Timer? _watchdogTimer;
  static HttpServer? _server;
  static DatabaseHelper? _dbHelper;
  static String? _dbPath;
  static String? _accessCode; // For basic authentication
  static List<String> _allowedIpRanges = [];

  // WebSocket connections for real-time sync
  static final Map<String, WebSocket> _activeWebSockets = {};
  static final StreamController<Map<String, dynamic>> _syncUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for real-time updates
  static Stream<Map<String, dynamic>> get syncUpdates => _syncUpdates.stream;

  // Initialize the service
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    try {
      _dbHelper = dbHelper;

      // Register database change callback for real-time sync
      DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChangeCallback);

      // Get saved settings with error handling
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('Failed to access SharedPreferences: $e');
        throw Exception('Failed to access app settings: $e');
      }

      final syncInterval =
          prefs.getInt(_syncIntervalKey) ?? 5; // Default 5 minutes
      final lanServerEnabled = prefs.getBool(_lanServerEnabledKey) ?? false;
      final serverPort = prefs.getInt(_serverPortKey) ?? _defaultPort;

      // Get or generate access code with error handling
      try {
        _accessCode = prefs.getString(_accessCodeKey);
        if (_accessCode == null) {
          _accessCode = _generateAccessCode();
          await prefs.setString(_accessCodeKey, _accessCode!);
        }
      } catch (e) {
        debugPrint('Failed to handle access code: $e');
        _accessCode = _generateAccessCode(); // Generate fallback code
      }

      // Determine LAN IP ranges with error handling
      try {
        await _configureLanIpRanges();
      } catch (e) {
        debugPrint('Failed to configure LAN IP ranges: $e');
        // Use fallback IP ranges
        _allowedIpRanges = [
          '127.0.0',
          '192.168.0',
          '192.168.1',
          '10.0.0',
          '172.16.0'
        ];
      }

      // Export DB to accessible location with error handling
      try {
        await _setupDbForSharing();
      } catch (e) {
        debugPrint('Failed to setup database for sharing: $e');
        throw Exception('Failed to setup database sharing: $e');
      }

      // Start sync timer with error handling
      try {
        _startPeriodicSync(syncInterval);
      } catch (e) {
        debugPrint('Failed to start periodic sync: $e');
        // Continue without periodic sync
      }

      // Start LAN server if enabled with error handling
      if (lanServerEnabled) {
        try {
          await startLanServer(port: serverPort);
        } catch (e) {
          debugPrint('Failed to start LAN server: $e');
          // Continue without LAN server
        }
      }

      // Monitor for file changes with error handling
      try {
        await _startFileChangeMonitoring();
      } catch (e) {
        debugPrint('Failed to start file change monitoring: $e');
        // Continue without file monitoring
      }
    } catch (e) {
      debugPrint('LanSyncService initialization failed: $e');
      rethrow;
    }
  }

  // Generate a random access code for basic auth
  static String _generateAccessCode() {
    final random = Random.secure();
    final values = List<int>.generate(8, (i) => random.nextInt(256));
    return base64Url.encode(values).substring(0, 8);
  }

  // Configure allowed IP ranges for LAN-only access
  static Future<void> _configureLanIpRanges() async {
    _allowedIpRanges = [];

    try {
      // Get all network interfaces (WiFi and Ethernet)
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Extract network prefix (e.g., 192.168.68)
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final prefix = "${parts[0]}.${parts[1]}.${parts[2]}";
              if (!_allowedIpRanges.contains(prefix)) {
                _allowedIpRanges.add(prefix);
                debugPrint(
                    'Configured LAN access for subnet: $prefix.* (${interface.name})');
              }
            }
          }
        }
      }

      // Also try WiFi IP for backwards compatibility
      try {
        final info = NetworkInfo();
        final wifiIP = await info.getWifiIP();
        if (wifiIP != null) {
          final parts = wifiIP.split('.');
          if (parts.length == 4) {
            final prefix = "${parts[0]}.${parts[1]}.${parts[2]}";
            if (!_allowedIpRanges.contains(prefix)) {
              _allowedIpRanges.add(prefix);
              debugPrint('Configured LAN access for WiFi subnet: $prefix.*');
            }
          }
        }
      } catch (e) {
        debugPrint('WiFi IP detection failed: $e');
      }

      // Add localhost
      _allowedIpRanges.add('127.0.0');

      // If no valid IP was found, use common private network ranges
      if (_allowedIpRanges.length == 1) {
        // Only localhost was added
        _allowedIpRanges.addAll([
          '192.168.0', '192.168.1', '192.168.2',
          '192.168.68', // Common home networks
          '10.0.0', '10.0.1', '10.1.0', // Corporate networks
          '172.16.0', '172.17.0', '172.18.0' // Docker and other private ranges
        ]);
        debugPrint('Using standard private network ranges');
      }

      debugPrint('Final allowed IP ranges: $_allowedIpRanges');
    } catch (e) {
      debugPrint('Error configuring LAN ranges: $e');
      // Fallback to comprehensive private network ranges
      _allowedIpRanges = [
        '127.0.0',
        '192.168.0',
        '192.168.1',
        '192.168.2',
        '192.168.68',
        '10.0.0',
        '10.0.1',
        '10.1.0',
        '172.16.0',
        '172.17.0',
        '172.18.0'
      ];
    }
  }

  // Check if an IP is within allowed LAN ranges
  static bool _isLanIp(String ip) {
    for (final prefix in _allowedIpRanges) {
      if (ip.startsWith('$prefix.')) {
        return true;
      }
    }
    return false;
  }

  // Set up database for sharing
  static Future<void> _setupDbForSharing() async {
    try {
      Directory targetDir;

      // Platform-specific directory selection with error handling
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          // For desktop platforms, use documents directory
          targetDir = await getApplicationDocumentsDirectory();
        } else if (Platform.isAndroid) {
          // For Android, try external storage first, fallback to documents
          try {
            final externalDir = await getExternalStorageDirectory();
            targetDir = externalDir ?? await getApplicationDocumentsDirectory();
          } catch (e) {
            debugPrint(
                'External storage not available, using documents directory: $e');
            targetDir = await getApplicationDocumentsDirectory();
          }
        } else {
          // For other platforms (iOS), use documents directory
          targetDir = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        debugPrint('Failed to get application documents directory: $e');
        throw Exception('Cannot access documents directory: $e');
      }

      // Ensure the directory exists and is accessible
      try {
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } catch (e) {
        debugPrint('Failed to create target directory: $e');
        throw Exception('Cannot create or access target directory: $e');
      }

      // Path for the shared database
      _dbPath = join(targetDir.path, 'patient_management_shared.db');

      // Copy current database to shared location with error handling
      try {
        await _copyDatabaseToSharedLocation();
      } catch (e) {
        debugPrint('Failed to copy database to shared location: $e');
        // This is not critical, we can continue without the initial copy
      }

      debugPrint('DB path for LAN sharing: $_dbPath');
    } catch (e) {
      debugPrint('Error setting up DB for sharing: $e');
      rethrow;
    }
  }

  // Copy database to shared location
  static Future<void> _copyDatabaseToSharedLocation() async {
    if (_dbHelper == null) {
      debugPrint('Database helper is null, cannot copy database');
      return;
    }

    try {
      final dbPath = await _dbHelper!.currentDatabasePath;
      if (dbPath == null) {
        debugPrint('Current database path is null, cannot copy database');
        return;
      }

      if (_dbPath == null) {
        debugPrint('Target database path is null, cannot copy database');
        return;
      }

      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        debugPrint('Source database file does not exist: $dbPath');
        return;
      }

      final targetFile = File(_dbPath!);

      try {
        await sourceFile.copy(targetFile.path);
        debugPrint('Database copied to shared location: $_dbPath');
      } catch (e) {
        debugPrint('Failed to copy database file: $e');
        // Try to create an empty database file as fallback
        try {
          await targetFile.create(recursive: true);
          debugPrint('Created empty database file as fallback: $_dbPath');
        } catch (createError) {
          debugPrint('Failed to create fallback database file: $createError');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error copying database to shared location: $e');
      throw Exception('Failed to setup database sharing: $e');
    }
  } // Start periodic synchronization

  static void _startPeriodicSync(int intervalMinutes) {
    // Cancel existing timer if any
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) async {
      try {
        // Check if sync is enabled
        final prefs = await SharedPreferences.getInstance();
        final syncEnabled = prefs.getBool(_syncEnabledKey) ?? false;

        if (!syncEnabled) {
          debugPrint('Sync is disabled in settings - skipping');
          return;
        }

        debugPrint('Running scheduled database sync...');

        // Add timeout wrapper for the entire sync operation
        final success = await _dbHelper!
            .syncWithServer()
            .timeout(const Duration(seconds: 30), onTimeout: () {
          debugPrint('Sync operation timed out after 30 seconds');
          return false;
        });

        debugPrint('Sync completed with ${success ? "success" : "failure"}');
      } catch (e) {
        debugPrint('Scheduled sync error: $e');
        // Don't rethrow - just log and continue
      }
    });

    debugPrint('Periodic sync started (interval: $intervalMinutes minutes)');
  }

  // Change sync interval
  static Future<void> setSyncInterval(int minutes) async {
    if (minutes < 1) minutes = 1; // Minimum 1 minute

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, minutes);

    _startPeriodicSync(minutes);
  }

  // Enable or disable sync
  static Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);

    if (enabled) {
      final syncInterval = prefs.getInt(_syncIntervalKey) ?? 5;
      _startPeriodicSync(syncInterval);
    } else {
      _syncTimer?.cancel();
      debugPrint('Sync disabled');
    }
  }

  // Check if sync is enabled
  static Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncEnabledKey) ?? false;
  }

  // Force manual sync now
  static Future<bool> syncNow() async {
    try {
      return await _dbHelper!.syncWithServer();
    } catch (e) {
      debugPrint('Manual sync error: $e');
      return false;
    }
  }

  // Validate request authentication using access code
  static bool _validateAuth(HttpRequest request) {
    // Extract authorization header
    final authHeader = request.headers.value('authorization');
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return false;
    }

    final token = authHeader.substring(7); // Remove 'Bearer ' prefix
    return token == _accessCode;
  }

  // Check if request comes from LAN
  static bool _isLanRequest(HttpRequest request) {
    final remoteAddress = request.connectionInfo?.remoteAddress.address;
    return remoteAddress != null && _isLanIp(remoteAddress);
  }

  // Start LAN server for database access
  static Future<void> startLanServer({int port = _defaultPort}) async {
    try {
      // Stop existing server if running
      await stopLanServer();

      // Save setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lanServerEnabledKey, true);
      await prefs.setInt(_serverPortKey, port);

      // Create server - bind only to local adapter for LAN access
      // This is more secure than binding to InternetAddress.anyIPv4
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

      debugPrint('LAN server started on port $port');
      debugPrint('Access code: $_accessCode');

      // Configure server to handle requests
      _server!.listen((request) async {
        try {
          // Add CORS headers for web access
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add(
              'Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
          request.response.headers.add(
              'Access-Control-Allow-Headers', 'Content-Type, Authorization');

          // Handle OPTIONS request for CORS
          if (request.method == 'OPTIONS') {
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();
            return;
          }

          // Only accept requests from LAN IPs
          if (!_isLanRequest(request)) {
            request.response.statusCode = HttpStatus.forbidden;
            request.response.write('Access denied: Non-LAN connection');
            await request.response.close();
            debugPrint(
                'Blocked non-LAN request from: ${request.connectionInfo?.remoteAddress.address}');
            return;
          }

          final path = request.uri.path;
          final method = request.method;

          // Route requests to appropriate handlers
          if (path.startsWith('/session/')) {
            await _handleSessionRequest(request);
          } else if (path == '/ws' && method == 'GET') {
            await _handleWebSocketUpgrade(request);
          } else if (method == 'GET' && path == '/db') {
            await _handleDatabaseRequest(request);
          } else if (method == 'POST' && path == '/sync') {
            await _handleSyncRequestHTTP(request);
          } else if (method == 'GET' && path == '/changes') {
            await _handleChangesRequest(request);
          } else if (method == 'GET' && path == '/documents') {
            await _handleDocumentsRequest(request);
          } else if (method == 'POST' && path == '/documents/sync') {
            await _handleDocumentSyncRequest(request);
          } else if (method == 'GET' && path == '/status') {
            await _handleStatusRequest(request);
          } else {
            // Unknown endpoint
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Endpoint not found');
            await request.response.close();
          }
        } catch (e) {
          debugPrint('Error handling request: $e');
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal server error');
          await request.response.close();
        }
      });

      // Start watchdog timer to ensure server stays alive
      _startWatchdog();

      // Start session management on the same server
      await _initializeSessionManagement();
    } catch (e) {
      debugPrint('Failed to start LAN server: $e');
      rethrow;
    }
  }

  /// Initialize session management within the LAN server
  static Future<void> _initializeSessionManagement() async {
    try {
      // Initialize the session service without starting its own server
      // since we handle session requests through the main LAN server
      debugPrint('LanSyncService: Initializing session management (integrated mode)...');
      
      // Set the session service to integrated mode
      LanSessionService.setIntegratedMode(true);
      
      // Just initialize the session service without starting a separate server
      await LanSessionService.initialize();
      
      debugPrint('LanSyncService: Session management initialized in integrated mode');
      debugPrint('Session management integrated into LAN server');
    } catch (e) {
      debugPrint('Error initializing session management: $e');
    }
  }

  /// Handle session-related requests
  static Future<void> _handleSessionRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    // Require authentication for all session endpoints
    if (!_validateAuth(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add('WWW-Authenticate', 'Bearer');
      request.response.write('Authentication required');
      await request.response.close();
      return;
    }

    try {
      if (path == '/session/create' && method == 'POST') {
        await _handleCreateSession(request);
      } else if (path == '/session/validate' && method == 'POST') {
        await _handleValidateSession(request);
      } else if ((path == '/session/list' || path == '/sessions') && method == 'GET') {
        await _handleGetSessions(request);
      } else if (path == '/session/update' && method == 'POST') {
        await _handleUpdateActivity(request);
      } else if (path.startsWith('/session/') && method == 'DELETE') {
        final sessionId = path.split('/').last;
        await _handleEndSession(request, sessionId);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Session endpoint not found');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('Error handling session request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Session error: $e');
      await request.response.close();
    }
  }

  /// Handle WebSocket upgrade for real-time session updates
  static Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final deviceId = request.uri.queryParameters['deviceId'];
    final accessCode = request.uri.queryParameters['access_code'];

    if (deviceId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Device ID required');
      await request.response.close();
      return;
    }

    if (accessCode != _accessCode) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write('Invalid access code');
      await request.response.close();
      return;
    }

    try {
      final socket = await WebSocketTransformer.upgrade(request);
      debugPrint('WebSocket connection established for device: $deviceId');

      // Store the WebSocket connection for broadcasting
      _activeWebSockets[deviceId] = socket;

      // Send initial data to the newly connected device
      _sendInitialSyncData(socket, deviceId);

      // Handle WebSocket messages for real-time updates
      socket.listen(
        (message) {
          debugPrint('WebSocket message from $deviceId: $message');
          _handleWebSocketMessage(deviceId, message, socket);
        },
        onDone: () {
          debugPrint('WebSocket connection closed for device: $deviceId');
          _activeWebSockets.remove(deviceId);
        },
        onError: (error) {
          debugPrint('WebSocket error for device $deviceId: $error');
          _activeWebSockets.remove(deviceId);
        },
      );
    } catch (e) {
      debugPrint('Error upgrading to WebSocket: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('WebSocket upgrade failed');
      await request.response.close();
    }
  }

  /// Send initial synchronization data to newly connected device
  static void _sendInitialSyncData(WebSocket socket, String deviceId) {
    try {
      final initialData = {
        'type': 'initial_sync',
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Connected to LAN sync server',
        'server_info': {
          'access_code': _accessCode,
          'session_server_running': LanSessionService.isServerRunning,
          'active_sessions': LanSessionService.activeSessions.length,
        }
      };

      socket.add(jsonEncode(initialData));
      debugPrint('Sent initial sync data to device: $deviceId');
    } catch (e) {
      debugPrint('Error sending initial sync data to $deviceId: $e');
    }
  }

  /// Handle incoming WebSocket messages
  static void _handleWebSocketMessage(
      String deviceId, dynamic message, WebSocket socket) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'sync_request':
          _handleSyncRequest(deviceId, data, socket);
          break;
        case 'database_change':
          _handleDatabaseChangeNotification(deviceId, data, socket);
          break;
        case 'document_change':
          _handleDocumentChangeNotification(deviceId, data, socket);
          break;
        case 'session_update':
          _handleSessionUpdateMessage(deviceId, data, socket);
          break;
        case 'heartbeat':
          _handleHeartbeat(deviceId, socket);
          break;
        case 'queue_update':
          _handleQueueUpdate(deviceId, data, socket);
          break;
        default:
          debugPrint('Unknown WebSocket message type from $deviceId: $type');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message from $deviceId: $e');
    }
  }

  /// Handle sync request from client
  static void _handleSyncRequest(
      String deviceId, Map<String, dynamic> data, WebSocket socket) {
    try {
      // Broadcast to all connected devices that a sync was requested
      _broadcastToClients({
        'type': 'sync_requested',
        'source_device': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      }, excludeDevice: deviceId);

      // Send acknowledgment
      socket.add(jsonEncode({
        'type': 'sync_response',
        'status': 'acknowledged',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('Error handling sync request from $deviceId: $e');
    }
  }

  /// Handle database change notifications
  static void _handleDatabaseChangeNotification(
      String deviceId, Map<String, dynamic> data, WebSocket socket) {
    try {
      // Add source device info
      data['source_device'] = deviceId;
      data['server_timestamp'] = DateTime.now().toIso8601String();

      // Broadcast to all other connected devices
      _broadcastToClients(data, excludeDevice: deviceId);

      // Emit to local stream
      _syncUpdates.add(data);

      debugPrint(
          'Handled database change notification from $deviceId: ${data['table']} - ${data['operation']}');
    } catch (e) {
      debugPrint('Error handling database change from $deviceId: $e');
    }
  }

  /// Handle document change notifications
  static void _handleDocumentChangeNotification(
      String deviceId, Map<String, dynamic> data, WebSocket socket) {
    try {
      // Add source device info
      data['source_device'] = deviceId;
      data['server_timestamp'] = DateTime.now().toIso8601String();

      // Broadcast to all other connected devices
      _broadcastToClients(data, excludeDevice: deviceId);

      // Emit to local stream
      _syncUpdates.add(data);

      final documentType = data['documentType'] ?? 'unknown';
      final operation = data['operation'] ?? 'unknown';
      debugPrint(
          'Handled document change notification from $deviceId: $documentType - $operation');
    } catch (e) {
      debugPrint('Error handling document change from $deviceId: $e');
    }
  }

  /// Handle session update messages
  static void _handleSessionUpdateMessage(
      String deviceId, Map<String, dynamic> data, WebSocket socket) {
    try {
      // Broadcast session updates to all devices
      _broadcastToClients({
        'type': 'session_update',
        'source_device': deviceId,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('Handled session update from $deviceId');
    } catch (e) {
      debugPrint('Error handling session update from $deviceId: $e');
    }
  }

  /// Handle heartbeat messages
  static void _handleHeartbeat(String deviceId, WebSocket socket) {
    try {
      socket.add(jsonEncode({
        'type': 'heartbeat_response',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('Error handling heartbeat from $deviceId: $e');
    }
  }

  /// Handle queue update messages
  static void _handleQueueUpdate(
      String deviceId, Map<String, dynamic> data, WebSocket socket) {
    try {
      // Add source device info
      data['source_device'] = deviceId;
      data['server_timestamp'] = DateTime.now().toIso8601String();

      // Broadcast to all other connected devices
      _broadcastToClients({
        'type': 'queue_update',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      }, excludeDevice: deviceId);

      // Emit to local stream
      _syncUpdates.add({
        'type': 'queue_update',
        'data': data,
      });

      debugPrint('Handled queue update from $deviceId');
    } catch (e) {
      debugPrint('Error handling queue update from $deviceId: $e');
    }
  }

  /// Broadcast message to all connected WebSocket clients
  static void _broadcastToClients(Map<String, dynamic> message,
      {String? excludeDevice}) {
    final messageJson = jsonEncode(message);

    for (final entry in _activeWebSockets.entries) {
      if (excludeDevice != null && entry.key == excludeDevice) continue;

      try {
        entry.value.add(messageJson);
      } catch (e) {
        debugPrint('Error broadcasting to device ${entry.key}: $e');
        // Remove dead connection
        _activeWebSockets.remove(entry.key);
      }
    }
  }

  /// Notify clients of database changes
  static Future<void> notifyDatabaseChange(
      String table, String operation, String recordId,
      {Map<String, dynamic>? data}) async {
    if (_activeWebSockets.isEmpty) return;

    final changeNotification = {
      'type': 'database_change',
      'table': table,
      'operation': operation,
      'record_id': recordId,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _broadcastToClients(changeNotification);
    _syncUpdates.add(changeNotification);
  }

  /// Notify clients of session changes
  static Future<void> notifySessionChange(
      String type, Map<String, dynamic> sessionData) async {
    if (_activeWebSockets.isEmpty && !LanSessionService.isServerRunning) return;

    final sessionNotification = {
      'type': 'session_change',
      'session_type': type,
      'data': sessionData,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _broadcastToClients(sessionNotification);
    _syncUpdates.add(sessionNotification);
  }

  /// Stop the LAN server
  static Future<void> stopLanServer() async {
    try {
      // Reset session service integrated mode when stopping
      LanSessionService.setIntegratedMode(false);
      
      // Only stop session service if it was running its own server
      if (LanSessionService.isServerRunning) {
        await LanSessionService.stopSessionServer();
      }

      // Close all WebSocket connections
      for (final socket in _activeWebSockets.values) {
        try {
          await socket.close();
        } catch (e) {
          debugPrint('Error closing WebSocket: $e');
        }
      }
      _activeWebSockets.clear();

      // Stop the server
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }

      // Cancel the watchdog timer
      _watchdogTimer?.cancel();
      _watchdogTimer = null;

      // Update settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lanServerEnabledKey, false);

      debugPrint('LAN server stopped');
    } catch (e) {
      debugPrint('Error stopping LAN server: $e');
    }
  }

  /// Handle session creation requests
  static Future<void> _handleCreateSession(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final username = data['username'] as String?;
      final deviceId = data['deviceId'] as String?;
      final deviceName = data['deviceName'] as String?;
      final accessLevel = data['accessLevel'] as String?;

      if (username == null ||
          deviceId == null ||
          deviceName == null ||
          accessLevel == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing required fields');
        await request.response.close();
        return;
      }

      // Use LanSessionService to create session
      final session = await LanSessionService.registerUserSession(
        username: username,
        deviceId: deviceId,
        deviceName: deviceName,
        accessLevel: accessLevel,
        ipAddress: request.connectionInfo?.remoteAddress.address,
      );

      if (session != null) {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': true,
          'session': session.toMap(),
        }));
      } else {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Failed to create session');
      }
    } catch (e) {
      debugPrint('Error handling create session: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    }
    await request.response.close();
  }

  /// Handle session validation requests
  static Future<void> _handleValidateSession(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final sessionId = data['sessionId'] as String?;
      final token = data['token'] as String?;

      if (sessionId == null || token == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing sessionId or token');
        await request.response.close();
        return;
      }

      final session = LanSessionService.validateSession(sessionId, token);

      if (session != null) {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'valid': true,
          'session': session.toMap(),
        }));
      } else {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('Invalid session');
      }
    } catch (e) {
      debugPrint('Error handling validate session: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    }
    await request.response.close();
  }

  /// Handle get sessions requests
  static Future<void> _handleGetSessions(HttpRequest request) async {
    try {
      final sessions = LanSessionService.activeSessions.values
          .map((session) => session.toMap())
          .toList();

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'sessions': sessions,
      }));
    } catch (e) {
      debugPrint('Error handling get sessions: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    }
    await request.response.close();
  }

  /// Handle session activity update requests
  static Future<void> _handleUpdateActivity(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final sessionId = data['sessionId'] as String?;

      if (sessionId == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing sessionId');
        await request.response.close();
        return;
      }

      await LanSessionService.updateSessionActivity(sessionId);

      request.response.statusCode = HttpStatus.ok;
      request.response.write('Activity updated');
    } catch (e) {
      debugPrint('Error handling update activity: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    }
    await request.response.close();
  }

  /// Handle end session requests
  static Future<void> _handleEndSession(
      HttpRequest request, String sessionId) async {
    try {
      final success = await LanSessionService.endUserSession(sessionId);

      if (success) {
        request.response.statusCode = HttpStatus.ok;
        request.response.write('Session ended');
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Session not found');
      }
    } catch (e) {
      debugPrint('Error handling end session: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    }
    await request.response.close();
  }

  /// Database change callback - triggers real-time sync notifications
  static Future<void> _onDatabaseChangeCallback(String table, String operation,
      String recordId, Map<String, dynamic>? data) async {
    try {
      // Immediate notification for real-time sync (< 1 second delay)
      await notifyDatabaseChange(table, operation, recordId, data: data);
      
      // Special handling for document changes with immediate broadcast
      if (table == 'generated_documents' && data != null) {
        await notifyDocumentChange(
          data['documentType'] ?? 'unknown',
          recordId,
          operation,
          documentData: data,
        );
        
        // Additional immediate notification for critical document operations
        if (operation == 'insert' && _activeWebSockets.isNotEmpty) {
          final urgentNotification = {
            'type': 'urgent_document_sync',
            'documentType': data['documentType'],
            'documentId': recordId,
            'operation': operation,
            'priority': 'high',
            'timestamp': DateTime.now().toIso8601String(),
          };
          _broadcastToClients(urgentNotification);
          debugPrint('Sent urgent document sync notification for $recordId');
        }
      }
      
      // Immediate broadcast for critical table changes
      final criticalTables = [
        'patient_bills',
        'payments', 
        'active_patient_queue',
        'generated_documents'
      ];
      
      if (criticalTables.contains(table) && _activeWebSockets.isNotEmpty) {
        final urgentNotification = {
          'type': 'urgent_sync',
          'table': table,
          'operation': operation,
          'record_id': recordId,
          'priority': 'high',
          'timestamp': DateTime.now().toIso8601String(),
        };
        _broadcastToClients(urgentNotification);
        debugPrint('Sent urgent sync notification for $table:$recordId');
      }
      
    } catch (e) {
      debugPrint('Error in database change callback: $e');
    }
  }

  /// Start file change monitoring (placeholder)
  static Future<void> _startFileChangeMonitoring() async {
    // File change monitoring implementation
    debugPrint('File change monitoring started');
  }

  /// Start server watchdog
  static void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_server == null) {
        debugPrint('Watchdog: Server not running, restarting...');
        // Could restart server here if needed
      }
    });
  }

  /// Handle database access requests
  static Future<void> _handleDatabaseRequest(HttpRequest request) async {
    if (!_validateAuth(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add('WWW-Authenticate', 'Bearer');
      request.response.write('Authentication required');
      await request.response.close();
      return;
    }

    try {
      if (_dbPath == null || !File(_dbPath!).existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Database file not found');
        await request.response.close();
        return;
      }

      final dbFile = File(_dbPath!);
      request.response.headers.contentType =
          ContentType('application', 'octet-stream');
      request.response.headers
          .add('Content-Disposition', 'attachment; filename="database.db"');

      await dbFile.openRead().pipe(request.response);
    } catch (e) {
      debugPrint('Error handling database request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error accessing database');
      await request.response.close();
    }
  }

  /// Handle HTTP sync requests
  static Future<void> _handleSyncRequestHTTP(HttpRequest request) async {
    if (!_validateAuth(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add('WWW-Authenticate', 'Bearer');
      request.response.write('Authentication required');
      await request.response.close();
      return;
    }

    try {
      final success = await syncNow();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': success,
        'message': success ? 'Sync completed' : 'Sync failed',
      }));
    } catch (e) {
      debugPrint('Error handling sync request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Sync error: $e');
    }
    await request.response.close();
  }

  /// Handle changes request
  static Future<void> _handleChangesRequest(HttpRequest request) async {
    if (!_validateAuth(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add('WWW-Authenticate', 'Bearer');
      request.response.write('Authentication required');
      await request.response.close();
      return;
    }

    try {
      final pendingChanges = await getPendingChanges();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'pendingChanges': pendingChanges,
      }));
    } catch (e) {
      debugPrint('Error handling changes request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    }
    await request.response.close();
  }

  /// Handle status request
  static Future<void> _handleStatusRequest(HttpRequest request) async {
    try {
      final info = await getConnectionInfo();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'running',
        'info': info,
      }));
    } catch (e) {
      debugPrint('Error handling status request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Status error: $e');
    }
    await request.response.close();
  }

  /// Regenerate access code for LAN server
  static Future<String> regenerateAccessCode() async {
    try {
      _accessCode = _generateAccessCode();

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessCodeKey, _accessCode!);

      debugPrint('Access code regenerated: $_accessCode');
      return _accessCode!;
    } catch (e) {
      debugPrint('Error regenerating access code: $e');
      throw Exception('Failed to regenerate access code: $e');
    }
  }

  /// Get database browser instructions
  static Future<Map<String, dynamic>> getDbBrowserInstructions() async {
    try {
      final interfaces = await NetworkInterface.list();
      final List<String> ipAddresses = [];

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ipAddresses.add(addr.address);
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final serverPort = prefs.getInt(_serverPortKey) ?? _defaultPort;

      return {
        'accessCode': _accessCode ?? 'Not generated',
        'serverPort': serverPort,
        'ipAddresses': ipAddresses,
        'dbEndpoint': '/db',
        'statusEndpoint': '/status',
        'syncEndpoint': '/sync',
        'instructions': [
          '1. Connect to the same WiFi/LAN network as this device',
          '2. Use any of the IP addresses listed above',
          '3. Access the database via: http://[IP]:$serverPort/db',
          '4. Include Authorization header: Bearer ${_accessCode ?? '[ACCESS_CODE]'}',
          '5. Check server status: http://[IP]:$serverPort/status',
        ],
        'curlExample':
            'curl -H "Authorization: Bearer ${_accessCode ?? '[ACCESS_CODE]'}" http://[IP]:$serverPort/db',
      };
    } catch (e) {
      debugPrint('Error getting DB browser instructions: $e');
      return {
        'error': 'Failed to get instructions: $e',
        'accessCode': _accessCode ?? 'Not available',
        'serverPort': _defaultPort,
        'ipAddresses': <String>[],
        'instructions': ['Error retrieving network information'],
      };
    }
  }

  /// Get access code for display
  static String? getAccessCode() {
    return _accessCode;
  }

  /// Get connection information for UI display
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    try {
      // Get network interfaces for IP addresses
      final List<String> ipAddresses = [];
      try {
        final interfaces = await NetworkInterface.list();
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ipAddresses.add(addr.address);
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to get network interfaces: $e');
      }

      // Get settings from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lanServerEnabled = prefs.getBool(_lanServerEnabledKey) ?? false;
      final port = prefs.getInt(_serverPortKey) ?? _defaultPort;

      return {
        'lanServerEnabled': lanServerEnabled,
        'accessCode': _accessCode ?? 'Not generated',
        'ipAddresses': ipAddresses,
        'port': port,
        'dbPath': _dbPath ?? 'Not available',
        'allowedNetworks': _allowedIpRanges,
        'serverRunning': _server != null,
      };
    } catch (e) {
      debugPrint('Error getting connection info: $e');
      return {
        'lanServerEnabled': false,
        'accessCode': 'Error',
        'ipAddresses': <String>[],
        'port': _defaultPort,
        'dbPath': 'Error',
        'allowedNetworks': <String>[],
        'serverRunning': false,
      };
    }
  }

  /// Get pending changes count
  static Future<int> getPendingChanges() async {
    try {
      if (_dbHelper == null) return 0;
      final changes = await _dbHelper!.getPendingChanges();
      return changes.length;
    } catch (e) {
      debugPrint('Error getting pending changes: $e');
      return 0;
    }
  }

  /// Handle documents list request
  static Future<void> _handleDocumentsRequest(HttpRequest request) async {
    if (!_validateAuth(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add('WWW-Authenticate', 'Bearer');
      request.response.write('Authentication required');
      await request.response.close();
      return;
    }

    try {
      if (_dbHelper == null) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Database helper not initialized');
        await request.response.close();
        return;
      }

      // Get unsynced documents
      final unsyncedDocuments =
          await _dbHelper!.documentTrackingService.getUnsyncedDocuments();

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'unsyncedDocuments': unsyncedDocuments,
        'count': unsyncedDocuments.length,
      }));
    } catch (e) {
      debugPrint('Error handling documents request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Documents request error: $e');
    }
    await request.response.close();
  }

  /// Handle document sync request (upload/download documents)
  static Future<void> _handleDocumentSyncRequest(HttpRequest request) async {
    if (!_validateAuth(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add('WWW-Authenticate', 'Bearer');
      request.response.write('Authentication required');
      await request.response.close();
      return;
    }

    try {
      if (_dbHelper == null) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Database helper not initialized');
        await request.response.close();
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final syncType = data['type'] as String?;

      if (syncType == 'download') {
        // Client wants to download documents
        final lastSyncTimestamp = data['lastSyncTimestamp'] as String?;

        final documents = await _getDocumentsSince(lastSyncTimestamp);

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': true,
          'documents': documents,
          'syncTimestamp': DateTime.now().toIso8601String(),
        }));
      } else if (syncType == 'upload') {
        // Client is uploading documents
        final documentsData = data['documents'] as List<dynamic>?;

        if (documentsData != null) {
          await _processUploadedDocuments(documentsData);

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'message': 'Documents synced successfully',
            'processed': documentsData.length,
          }));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Invalid documents data');
        }
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Invalid sync type');
      }
    } catch (e) {
      debugPrint('Error handling document sync request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Document sync error: $e');
    }
    await request.response.close();
  }

  /// Get documents modified since a specific timestamp
  static Future<List<Map<String, dynamic>>> _getDocumentsSince(
      String? lastSyncTimestamp) async {
    if (_dbHelper == null) return [];

    try {
      final db = await _dbHelper!.database;

      String whereClause = 'synced = 0';
      List<dynamic> whereArgs = [];

      if (lastSyncTimestamp != null && lastSyncTimestamp.isNotEmpty) {
        whereClause += ' OR generatedAt > ?';
        whereArgs.add(lastSyncTimestamp);
      }

      final results = await db.query(
        'generated_documents',
        where: whereClause,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'generatedAt DESC',
      );

      return results;
    } catch (e) {
      debugPrint('Error getting documents since timestamp: $e');
      return [];
    }
  }

  /// Process uploaded documents from client devices
  static Future<void> _processUploadedDocuments(
      List<dynamic> documentsData) async {
    if (_dbHelper == null) return;

    try {
      final db = await _dbHelper!.database;

      for (final docData in documentsData) {
        final docMap = docData as Map<String, dynamic>;
        final documentId = docMap['id'] as String?;

        if (documentId == null) continue;

        // Check if document already exists
        final existing = await db.query(
          'generated_documents',
          where: 'id = ?',
          whereArgs: [documentId],
          limit: 1,
        );

        if (existing.isEmpty) {
          // Insert new document
          await db.insert('generated_documents', docMap);
          await _dbHelper!
              .logChange('generated_documents', documentId, 'insert', data: {
            'documentType': docMap['documentType'],
            'fileName': docMap['fileName'],
            'fileSize': docMap['fileSize'],
          });

          debugPrint('Synced new document: $documentId');
        } else {
          // Update existing document if newer
          final existingTimestamp = existing.first['generatedAt'] as String;
          final newTimestamp = docMap['generatedAt'] as String;

          if (newTimestamp.compareTo(existingTimestamp) > 0) {
            await db.update(
              'generated_documents',
              docMap,
              where: 'id = ?',
              whereArgs: [documentId],
            );
            await _dbHelper!
                .logChange('generated_documents', documentId, 'update', data: {
              'documentType': docMap['documentType'],
              'fileName': docMap['fileName'],
              'fileSize': docMap['fileSize'],
            });

            debugPrint('Updated document: $documentId');
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing uploaded documents: $e');
      rethrow;
    }
  }

  /// Notify clients of document changes
  static Future<void> notifyDocumentChange(
      String documentType, String documentId, String operation,
      {Map<String, dynamic>? documentData}) async {
    if (_activeWebSockets.isEmpty) return;

    final documentNotification = {
      'type': 'document_change',
      'documentType': documentType,
      'documentId': documentId,
      'operation': operation,
      'data': documentData,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _broadcastToClients(documentNotification);
    _syncUpdates.add(documentNotification);

    debugPrint(
        'Notified clients of document change: $documentType - $operation');
  }
}
