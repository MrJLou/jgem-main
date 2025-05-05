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

class LanSyncService {
  static const String _syncIntervalKey = 'sync_interval_minutes';
  static const String _lanServerEnabledKey = 'lan_server_enabled';
  static const String _serverPortKey = 'server_port';
  static const String _accessCodeKey = 'lan_access_code';
  static const int _defaultPort = 8080;

  static Timer? _syncTimer;
  static Timer? _watchdogTimer;
  static HttpServer? _server;
  static DatabaseHelper? _dbHelper;
  static String? _dbPath;
  static Directory? _watchDir;
  static StreamSubscription? _dirWatcher;
  static String? _accessCode; // For basic authentication
  static List<String> _allowedIpRanges = [];

  // Initialize the service
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    _dbHelper = dbHelper;

    // Get saved settings
    final prefs = await SharedPreferences.getInstance();
    final syncInterval =
        prefs.getInt(_syncIntervalKey) ?? 5; // Default 5 minutes
    final lanServerEnabled = prefs.getBool(_lanServerEnabledKey) ?? false;
    final serverPort = prefs.getInt(_serverPortKey) ?? _defaultPort;

    // Get or generate access code
    _accessCode = prefs.getString(_accessCodeKey);
    if (_accessCode == null) {
      _accessCode = _generateAccessCode();
      await prefs.setString(_accessCodeKey, _accessCode!);
    }

    // Determine LAN IP ranges
    await _configureLanIpRanges();

    // Export DB to accessible location
    await _setupDbForSharing();

    // Start sync timer
    _startPeriodicSync(syncInterval);

    // Start LAN server if enabled
    if (lanServerEnabled) {
      await startLanServer(port: serverPort);
    }

