import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Client service for syncing with Enhanced Shelf Server
class DatabaseSyncClient {
  static WebSocketChannel? _wsChannel;
  static Timer? _reconnectTimer;
  static Timer? _heartbeatTimer;
  static bool _isConnected = false;
  static String? _serverIp;
  static int? _serverPort;
  static String? _accessCode;
  static DatabaseHelper? _dbHelper;
  static StreamSubscription? _wsSubscription;

  // Stream controllers for sync events
  static final StreamController<Map<String, dynamic>> _syncUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  static bool get isConnected => _isConnected;
  static Stream<Map<String, dynamic>> get syncUpdates => _syncUpdates.stream;

  /// Initialize the client
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    _dbHelper = dbHelper;
    
    // Set up database change callback for sending changes to server
    DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
    
    debugPrint('Database Sync Client initialized with bidirectional sync');
  }

  /// Connect to server
  static Future<bool> connectToServer(String serverIp, int port, String accessCode) async {
    try {
      _serverIp = serverIp;
      _serverPort = port;
      _accessCode = accessCode;

      // Test HTTP connection first
      final testUrl = 'http://$serverIp:$port/status';
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {'access-code': accessCode},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server connection failed: ${response.statusCode}');
      }

      // Connect WebSocket
      await _connectWebSocket();

      debugPrint('Successfully connected to server at $serverIp:$port');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to server: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Connect WebSocket
  static Future<void> _connectWebSocket() async {
    try {
      final wsUrl = 'ws://$_serverIp:$_serverPort/ws?access_code=$_accessCode';
      _wsChannel = IOWebSocketChannel.connect(wsUrl);

      _wsSubscription = _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      _startHeartbeat();

      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Handle WebSocket messages
  static void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          debugPrint('Connected to server');
          _requestFullSync();
          break;

        case 'database_change':
          _handleRemoteDatabaseChange(data['change'] as Map<String, dynamic>);
          break;

        case 'full_sync':
          _handleFullSync(data['data'] as Map<String, dynamic>);
          break;

        case 'pong':
          // Heartbeat response
          break;

        default:
          debugPrint('Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  /// Request full sync from server
  static void _requestFullSync() {
    if (_isConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_sync',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Handle full sync data from server
  static Future<void> _handleFullSync(Map<String, dynamic> data) async {
    try {
      if (_dbHelper == null) return;

      debugPrint('Applying full sync from server...');
      
      final db = await _dbHelper!.database;

      // Temporarily disable change callback to prevent sync loops during full sync
      DatabaseHelper.clearDatabaseChangeCallback();
      
      try {
        // Sync each table
        for (final entry in data.entries) {
          final tableName = entry.key;
          final tableData = entry.value as List<dynamic>;

          debugPrint('Syncing table $tableName with ${tableData.length} records');

          // Clear existing data (you might want to be more selective here)
          await db.delete(tableName);

          // Insert new data
          for (final record in tableData) {
            final recordMap = record as Map<String, dynamic>;
            await db.insert(tableName, recordMap);
          }
        }
      } finally {
        // Re-enable change callback
        DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
      }

      debugPrint('Full sync completed successfully');
      _syncUpdates.add({
        'type': 'full_sync_completed',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error applying full sync: $e');
    }
  }

  /// Handle remote database changes
  static Future<void> _handleRemoteDatabaseChange(Map<String, dynamic> change) async {
    try {
      if (_dbHelper == null) return;

      final table = change['table'] as String;
      final operation = change['operation'] as String;
      final recordId = change['recordId'] as String;
      final data = change['data'] as Map<String, dynamic>?;
      final source = change['source'] as String?;

      // Don't apply changes that came from this client to avoid loops
      if (source == 'client') {
        final deviceId = await _getDeviceId();
        final changeClientInfo = change['clientInfo'] as Map<String, dynamic>?;
        final changeDeviceId = changeClientInfo?['deviceId'] as String?;
        
        if (changeDeviceId == deviceId) {
          debugPrint('Ignoring change from this device to prevent loop');
          return;
        }
      }

      debugPrint('Applying remote change: $table.$operation for record $recordId');

      final db = await _dbHelper!.database;

      // Temporarily disable change callback to prevent sync loops
      DatabaseHelper.clearDatabaseChangeCallback();
      
      try {
        switch (operation.toLowerCase()) {
          case 'insert':
            if (data != null) {
              try {
                await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
                debugPrint('Successfully applied remote insert: $table.$recordId');
              } catch (e) {
                debugPrint('Error applying remote insert: $e');
              }
            }
            break;
          case 'update':
            if (data != null) {
              try {
                final rowsAffected = await db.update(table, data, where: 'id = ?', whereArgs: [recordId]);
                debugPrint('Successfully applied remote update: $table.$recordId (rows affected: $rowsAffected)');
              } catch (e) {
                debugPrint('Error applying remote update: $e');
              }
            }
            break;
          case 'delete':
            try {
              final rowsAffected = await db.delete(table, where: 'id = ?', whereArgs: [recordId]);
              debugPrint('Successfully applied remote delete: $table.$recordId (rows affected: $rowsAffected)');
            } catch (e) {
              debugPrint('Error applying remote delete: $e');
            }
            break;
        }
      } finally {
        // Re-enable change callback
        DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
      }

      _syncUpdates.add({
        'type': 'remote_change_applied',
        'change': change,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error applying remote change: $e');
    }
  }

  /// Start heartbeat
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _wsChannel != null) {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
    });
  }

  /// Schedule reconnection
  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _serverIp != null && _serverPort != null && _accessCode != null) {
        debugPrint('Attempting to reconnect...');
        _connectWebSocket();
      }
    });
  }

  /// Disconnect from server
  static Future<void> disconnect() async {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _wsSubscription?.cancel();
    await _wsChannel?.sink.close();
    
    _wsChannel = null;
    _wsSubscription = null;
    
    debugPrint('Disconnected from server');
  }

  /// Manual sync with server
  static Future<bool> manualSync() async {
    try {
      if (_serverIp == null || _serverPort == null || _accessCode == null) {
        return false;
      }

      final url = 'http://$_serverIp:$_serverPort/db/download';
      final response = await http.get(
        Uri.parse(url),
        headers: {'access-code': _accessCode!},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _handleFullSync(data['data'] as Map<String, dynamic>);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Manual sync failed: $e');
      return false;
    }
  }

  /// Handle local database changes and send to server
  static Future<void> _onLocalDatabaseChange(String table, String operation, String recordId, Map<String, dynamic>? data) async {
    try {
      if (!_isConnected || _wsChannel == null) {
        debugPrint('Not connected to server, change will sync later: $table.$operation');
        return;
      }

      debugPrint('Sending local change to server: $table.$operation for record $recordId');

      final changeMessage = {
        'type': 'database_change',
        'change': {
          'table': table,
          'operation': operation,
          'recordId': recordId,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'client',
        },
        'clientInfo': {
          'timestamp': DateTime.now().toIso8601String(),
          'deviceId': await _getDeviceId(),
        }
      };

      _wsChannel!.sink.add(jsonEncode(changeMessage));
      debugPrint('Successfully sent local change to server');
    } catch (e) {
      debugPrint('Error sending local change to server: $e');
    }
  }

  /// Get device ID for tracking
  static Future<String> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'client_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
        await prefs.setString('device_id', deviceId);
      }
      return deviceId;
    } catch (e) {
      return 'unknown_device_${Random().nextInt(10000)}';
    }
  }

  /// Dispose client
  static Future<void> dispose() async {
    await disconnect();
  }
}
