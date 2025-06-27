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
      
      // Set up database change callback for this server
      DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      
      // Create router with endpoints
      final router = _createRouter();
      
      // Create handler with middleware
      final handler = const Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(_authMiddleware())
          .addMiddleware(_lanOnlyMiddleware())
          .addHandler(router.call);

      // Start HTTP server
      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      _isRunning = true;
      
      debugPrint('Enhanced Shelf Server started on port $port with integrated WebSocket support');
      debugPrint('Access code: $_accessCode');
      
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
      final tables = ['patients', 'appointments', 'medical_records', 'users', 'clinic_services'];
      final data = <String, List<Map<String, dynamic>>>{};
      
      for (final table in tables) {
        try {
          final result = await db.query(table);
          data[table] = result;
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

  /// Check if IP is in LAN range
  static bool _isLanIp(String ip) {
    if (ip == 'localhost') return true;
    if (ip == '127.0.0.1' || ip == '::1') return true;
    
    final lanRanges = [
      '192.168.',
      '10.',
      '172.16.', '172.17.', '172.18.', '172.19.',
      '172.20.', '172.21.', '172.22.', '172.23.',
      '172.24.', '172.25.', '172.26.', '172.27.',
      '172.28.', '172.29.', '172.30.', '172.31.',
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
          // Check if record exists
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
        } else {
          // Insert record without ID (let database generate)
          await db.insert(table, recordMap);
          insertedCount++;
        }
      }
      
      // Re-enable change callback
      DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      
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
      // Re-enable change callback even on error
      DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
      return Response.internalServerError(body: 'Table sync failed');
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
  static Map<String, dynamic> getConnectionInfo() {
    if (!_isRunning || _accessCode == null) {
      return {'error': 'Server is not running'};
    }

    return {
      'serverIp': _allowedIpRanges.isNotEmpty ? '${_allowedIpRanges.first}.100' : 'localhost',
      'port': _currentPort,
      'webSocketEndpoint': '/ws',
      'accessCode': _accessCode,
      'timestamp': DateTime.now().toIso8601String(),
      'webSocketIntegrated': true,
      'activeConnections': _activeWebSocketConnections.length,
      'instructions': [
        '1. Open the Patient Management app on your device',
        '2. Go to "LAN Client Connection"',
        '3. Enter the server details above',
        '4. HTTP Port: $_currentPort, WebSocket Endpoint: ws://[SERVER_IP]:$_currentPort/ws',
        '5. Tap "Connect to Server"',
      ],
    };
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
      (message) {
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          _handleWebSocketMessage(webSocket, data);
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
  static void _handleWebSocketMessage(WebSocketChannel webSocket, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    try {
      switch (type) {
        case 'ping':
          // Respond to ping with pong
          webSocket.sink.add(jsonEncode({
            'type': 'pong',
            'timestamp': DateTime.now().toIso8601String(),
            'activeConnections': _activeWebSocketConnections.length,
          }));
          break;
          
        case 'request_full_sync':
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
            _sendTableSyncToClient(webSocket, tableName);
          }
          break;
          
        case 'acknowledge':
          // Handle acknowledgment from client
          final ackId = data['ackId'] as String?;
          debugPrint('Received acknowledgment for: $ackId');
          break;
          
        default:
          debugPrint('Unknown WebSocket message type: $type');
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
      final tables = ['patients', 'appointments', 'medical_records', 'users', 'clinic_services'];
      
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
      
      debugPrint('Applying WebSocket client change: $table.$operation for record $recordId');
      
      if (_dbHelper == null) return;
      final db = await _dbHelper!.database;
      
      // Temporarily disable change callback to avoid loops
      DatabaseHelper.clearDatabaseChangeCallback();
      
      try {
        switch (operation.toLowerCase()) {
          case 'insert':
            if (recordData != null) {
              try {
                await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                debugPrint('Successfully applied WebSocket insert: $table.$recordId');
              } catch (e) {
                debugPrint('Error applying WebSocket insert: $e');
              }
            }
            break;
          case 'update':
            if (recordData != null) {
              try {
                final rowsAffected = await db.update(table, recordData, where: 'id = ?', whereArgs: [recordId]);
                debugPrint('Successfully applied WebSocket update: $table.$recordId (rows affected: $rowsAffected)');
              } catch (e) {
                debugPrint('Error applying WebSocket update: $e');
              }
            }
            break;
          case 'delete':
            try {
              final rowsAffected = await db.delete(table, where: 'id = ?', whereArgs: [recordId]);
              debugPrint('Successfully applied WebSocket delete: $table.$recordId (rows affected: $rowsAffected)');
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
        
      } finally {
        // Re-enable change callback
        DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
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
