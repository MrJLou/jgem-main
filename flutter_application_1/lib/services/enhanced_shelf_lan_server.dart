import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Enhanced Shelf server for HTTP database operations
class EnhancedShelfServer {
  static const String _accessCodeKey = 'shelf_access_code';
  static const int _defaultPort = 8080;

  static HttpServer? _server;
  static DatabaseHelper? _dbHelper;
  static String? _accessCode;
  static List<String> _allowedIpRanges = [];
  static bool _isRunning = false;
  static int _currentPort = _defaultPort;

  // Database change tracking
  static DateTime _lastSyncTime = DateTime.now();
  static final Map<String, DateTime> _tableLastModified = {};
  
  // Change log for tracking database changes since timestamp
  static final List<Map<String, dynamic>> _changeLog = [];

  // WebSocket connections for real-time sync
  static final Set<WebSocketChannel> _activeWebSocketConnections = {};
  static final StreamController<Map<String, dynamic>> _syncUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  static bool get isRunning => _isRunning;
  static String? get accessCode => _accessCode;
  static List<String> get allowedIpRanges => List.from(_allowedIpRanges);
  static Stream<Map<String, dynamic>> get syncUpdates => _syncUpdates.stream;
  static int get activeWebSocketConnections => _activeWebSocketConnections.length;