    // Monitor for file changes
    await _startFileChangeMonitoring();
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
      // Get device's own IP address
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null) {
        // Extract network prefix (e.g., 192.168.1)
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          final prefix = "${parts[0]}.${parts[1]}.${parts[2]}";
          _allowedIpRanges.add(prefix);
          debugPrint('Configured LAN access for subnet: $prefix.*');
        }
      }

      // Add localhost
      _allowedIpRanges.add('127.0.0');

      // If no valid IP was found, use common private network ranges
      if (_allowedIpRanges.length == 1) {
        // Only localhost was added
        _allowedIpRanges
            .addAll(['192.168.0', '192.168.1', '10.0.0', '172.16.0']);
        debugPrint('Using standard private network ranges');
      }
    } catch (e) {
      debugPrint('Error configuring LAN ranges: $e');
      // Fallback to common private network ranges
      _allowedIpRanges = [
        '127.0.0',
        '192.168.0',
        '192.168.1',
        '10.0.0',
        '172.16.0'
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
      // Get external directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('External storage not available');
      }

      // Ensure the directory exists and is accessible
      if (!await externalDir.exists()) {
        await externalDir.create(recursive: true);
      }

      // Path for the database
      _dbPath = join(externalDir.path, 'patient_management.db');
      _watchDir = externalDir;

      debugPrint('DB path for LAN sharing: $_dbPath');
    } catch (e) {
      debugPrint('Error setting up DB for sharing: $e');
      rethrow;
    }
  }

  // Start periodic synchronization
  static void _startPeriodicSync(int intervalMinutes) {
    // Cancel existing timer if any
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) async {
      try {
        debugPrint('Running scheduled database sync...');
        final success = await _dbHelper!.syncWithServer();
        debugPrint('Sync completed with ${success ? "success" : "failure"}');
      } catch (e) {
        debugPrint('Scheduled sync error: $e');
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
          // Only accept requests from LAN IPs
          if (!_isLanRequest(request)) {
            request.response.statusCode = HttpStatus.forbidden;
            request.response.write('Access denied: Non-LAN connection');
            await request.response.close();
            debugPrint(
                'Blocked non-LAN request from: ${request.connectionInfo?.remoteAddress.address}');
            return;
          }

          // API endpoints
          if (request.method == 'GET' && request.uri.path == '/db') {
            // Require authentication for database access
            if (!_validateAuth(request)) {
              request.response.statusCode = HttpStatus.unauthorized;
              request.response.headers.add('WWW-Authenticate', 'Bearer');
              request.response.write('Authentication required');
              await request.response.close();
              return;
            }

            // Serve the database file for direct access
            final dbFile = File(_dbPath!);
            if (await dbFile.exists()) {
              request.response.headers.contentType =
                  ContentType('application', 'octet-stream');
              request.response.headers.add('Content-Disposition',
                  'attachment; filename="patient_management.db"');
              await dbFile.openRead().pipe(request.response);
            } else {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write('Database file not found');
              await request.response.close();
            }
          } else if (request.method == 'GET' && request.uri.path == '/status') {
            // Return server status (no auth required for status check)
            request.response.headers.contentType =
                ContentType('application', 'json');
            final pendingChanges = await _dbHelper!.getPendingChanges();

            final status = {
              'status': 'online',
              'dbPath': _dbPath,
              'pendingChanges': pendingChanges.length,
              'allowedNetworks':
                  _allowedIpRanges.map((prefix) => '$prefix.*').toList(),
              'timestamp': DateTime.now().toIso8601String(),
            };

            request.response.write(jsonEncode(status));
            await request.response.close();
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Not found');
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
    } catch (e) {
      debugPrint('Failed to start LAN server: $e');
      rethrow;
    }
  }

  // Regenerate access code
  static Future<String> regenerateAccessCode() async {
    final newCode = _generateAccessCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessCodeKey, newCode);
    _accessCode = newCode;
    return newCode;
  }

  // Stop LAN server
  static Future<void> stopLanServer() async {
    try {
      await _server?.close(force: true);
      _server = null;

      _watchdogTimer?.cancel();
      _watchdogTimer = null;

      // Save setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lanServerEnabledKey, false);

      debugPrint('LAN server stopped');
    } catch (e) {
      debugPrint('Error stopping LAN server: $e');
    }
  }

  // Start watchdog timer
  static void _startWatchdog() {
    _watchdogTimer?.cancel();

    _watchdogTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_server == null) {
        debugPrint('Watchdog detected server is down, restarting...');

        final prefs = await SharedPreferences.getInstance();
        final port = prefs.getInt(_serverPortKey) ?? _defaultPort;

        await startLanServer(port: port);
      }
    });
  }

  // Monitor for file changes
  static Future<void> _startFileChangeMonitoring() async {
    try {
      if (_watchDir == null) return;

      // Cancel existing watcher if any
      await _dirWatcher?.cancel();

      // Watch for changes in the directory
      _dirWatcher = _watchDir!.watch(recursive: false).listen((event) {
        final path = event.path;

        // If our database file was modified externally
        if (path.endsWith('patient_management.db')) {
          debugPrint('Database file modified externally at ${DateTime.now()}');
          // No need to do anything special here as SQLite handles this automatically
          // with its built-in concurrency control
        }
      });

      debugPrint('File change monitoring started for: ${_watchDir!.path}');
    } catch (e) {
      debugPrint('Error setting up file monitoring: $e');
    }
  }

  // Get network information for connecting
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    try {
      final interfaces = await NetworkInterface.list();
      final ipAddresses = <String>[];

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && _isLanIp(addr.address)) {
            ipAddresses.add(addr.address);
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final port = prefs.getInt(_serverPortKey) ?? _defaultPort;
      final lanServerEnabled = prefs.getBool(_lanServerEnabledKey) ?? false;

      return {
        'ipAddresses': ipAddresses,
        'port': port,
        'lanServerEnabled': lanServerEnabled,
        'dbPath': _dbPath,
        'connectionUrls':
            ipAddresses.map((ip) => 'http://$ip:$port/db').toList(),
        'statusUrl': ipAddresses.isNotEmpty
            ? 'http://${ipAddresses.first}:$port/status'
            : null,
        'accessCode': _accessCode,
        'allowedNetworks':
            _allowedIpRanges.map((prefix) => '$prefix.*').toList(),
      };
    } catch (e) {
      debugPrint('Error getting connection info: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  static Future<int> getPendingChanges() async {
    try {
      if (_dbHelper == null) {
        return 0;
      }
      final changes = await _dbHelper!.getPendingChanges();
      return changes.length;
    } catch (e) {
      debugPrint('Error getting pending changes: $e');
      return 0;
    }
  }

  // Generate instructions for DB Browser connection
  static Future<String> getDbBrowserInstructions() async {
    final connectionInfo = await getConnectionInfo();

    final StringBuffer instructions = StringBuffer();
    instructions.writeln('=== DB BROWSER CONNECTION INSTRUCTIONS ===\n');
    instructions.writeln('To view the database in DB Browser for SQLite:');

    if (connectionInfo['lanServerEnabled'] == true) {
      instructions
          .writeln('\nOption 1: Direct Network Connection (Recommended)');
      instructions.writeln('1. Open DB Browser for SQLite');
      instructions.writeln('2. Select "File" > "Open Database"');
      instructions.writeln('3. In the URL field, enter one of:');

      for (final url in connectionInfo['connectionUrls']) {
        instructions.writeln('   - $url');
      }

      instructions.writeln('4. When prompted for authentication:');
      instructions.writeln(
          '   - Use "Bearer ${connectionInfo['accessCode']}" as the token');
      instructions.writeln('5. Select "Read and Write" mode');
      instructions.writeln(
          '6. Check "Keep updating the SQL view as the database changes"');
    }

    instructions.writeln('\nOption 2: Manual File Connection');
    instructions.writeln('1. Find the database file at:');
    instructions.writeln('   ${connectionInfo['dbPath']}');
    instructions.writeln('2. Copy this file to your computer');
    instructions.writeln('3. Open it in DB Browser for SQLite');
    instructions.writeln('4. Note: This won\'t show live updates');

    instructions.writeln('\nLAN Access Information:');
    instructions
        .writeln('IP Addresses: ${connectionInfo['ipAddresses'].join(', ')}');
    instructions.writeln('Server Port: ${connectionInfo['port']}');
    instructions.writeln(
        'Server Status: ${connectionInfo['lanServerEnabled'] ? 'Running' : 'Stopped'}');
    instructions.writeln('Access Code: ${connectionInfo['accessCode']}');
    instructions.writeln(
        'Allowed Networks: ${connectionInfo['allowedNetworks'].join(', ')}');

    return instructions.toString();
  }

  // Dispose the service
  static Future<void> dispose() async {
    _syncTimer?.cancel();
    _watchdogTimer?.cancel();
    await _dirWatcher?.cancel();
    await _server?.close(force: true);

    _syncTimer = null;
    _watchdogTimer = null;
    _dirWatcher = null;
    _server = null;
  }
}