  /// Initialize the server
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    try {
      _dbHelper = dbHelper;
      
      // Load or generate access code
      final prefs = await SharedPreferences.getInstance();
      _accessCode = prefs.getString(_accessCodeKey) ?? _generateAccessCode();
      await prefs.setString(_accessCodeKey, _accessCode!);
      
      // Configure allowed IP ranges
      await _configureLanIpRanges();
      
      debugPrint('Enhanced Shelf Server initialized with access code: $_accessCode');
    } catch (e) {
      debugPrint('Enhanced Shelf Server initialization failed: $e');
      rethrow;
    }
  }

  /// Start the server
  static Future<bool> startServer({int port = _defaultPort}) async {
    if (_isRunning) {
      debugPrint('Server already running on port $_currentPort');
      return true;
    }

    try {
      _currentPort = port;
      
      // Detect server IP BEFORE starting the server
      final detectedIp = await _getActualServerIp();
      
      // Database change callback is now handled in main.dart to prevent conflicts
      // DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      
      // Create router with endpoints
      final router = _createRouter();
      
      // Create handler with middleware
      final handler = const Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(_authMiddleware())
          .addMiddleware(_lanOnlyMiddleware())
          .addHandler(router.call);

      // Start HTTP server on all interfaces (0.0.0.0)
      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      _isRunning = true;
      
      // Enhanced startup logging
      debugPrint('');
      debugPrint('🚀 === ENHANCED SHELF SERVER STARTED ===');
      debugPrint('✓ Server running on port: $port');
      debugPrint('✓ Server IP for clients: $detectedIp');
      debugPrint('✓ Access code: $_accessCode');
      debugPrint('✓ WebSocket endpoint: /ws');
      debugPrint('✓ Full WebSocket URL: ws://$detectedIp:$port/ws');
      debugPrint('✓ HTTP API URL: http://$detectedIp:$port');
      debugPrint('');
      debugPrint('📱 For client devices to connect:');
      debugPrint('   Server IP: $detectedIp');
      debugPrint('   Port: $port');
      debugPrint('   Access Code: $_accessCode');
      debugPrint('==========================================');
      debugPrint('');
      
      return true;
    } catch (e) {
      debugPrint('Failed to start Enhanced Shelf Server: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stop the server
  static Future<void> stopServer() async {
    try {
      // Close all WebSocket connections
      for (final connection in _activeWebSocketConnections) {
        await connection.sink.close();
      }
      _activeWebSocketConnections.clear();
      
      await _server?.close(force: true);
      _server = null;
      _isRunning = false;
      
      // Clear database callback
      DatabaseHelper.clearDatabaseChangeCallback();
      
      debugPrint('Enhanced Shelf Server stopped');
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }

  /// Create router with all endpoints
  static Router _createRouter() {
    final router = Router();

    // Database sync endpoints
    router.get('/status', _handleStatus);
    router.get('/db/download', _handleDatabaseDownload);
    router.post('/db/sync', _handleDatabaseSync);
    router.get('/db/changes/<since>', _handleDatabaseChanges);
    
    // Table-specific endpoints
    router.get('/tables/<table>', _handleTableData);
    router.post('/tables/<table>/sync', _handleTableSync);

    // WebSocket endpoint using shelf_web_socket
    router.get('/ws', webSocketHandler(_handleWebSocketConnection));

    return router;
  }

  /// Database change callback (public method for external access)
  static Future<void> onDatabaseChange(String table, String operation, String recordId, Map<String, dynamic>? data) async {
    await _onDatabaseChange(table, operation, recordId, data);
  }

  /// Database change callback (internal)
  static Future<void> _onDatabaseChange(String table, String operation, String recordId, Map<String, dynamic>? data) async {
    debugPrint('Database change detected: $table.$operation for record $recordId');
    
    final change = {
      'table': table,
      'operation': operation,
      'recordId': recordId,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Update last modified time for table
    _tableLastModified[table] = DateTime.now();
    _lastSyncTime = DateTime.now();
    
    // Add change to log for tracking
    _changeLog.add(change);
    
    // Keep only last 1000 changes to prevent memory issues
    if (_changeLog.length > 1000) {
      _changeLog.removeAt(0);
    }
    
    // Notify WebSocket clients of the change
    _broadcastWebSocketChange(change);
  }

  /// Handle database download
  static Future<Response> _handleDatabaseDownload(Request request) async {
    try {
      if (_dbHelper == null) {
        return Response.internalServerError(body: 'Database not initialized');
      }

      final db = await _dbHelper!.database;
      // COMPLETE table list - ALL database tables for full sync
      final tables = [
        'patients', 
        'appointments', 
        'medical_records', 
        'users', 
        'clinic_services', 
        'user_sessions',
        'active_patient_queue',
        'patient_history',
        'patient_bills',
        'bill_items',
        'payments',
        'user_activity_log',
        'patient_queue'
      ];
      final data = <String, List<Map<String, dynamic>>>{};
      
      for (final table in tables) {
        try {
          final result = await db.query(table);
          data[table] = result;
          debugPrint('Synced ${result.length} records from table $table');
        } catch (e) {
          debugPrint('Error querying table $table: $e');
          data[table] = [];
        }
      }
      
      return Response.ok(
        jsonEncode({
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
          'lastSyncTime': _lastSyncTime.toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error in database download: $e');
      return Response.internalServerError(body: 'Database download failed');
    }
  }

  /// Handle database sync
  static Future<Response> _handleDatabaseSync(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final changes = data['changes'] as List<dynamic>?;
      if (changes != null) {
        await _handleUploadChanges(changes);
      }
      
      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'Sync completed',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error in database sync: $e');
      return Response.internalServerError(body: 'Sync failed');
    }
  }

  /// Handle uploaded changes from clients
  static Future<void> _handleUploadChanges(List<dynamic>? changes) async {
    if (changes == null || _dbHelper == null) return;
    
    try {
      final db = await _dbHelper!.database;
      
      for (final change in changes) {
        final changeMap = change as Map<String, dynamic>;
        final table = changeMap['table'] as String;
        final operation = changeMap['operation'] as String;
        final data = changeMap['data'] as Map<String, dynamic>?;
        
        switch (operation.toLowerCase()) {
          case 'insert':
            if (data != null) {
              await db.insert(table, data);
            }
            break;
          case 'update':
            if (data != null) {
              final id = data['id'];
              if (id != null) {
                await db.update(table, data, where: 'id = ?', whereArgs: [id]);
              }
            }
            break;
          case 'delete':
            final recordId = changeMap['recordId'];
            if (recordId != null) {
              await db.delete(table, where: 'id = ?', whereArgs: [recordId]);
            }
            break;
        }
      }
    } catch (e) {
      debugPrint('Error applying uploaded changes: $e');
    }
  }

  /// Handle status endpoint
  static Response _handleStatus(Request request) {
    final status = {
      'status': 'running',
      'timestamp': DateTime.now().toIso8601String(),
      'version': '2.0.0',
      'accessCode': _accessCode,
      'activeConnections': _activeWebSocketConnections.length,
      'webSocketIntegrated': true,
      'webSocketEndpoint': '/ws',
      'lastSyncTime': _lastSyncTime.toIso8601String(),
      'allowedIpRanges': _allowedIpRanges,
    };
    
    return Response.ok(
      jsonEncode(status),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handle database changes since timestamp
  static Future<Response> _handleDatabaseChanges(Request request) async {
    try {
      final since = request.params['since'];
      if (since == null) {
        return Response.badRequest(body: 'Missing since parameter');
      }
      
      // Parse the since timestamp
      DateTime sinceTime;
      try {
        sinceTime = DateTime.parse(since);
      } catch (e) {
        return Response.badRequest(body: 'Invalid timestamp format');
      }
      
      // Filter changes from the change log that are newer than the since timestamp
      final recentChanges = _changeLog.where((change) {
        final changeTimestamp = DateTime.parse(change['timestamp'] as String);
        return changeTimestamp.isAfter(sinceTime);
      }).toList();
      
      return Response.ok(
        jsonEncode({
          'changes': recentChanges,
          'timestamp': DateTime.now().toIso8601String(),
          'sinceTime': sinceTime.toIso8601String(),
          'changeCount': recentChanges.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error getting database changes: $e');
      return Response.internalServerError(body: 'Failed to get changes');
    }
  }

  /// CORS middleware
  static Middleware _corsMiddleware() {
    return (handler) {
      return (request) async {
        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, Access-Code',
        });
      };
    };
  }

  /// Authentication middleware
  static Middleware _authMiddleware() {
    return (handler) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, Access-Code',
          });
        }

        if (request.url.path != 'status') {
          final accessCode = request.headers['access-code'] ?? 
                            request.url.queryParameters['access_code'];
          
          if (accessCode != _accessCode) {
            return Response.unauthorized('Invalid access code');
          }
        }

        return handler(request);
      };
    };
  }

  /// LAN-only access middleware
  static Middleware _lanOnlyMiddleware() {
    return (handler) {
      return (request) async {
        final clientIp = request.headers['x-forwarded-for'] ?? 'localhost';
        
        if (!_isLanIp(clientIp)) {
          return Response.forbidden('Access denied: Not a LAN IP');
        }

        return handler(request);
      };
    };
  }

  /// Check if IP is in LAN range (enhanced for your network)
  static bool _isLanIp(String ip) {
    if (ip == 'localhost') return true;
    if (ip == '127.0.0.1' || ip == '::1') return true;
    
    // Your specific network ranges
    if (ip.startsWith('192.168.68.')) return true; // Your current network
    
    // Standard private network ranges
    final lanRanges = [
      '192.168.',   // Class C private networks
      '10.',        // Class A private networks
      '172.16.', '172.17.', '172.18.', '172.19.',
      '172.20.', '172.21.', '172.22.', '172.23.',
      '172.24.', '172.25.', '172.26.', '172.27.',
      '172.28.', '172.29.', '172.30.', '172.31.',  // Class B private networks
    ];
    
    return lanRanges.any((range) => ip.startsWith(range));
  }

  /// Generate access code
  static String _generateAccessCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Configure LAN IP ranges
  static Future<void> _configureLanIpRanges() async {
    try {
      final interfaces = await NetworkInterface.list();
      _allowedIpRanges.clear();
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final ip = address.address;
            if (_isLanIp(ip)) {
              final parts = ip.split('.');
              if (parts.length == 4) {
                final networkRange = '${parts[0]}.${parts[1]}.${parts[2]}';
                if (!_allowedIpRanges.contains(networkRange)) {
                  _allowedIpRanges.add(networkRange);
                }
              }
            }
          }
        }
      }
      
      if (!_allowedIpRanges.contains('127.0.0')) {
        _allowedIpRanges.add('127.0.0');
      }
      
      debugPrint('Configured LAN IP ranges: $_allowedIpRanges');
    } catch (e) {
      debugPrint('Error configuring LAN IP ranges: $e');
      _allowedIpRanges = ['127.0.0', '192.168.1', '192.168.0', '10.0.0'];
    }
  }

  /// Regenerate access code
  static Future<String> regenerateAccessCode() async {
    try {
      _accessCode = _generateAccessCode();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessCodeKey, _accessCode!);
      return _accessCode!;
    } catch (e) {
      debugPrint('Error regenerating access code: $e');
      return 'ERROR';
    }
  }

  /// Handle table data requests
  static Future<Response> _handleTableData(Request request) async {
    try {
      final table = request.params['table'];
      if (table == null) {
        return Response.badRequest(body: 'Table name required');
      }

      if (_dbHelper == null) {
        return Response.internalServerError(body: 'Database not initialized');
      }

      final db = await _dbHelper!.database;
      final result = await db.query(table);
      
      return Response.ok(
        jsonEncode({
          'table': table,
          'data': result,
          'count': result.length,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error getting table data: $e');
      return Response.internalServerError(body: 'Failed to get table data');
    }
  }

  /// Handle table sync requests
  static Future<Response> _handleTableSync(Request request) async {
    try {
      final table = request.params['table'];
      if (table == null) {
        return Response.badRequest(body: 'Table name required');
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final records = data['records'] as List<dynamic>?;
      if (records == null) {
        return Response.badRequest(body: 'Records data required');
      }

      if (_dbHelper == null) {
        return Response.internalServerError(body: 'Database not initialized');
      }

      final db = await _dbHelper!.database;
      
      // Temporarily disable change callback to avoid loops
      DatabaseHelper.clearDatabaseChangeCallback();
      
      int insertedCount = 0;
      int updatedCount = 0;
      
      for (final record in records) {
        final recordMap = record as Map<String, dynamic>;
        final id = recordMap['id'];
        
        if (id != null) {
          try {
            // Special handling for user_sessions table to prevent duplicates
            if (table == 'user_sessions') {
              // Check if session already exists by sessionToken to prevent duplicates
              if (recordMap['sessionToken'] != null) {
                final existing = await db.query(
                  table,
                  where: 'sessionToken = ?',
                  whereArgs: [recordMap['sessionToken']],
                );
                
                if (existing.isNotEmpty) {
                  // Update existing session instead of creating duplicate
                  await db.update(
                    table, 
                    recordMap, 
                    where: 'sessionToken = ?', 
                    whereArgs: [recordMap['sessionToken']]
                  );
                  updatedCount++;
                  debugPrint('Updated existing session: ${recordMap['sessionToken']}');
                } else {
                  // Insert new session
                  await db.insert(table, recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
                  insertedCount++;
                  debugPrint('Inserted new session: ${recordMap['sessionToken']}');
                }
              } else {
                // Fallback to normal insert if no sessionToken
                await db.insert(table, recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
                insertedCount++;
              }
            } else {
              // Use INSERT OR REPLACE to handle conflicts gracefully for other tables
              await db.insert(table, recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
              
              // Check if this was an insert or update
              final existing = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
              if (existing.isNotEmpty) {
                final existingRecord = existing.first;
                final isUpdate = existingRecord.toString() != recordMap.toString();
                if (isUpdate) {
                  updatedCount++;
                } else {
                  insertedCount++;
                }
              } else {
                insertedCount++;
              }
            }
          } catch (e) {
            debugPrint('Error syncing record $id in table $table: $e');
            // Try alternative approach with explicit update/insert
            try {
              final existing = await db.query(table, where: 'id = ?', whereArgs: [id]);
              
              if (existing.isNotEmpty) {
                // Update existing record
                await db.update(table, recordMap, where: 'id = ?', whereArgs: [id]);
                updatedCount++;
              } else {
                // Insert new record
                await db.insert(table, recordMap);
                insertedCount++;
              }
            } catch (fallbackError) {
              debugPrint('Fallback sync also failed for $id: $fallbackError');
            }
          }
        } else {
          // Insert record without ID (let database generate)
          try {
            await db.insert(table, recordMap);
            insertedCount++;
          } catch (e) {
            debugPrint('Error inserting record without ID: $e');
          }
        }
      }
      
      // Re-enable change callback - handled in main.dart now
      // DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      
      return Response.ok(
        jsonEncode({
          'status': 'success',
          'table': table,
          'inserted': insertedCount,
          'updated': updatedCount,
          'total': insertedCount + updatedCount,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error syncing table: $e');
      // Re-enable change callback even on error - handled in main.dart now
      // DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      return Response.internalServerError(body: 'Table sync failed');
    }
  }

  /// Broadcast real-time data to all connected WebSocket clients immediately
  static Future<void> broadcastToAllClients(Map<String, dynamic> data) async {
    try {
      final message = jsonEncode(data);
      _broadcastToAllClients(message);
      debugPrint('EnhancedShelfServer: Broadcasted real-time data to ${_activeWebSocketConnections.length} clients');
    } catch (e) {
      debugPrint('EnhancedShelfServer: Error broadcasting real-time data: $e');
    }
  }

  /// Get server status information
  static Map<String, dynamic> getServerStatus() {
    return {
      'isRunning': _isRunning,
      'port': _currentPort,
      'accessCode': _accessCode,
      'allowedIpRanges': List.from(_allowedIpRanges),
      'activeConnections': _activeWebSocketConnections.length,
      'webSocketIntegrated': true,
      'webSocketEndpoint': '/ws',
      'lastSyncTime': _lastSyncTime.toIso8601String(),
    };
  }

  /// Get connection information for sharing with other devices
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    if (!_isRunning || _accessCode == null) {
      return {'error': 'Server is not running'};
    }

    // Always get fresh IP address
    final actualServerIp = await _getActualServerIp() ?? 'localhost';

    return {
      'serverIp': actualServerIp,
      'port': _currentPort,
      'webSocketEndpoint': '/ws',
      'accessCode': _accessCode,
      'timestamp': DateTime.now().toIso8601String(),
      'webSocketIntegrated': true,
      'activeConnections': _activeWebSocketConnections.length,
      'webSocketUrl': 'ws://$actualServerIp:$_currentPort/ws',
      'httpUrl': 'http://$actualServerIp:$_currentPort',
      'instructions': [
        '1. Open the Patient Management app on your device',
        '2. Go to "LAN Client Connection"',
        '3. Enter the server details above:',
        '   - Server IP: $actualServerIp',
        '   - Port: $_currentPort',
        '   - Access Code: $_accessCode',
        '4. Tap "Connect to Server"',
      ],
      'troubleshooting': [
        'Ensure both devices are on the same WiFi network',
        'Check that firewall is not blocking port $_currentPort',
        'Verify the IP address has not changed',
        'Make sure the server is running before connecting',
      ],
    };
  }

  /// Get the actual server IP address with improved detection
  static Future<String?> _getActualServerIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      final validIps = <Map<String, String>>[];
      
      debugPrint('=== IP Detection Debug ===');
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final ip = address.address;
            final interfaceName = interface.name;
            
            debugPrint('Found IPv4: $ip on $interfaceName');
            
            if (_isLanIp(ip) && !ip.startsWith('127.') && !address.isLoopback) {
              validIps.add({
                'ip': ip,
                'interface': interfaceName,
                'priority': _getIpPriority(ip).toString(),
              });
              debugPrint('✓ Valid LAN IP: $ip on interface: $interfaceName (priority: ${_getIpPriority(ip)})');
            } else {
              debugPrint('✗ Skipped IP: $ip (not suitable for LAN)');
            }
          }
        }
      }
      
      debugPrint('Found ${validIps.length} valid LAN IPs');
      
      if (validIps.isNotEmpty) {
        // Sort by priority (higher number = higher priority)
        validIps.sort((a, b) => int.parse(b['priority']!) - int.parse(a['priority']!));
        
        final selectedIp = validIps.first['ip']!;
        final selectedInterface = validIps.first['interface']!;
        
        debugPrint('=== SELECTED IP ===');
        debugPrint('✓ Primary LAN IP: $selectedIp');
        debugPrint('✓ Interface: $selectedInterface');
        debugPrint('✓ Clients should connect to: $selectedIp:$_currentPort');
        debugPrint('==================');
        
        return selectedIp;
      }
      
      // Fallback to localhost if no LAN IP found
      debugPrint('❌ No LAN IP found, using localhost');
      debugPrint('NOTE: Clients will not be able to connect from other devices!');
      return 'localhost';
    } catch (e) {
      debugPrint('Error getting server IP: $e');
      return 'localhost';
    }
  }

  /// Get IP priority for selection (higher = better)
  static int _getIpPriority(String ip) {
    // Prioritize based on common network patterns
    if (ip.startsWith('192.168.68.')) return 100; // Your specific network
    if (ip.startsWith('172.30.')) return 95;       // Corporate network pattern
    if (ip.startsWith('192.168.1.')) return 90;    // Common home network
    if (ip.startsWith('192.168.0.')) return 85;    // Common home network
    if (ip.startsWith('192.168.')) return 80;      // Other 192.168.x.x networks
    if (ip.startsWith('10.')) return 70;           // Class A private networks
    if (ip.startsWith('172.')) return 60;          // Other Class B private networks
    return 10; // Other IPs (lowest priority)
  }

  /// Handle WebSocket connections for real-time sync
  static void _handleWebSocketConnection(WebSocketChannel webSocket, String? protocol) {
    debugPrint('New WebSocket connection established (Total: ${_activeWebSocketConnections.length + 1})');
    _activeWebSocketConnections.add(webSocket);
    
    // Send initial connection confirmation
    webSocket.sink.add(jsonEncode({
      'type': 'connected',
      'timestamp': DateTime.now().toIso8601String(),
      'lastSyncTime': _lastSyncTime.toIso8601String(),
      'serverInfo': {
        'version': '2.0.0',
        'activeConnections': _activeWebSocketConnections.length,
        'accessCode': _accessCode,
        'features': ['real_time_sync', 'full_sync', 'heartbeat', 'database_changes'],
      }
    }));
    
    // Listen for messages from client
    webSocket.stream.listen(
      (message) async {
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          await _handleWebSocketMessage(webSocket, data);
        } catch (e) {
          debugPrint('Error processing WebSocket message: $e');
          _sendWebSocketError(webSocket, 'Invalid message format');
        }
      },
      onDone: () {
        debugPrint('WebSocket connection closed (Remaining: ${_activeWebSocketConnections.length - 1})');
        _activeWebSocketConnections.remove(webSocket);
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
        _activeWebSocketConnections.remove(webSocket);
      },
    );
  }

  /// Handle incoming WebSocket messages
  static Future<void> _handleWebSocketMessage(WebSocketChannel webSocket, Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    debugPrint('Received WebSocket message: $type');
    
    try {
      switch (type) {
        case 'ping':
          debugPrint('Handling ping request');
          // Respond to ping with pong
          webSocket.sink.add(jsonEncode({
            'type': 'pong',
            'timestamp': DateTime.now().toIso8601String(),
            'activeConnections': _activeWebSocketConnections.length,
          }));
          break;
          
        case 'request_full_sync':
        case 'request_sync':  // Handle both message types for compatibility
          debugPrint('Client requested full sync');
          // Send full database sync to this client
          _sendWebSocketFullSync(webSocket);
          break;
          
        case 'database_change':
          // Handle incoming database change from client
          _handleWebSocketDatabaseChange(data);
          break;
          
        case 'heartbeat':
          // Respond to heartbeat
          webSocket.sink.add(jsonEncode({
            'type': 'heartbeat_ack',
            'timestamp': DateTime.now().toIso8601String(),
            'serverTime': DateTime.now().toIso8601String(),
          }));
          break;
          
        case 'sync_status':
          // Handle sync status from client
          final clientStatus = data['status'] as Map<String, dynamic>?;
          if (clientStatus != null) {
            debugPrint('Client sync status: $clientStatus');
            // Could store client status for monitoring
          }
          break;
          
        case 'client_info':
          // Handle client information
          final clientInfo = data['info'] as Map<String, dynamic>?;
          if (clientInfo != null) {
            debugPrint('Client info: $clientInfo');
          }
          break;
          
        case 'request_table_sync':
          // Send specific table data to client
          final tableName = data['table'] as String?;
          if (tableName != null) {
            debugPrint('SERVER: Table sync requested for: $tableName');
            _sendTableSyncToClient(webSocket, tableName);
            
            // For user_sessions, also broadcast to all other clients to ensure consistency
            if (tableName == 'user_sessions') {
              debugPrint('SERVER: Broadcasting user_sessions to all clients due to sync request');
              await forceSyncTable('user_sessions');
            }
          }
          break;
          
        case 'request_immediate_table_sync':
          // Handle immediate table sync request with priority
          final tableName = data['table'] as String?;
          if (tableName != null) {
            debugPrint('SERVER: IMMEDIATE SYNC REQUEST for: $tableName');
            _sendTableSyncToClient(webSocket, tableName);
            
            // If it's user_sessions, broadcast to ALL clients immediately
            if (tableName == 'user_sessions') {
              debugPrint('SERVER: IMMEDIATE SYNC - Force broadcasting user_sessions to all clients');
              await forceSyncTable('user_sessions');
              
              // Also broadcast a general session update notification
              _broadcastToAllClients(jsonEncode({
                'type': 'session_table_updated',
                'table': 'user_sessions',
                'timestamp': DateTime.now().toIso8601String(),
                'reason': 'immediate_sync_request',
              }));
            }
          }
          break;
          
        case 'force_immediate_session_sync':
          // Handle CRITICAL session sync request - immediate priority
          debugPrint('SERVER: CRITICAL - Force immediate session sync requested');
          final tableName = data['table'] as String?;
          final operation = data['operation'] as String?;
          final recordId = data['recordId'] as String?;
          
          if (tableName == 'user_sessions') {
            debugPrint('SERVER: IMMEDIATE SESSION SYNC - Processing user_sessions sync');
            
            // 1. Immediately send table data to requesting client
            await _sendTableSyncToClient(webSocket, 'user_sessions');
            
            // 2. Force sync to ALL other clients immediately
            await forceSyncTable('user_sessions');
            
            // 3. Broadcast session change notification
            _broadcastToAllClients(jsonEncode({
              'type': 'session_sync_completed',
              'table': 'user_sessions',
              'operation': operation,
              'recordId': recordId,
              'timestamp': DateTime.now().toIso8601String(),
              'priority': 'critical',
            }));
            
            // 4. Send confirmation back to requesting client
            webSocket.sink.add(jsonEncode({
              'type': 'session_sync_confirmed',
              'table': 'user_sessions',
              'timestamp': DateTime.now().toIso8601String(),
            }));
            
            debugPrint('SERVER: IMMEDIATE SESSION SYNC completed for user_sessions');
          }
          break;
          
        case 'force_table_sync':
          // Handle force table sync request from client
          final tableName = data['table'] as String?;
          if (tableName != null) {
            debugPrint('SERVER: FORCE TABLE SYNC requested for: $tableName');
            await _sendTableSyncToClient(webSocket, tableName);
            
            // For user_sessions, ensure all clients get the update
            if (tableName == 'user_sessions') {
              debugPrint('SERVER: FORCE SYNC - Broadcasting user_sessions to all clients');
              await forceSyncTable('user_sessions');
            }
          }
          break;
          
        case 'acknowledge':
          // Handle acknowledgment from client
          final ackId = data['ackId'] as String?;
          debugPrint('Received acknowledgment for: $ackId');
          break;
          
        case 'pong':
          // Handle pong response from client (to our ping)
          debugPrint('Received pong from client');
          break;
          
        case 'session_invalidated':
          // Handle session invalidation message and broadcast to all clients
          debugPrint('Received session invalidation message from client');
          _broadcastToAllClients(jsonEncode(data));
          break;
          
        default:
          debugPrint('Unknown WebSocket message type: $type');
          debugPrint('Available message types: ping, request_full_sync, request_sync, database_change, heartbeat, sync_status, client_info, request_table_sync, acknowledge, pong, session_invalidated');
          _sendWebSocketError(webSocket, 'Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
      _sendWebSocketError(webSocket, 'Error processing message');
    }
  }

  /// Send error message to WebSocket client
  static void _sendWebSocketError(WebSocketChannel webSocket, String error) {
    try {
      webSocket.sink.add(jsonEncode({
        'type': 'error',
        'message': error,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('Failed to send WebSocket error message: $e');
    }
  }

  /// Send full database sync to a WebSocket client
  static Future<void> _sendWebSocketFullSync(WebSocketChannel webSocket) async {
    try {
      if (_dbHelper == null) {
        _sendWebSocketError(webSocket, 'Database not initialized');
        return;
      }
      
      final db = await _dbHelper!.database;
      
      // COMPLETE table list for WebSocket full sync
      final tables = [
        'patients', 
        'appointments', 
        'medical_records', 
        'users', 
        'clinic_services', 
        'active_patient_queue', 
        'user_sessions',
        'patient_history',
        'patient_bills',
        'bill_items', 
        'payments',
        'user_activity_log',
        'patient_queue'
      ];
      
      final syncData = <String, dynamic>{};
      
      for (final table in tables) {
        try {
          final data = await db.query(table);
          syncData[table] = data;
          debugPrint('Synced ${data.length} records from table $table');
        } catch (e) {
          debugPrint('Error querying table $table: $e');
          syncData[table] = [];
        }
      }
      
      webSocket.sink.add(jsonEncode({
        'type': 'full_sync',
        'data': syncData,
        'timestamp': DateTime.now().toIso8601String(),
        'tablesCount': syncData.length,
      }));
      
      debugPrint('Full sync sent to WebSocket client (${syncData.length} tables)');
    } catch (e) {
      debugPrint('Error sending WebSocket full sync: $e');
      _sendWebSocketError(webSocket, 'Failed to send full sync');
    }
  }

  /// Send specific table sync to a WebSocket client
  static Future<void> _sendTableSyncToClient(WebSocketChannel webSocket, String tableName) async {
    try {
      if (_dbHelper == null) {
        _sendWebSocketError(webSocket, 'Database not initialized');
        return;
      }
      
      final db = await _dbHelper!.database;
      final data = await db.query(tableName);
      
      webSocket.sink.add(jsonEncode({
        'type': 'table_sync',
        'table': tableName,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'recordCount': data.length,
      }));
      
      debugPrint('Sent table sync for $tableName to client (${data.length} records)');
    } catch (e) {
      debugPrint('Error sending table sync for $tableName: $e');
      _sendWebSocketError(webSocket, 'Failed to sync table: $tableName');
    }
  }

  /// Handle database change from WebSocket client
  static Future<void> _handleWebSocketDatabaseChange(Map<String, dynamic> data) async {
    try {
      final changeData = data['change'] as Map<String, dynamic>?;
      final clientInfo = data['clientInfo'] as Map<String, dynamic>?;
      
      if (changeData == null) {
        debugPrint('Invalid WebSocket database change data');
        return;
      }
      
      final table = changeData['table'] as String?;
      final operation = changeData['operation'] as String?;
      final recordId = changeData['recordId'] as String?;
      final recordData = changeData['data'] as Map<String, dynamic>?;
      
      if (table == null || operation == null || recordId == null) {
        debugPrint('Invalid database change data received via WebSocket');
        return;
      }
      
      debugPrint('SERVER: Applying WebSocket client change: $table.$operation for record $recordId');
      
      // CRITICAL FIX: Add specific queue change logging
      if (table == 'active_patient_queue') {
        debugPrint('SERVER: QUEUE CHANGE received from client - operation=$operation, recordId=$recordId');
        if (recordData != null) {
          debugPrint('SERVER: QUEUE DATA - patientName=${recordData['patientName']}, status=${recordData['status']}');
        }
      }
      
      if (_dbHelper == null) return;
      final db = await _dbHelper!.database;
      
      // Temporarily disable change callback to avoid loops
      DatabaseHelper.clearDatabaseChangeCallback();
      
      try {
        switch (operation.toLowerCase()) {
          case 'insert':
            if (recordData != null) {
              try {
                // Special handling for user_sessions table to prevent duplicates
                if (table == 'user_sessions') {
                  // Check if session already exists by sessionToken to prevent duplicates
                  if (recordData['sessionToken'] != null) {
                    final existing = await db.query(
                      table,
                      where: 'sessionToken = ?',
                      whereArgs: [recordData['sessionToken']],
                    );
                    
                    if (existing.isNotEmpty) {
                      // Update existing session instead of creating duplicate
                      await db.update(
                        table, 
                        recordData, 
                        where: 'sessionToken = ?', 
                        whereArgs: [recordData['sessionToken']]
                      );
                      await _dbHelper!.logChange(table, recordId, 'update', data: recordData);
                      debugPrint('Updated existing session via WebSocket: ${recordData['sessionToken']}');
                    } else {
                      // Insert new session
                      await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                      await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                      debugPrint('Successfully applied WebSocket session insert: $table.$recordId');
                    }
                  } else {
                    // Fallback to normal insert if no sessionToken
                    await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                    await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                    debugPrint('Successfully applied WebSocket insert: $table.$recordId');
                  }
                } else if (table == 'active_patient_queue') {
                  // ENHANCED FIX: Better conflict handling for queue inserts
                  final existing = await db.query(
                    table,
                    where: 'queueEntryId = ?',
                    whereArgs: [recordId],
                  );
                  
                  if (existing.isEmpty) {
                    await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                    await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                    debugPrint('SERVER: Successfully inserted queue item: $recordId');
                  } else {
                    debugPrint('SERVER: Queue item already exists, updating instead: $recordId');
                    await db.update(table, recordData, where: 'queueEntryId = ?', whereArgs: [recordId]);
                    await _dbHelper!.logChange(table, recordId, 'update', data: recordData);
                  }
                } else {
                  // Use INSERT OR REPLACE to handle potential conflicts for other tables
                  await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                  // Log the change to trigger sync notifications
                  await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                  debugPrint('Successfully applied WebSocket insert: $table.$recordId');
                }
              } catch (e) {
                debugPrint('Error applying WebSocket insert: $e');
                // If insert fails, try update as fallback
                try {
                  String whereColumn = 'id';
                  if (table == 'active_patient_queue') {
                    whereColumn = 'queueEntryId';
                  } else if (table == 'user_sessions') {
                    whereColumn = 'id';
                  }
                  
                  final rowsAffected = await db.update(table, recordData, where: '$whereColumn = ?', whereArgs: [recordId]);
                  await _dbHelper!.logChange(table, recordId, 'update', data: recordData);
                  debugPrint('Fallback update successful: $table.$recordId (rows affected: $rowsAffected)');
                } catch (updateError) {
                  debugPrint('Both insert and update failed for $table.$recordId: $updateError');
                }
              }
            }
            break;
          case 'update':
            if (recordData != null) {
              try {
                String whereColumn = 'id';
                // Handle special cases for tables with different primary key columns
                if (table == 'active_patient_queue') {
                  whereColumn = 'queueEntryId';
                } else if (table == 'user_sessions') {
                  whereColumn = 'id';
                }
                
                final rowsAffected = await db.update(table, recordData, where: '$whereColumn = ?', whereArgs: [recordId]);
                
                // If no rows were affected, try inserting the record
                if (rowsAffected == 0) {
                  debugPrint('No rows updated, attempting insert for $table.$recordId');
                  await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                  await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                  debugPrint('Successfully inserted instead of updated: $table.$recordId');
                } else {
                  // Log the change to trigger sync notifications
                  await _dbHelper!.logChange(table, recordId, 'update', data: recordData);
                  debugPrint('Successfully applied WebSocket update: $table.$recordId (rows affected: $rowsAffected)');
                }
              } catch (e) {
                debugPrint('Error applying WebSocket update: $e');
              }
            }
            break;
          case 'delete':
            try {
              String whereColumn = 'id';
              String whereValue = recordId;
              
              // Handle special cases for tables with different primary key columns
              if (table == 'active_patient_queue') {
                whereColumn = 'queueEntryId';
              } else if (table == 'user_sessions') {
                // For user_sessions, try to use sessionToken if available in the data
                if (recordData != null && recordData['sessionToken'] != null) {
                  whereColumn = 'sessionToken';
                  whereValue = recordData['sessionToken'];
                  debugPrint('Using sessionToken for session deletion: $whereValue');
                } else {
                  whereColumn = 'id';
                }
              }
              
              final rowsAffected = await db.delete(table, where: '$whereColumn = ?', whereArgs: [whereValue]);
              // Log the change to trigger sync notifications
              await _dbHelper!.logChange(table, recordId, 'delete');
              debugPrint('Successfully applied WebSocket delete: $table.$recordId using $whereColumn=$whereValue (rows affected: $rowsAffected)');
            } catch (e) {
              debugPrint('Error applying WebSocket delete: $e');
            }
            break;
          default:
            debugPrint('Unknown WebSocket operation: $operation');
        }
        
        // Add client info to the change data for tracking
        final broadcastData = Map<String, dynamic>.from(changeData);
        broadcastData['source'] = 'client';
        if (clientInfo != null) {
          broadcastData['clientInfo'] = clientInfo;
        }
        
        // Broadcast this change to other connected clients (excluding sender)
        _broadcastWebSocketChange(broadcastData);
        
        // CRITICAL FIX: Special handling for queue changes
        if (table == 'active_patient_queue') {
          debugPrint('SERVER: QUEUE CHANGE broadcasted to all connected clients');
          
          // Also send immediate table sync to ensure consistency
          Future.delayed(const Duration(milliseconds: 100), () async {
            try {
              if (_dbHelper != null) {
                final db = await _dbHelper!.database;
                final queueData = await db.query('active_patient_queue');
                
                _broadcastToAllClients(jsonEncode({
                  'type': 'table_sync',
                  'table': 'active_patient_queue',
                  'data': queueData,
                  'timestamp': DateTime.now().toIso8601String(),
                  'recordCount': queueData.length,
                  'reason': 'queue_change_immediate_sync',
                }));
                
                debugPrint('SERVER: Sent immediate queue table sync to all clients (${queueData.length} records)');
              }
            } catch (e) {
              debugPrint('SERVER: Error sending immediate queue sync: $e');
            }
          });
        }
        
      } finally {
        // Re-enable change callback - handled in main.dart now
        // DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      }
      
    } catch (e) {
      debugPrint('Error handling WebSocket database change: $e');
    }
  }

  /// Broadcast changes to all WebSocket clients
  static void _broadcastWebSocketChange(Map<String, dynamic> change) {
    final message = jsonEncode({
      'type': 'database_change',
      'change': change,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    final deadConnections = <WebSocketChannel>[];
    
    for (final connection in _activeWebSocketConnections) {
      try {
        connection.sink.add(message);
      } catch (e) {
        debugPrint('Failed to send to WebSocket client: $e');
        deadConnections.add(connection);
      }
    }
    
    // Remove dead connections
    for (final deadConnection in deadConnections) {
      _activeWebSocketConnections.remove(deadConnection);
    }
    
    if (deadConnections.isNotEmpty) {
      debugPrint('Removed ${deadConnections.length} dead WebSocket connections');
    }
    
    // Add to sync updates stream
    _syncUpdates.add(change);
    
    debugPrint('Broadcasted change to ${_activeWebSocketConnections.length} WebSocket clients');
  }

  /// Send ping to all connected WebSocket clients to check connection health
  static void pingAllClients() {
    final pingMessage = jsonEncode({
      'type': 'ping',
      'timestamp': DateTime.now().toIso8601String(),
      'from': 'server',
    });
    
    final deadConnections = <WebSocketChannel>[];
    
    for (final connection in _activeWebSocketConnections) {
      try {
        connection.sink.add(pingMessage);
      } catch (e) {
        debugPrint('Failed to ping WebSocket client: $e');
        deadConnections.add(connection);
      }
    }
    
    // Remove dead connections
    for (final deadConnection in deadConnections) {
      _activeWebSocketConnections.remove(deadConnection);
    }
    
    if (deadConnections.isNotEmpty) {
      debugPrint('Removed ${deadConnections.length} dead connections during ping');
    }
  }

  /// Request all clients to send their sync status
  static void requestClientSyncStatus() {
    final message = jsonEncode({
      'type': 'request_sync_status',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _broadcastToAllClients(message);
    debugPrint('Requested sync status from all clients');
  }

  /// Broadcast a message to all connected WebSocket clients
  static void _broadcastToAllClients(String message) {
    final deadConnections = <WebSocketChannel>[];
    
    for (final connection in _activeWebSocketConnections) {
      try {
        connection.sink.add(message);
      } catch (e) {
        debugPrint('Failed to broadcast to WebSocket client: $e');
        deadConnections.add(connection);
      }
    }
    
    // Remove dead connections
    for (final deadConnection in deadConnections) {
      _activeWebSocketConnections.remove(deadConnection);
    }
  }

  /// Get detailed server statistics
  static Map<String, dynamic> getServerStatistics() {
    return {
      'isRunning': _isRunning,
      'port': _currentPort,
      'accessCode': _accessCode,
      'webSocketIntegrated': true,
      'webSocketEndpoint': '/ws',
      'activeWebSocketConnections': _activeWebSocketConnections.length,
      'totalChangeLogEntries': _changeLog.length,
      'lastSyncTime': _lastSyncTime.toIso8601String(),
      'allowedIpRanges': List.from(_allowedIpRanges),
      'uptime': _isRunning ? DateTime.now().difference(_lastSyncTime).inMinutes : 0,
      'endpoints': [
        'GET /status',
        'GET /db/download',
        'POST /db/sync',
        'GET /db/changes/<since>',
        'GET /tables/<table>',
        'POST /tables/<table>/sync',
        'WS /ws'
      ],
      'features': [
        'HTTP REST API',
        'WebSocket real-time sync',
        'Change tracking',
        'LAN-only access',
        'Access code authentication',
        'CORS support',
        'Full database sync',
        'Incremental sync',
        'Connection health monitoring'
      ]
    };
  }

  /// Force sync a specific table to all clients
  static Future<void> forceSyncTable(String tableName) async {
    try {
      if (_dbHelper == null) {
        debugPrint('Cannot force sync: Database not initialized');
        return;
      }
      
      final db = await _dbHelper!.database;
      final data = await db.query(tableName);
      
      final syncMessage = jsonEncode({
        'type': 'force_table_sync',
        'table': tableName,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'recordCount': data.length,
      });
      
      _broadcastToAllClients(syncMessage);
      debugPrint('Force synced table $tableName to all clients (${data.length} records)');
    } catch (e) {
      debugPrint('Error force syncing table $tableName: $e');
    }
  }

  /// Cleanup old change log entries (keep only last 24 hours)
  static void cleanupChangeLog() {
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
    final originalCount = _changeLog.length;
    
    _changeLog.removeWhere((change) {
      final changeTime = DateTime.parse(change['timestamp'] as String);
      return changeTime.isBefore(cutoffTime);
    });
    
    final removedCount = originalCount - _changeLog.length;
    if (removedCount > 0) {
      debugPrint('Cleaned up $removedCount old change log entries');
    }
  }

  /// Send server announcement to all clients
  static void announceToClients(String message, {String type = 'announcement'}) {
    final announcement = jsonEncode({
      'type': type,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'from': 'server',
    });
    
    _broadcastToAllClients(announcement);
    debugPrint('Announced to all clients: $message');
  }
}
