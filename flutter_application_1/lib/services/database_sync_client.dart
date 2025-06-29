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

  // Timer for periodic sync checks
  static Timer? _periodicSyncTimer;
  static Timer? _queueRefreshTimer;

  static bool get isConnected => _isConnected;
  static Stream<Map<String, dynamic>> get syncUpdates => _syncUpdates.stream;

  /// Initialize the client
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    _dbHelper = dbHelper;
    
    // Set up database change callback for sending changes to server
    DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
    
    // Start periodic sync for queue updates (every 3 seconds)
    _startPeriodicSync();
    
    debugPrint('Database Sync Client initialized with bidirectional sync and periodic refresh');
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

      // Save settings only after successful connection
      await saveSyncSettings(serverIp, port, accessCode);

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

  /// Send client information to server
  static void _sendClientInfo() {
    if (_isConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'client_info',
        'info': {
          'clientType': 'flutter_app',
          'version': '2.0.0',
          'platform': 'mobile', // or get actual platform
          'capabilities': ['real_time_sync', 'full_sync', 'table_sync', 'heartbeat'],
          'deviceId': 'flutter_device_${DateTime.now().millisecondsSinceEpoch}',
        },
        'timestamp': DateTime.now().toIso8601String(),
      }));
      debugPrint('Client info sent to server');
    }
  }

  /// Handle WebSocket messages
  static void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      debugPrint('Received WebSocket message: $type');

      switch (type) {
        case 'connected':
          debugPrint('Connected to server');
          // Send client information
          _sendClientInfo();
          // Request full sync
          _requestFullSync();
          // Immediately request user_sessions sync for authentication state
          _requestUserSessionsSync();
          break;

        case 'database_change':
          debugPrint('Received database change from server');
          _handleRemoteDatabaseChange(data['change'] as Map<String, dynamic>);
          break;

        case 'full_sync':
          debugPrint('Received full sync data from server');
          _handleFullSync(data['data'] as Map<String, dynamic>);
          break;

        case 'pong':
          // Heartbeat response
          debugPrint('Received pong from server');
          break;

        case 'heartbeat_ack':
          // Heartbeat acknowledgment response
          debugPrint('Received heartbeat_ack from server');
          break;

        case 'error':
          // Handle error messages from server
          final errorMessage = data['message'] as String?;
          debugPrint('Server error: $errorMessage');
          _syncUpdates.add({
            'type': 'server_error',
            'error': errorMessage,
            'timestamp': DateTime.now().toIso8601String(),
          });
          break;

        case 'table_sync':
          // Handle individual table sync from server
          final tableName = data['table'] as String?;
          final tableData = data['data'] as List<dynamic>?;
          if (tableName != null && tableData != null) {
            debugPrint('Received table sync for $tableName: ${tableData.length} records');
            _handleTableSync(tableName, tableData);
          }
          break;

        case 'ping':
          // Respond to server ping with pong
          if (_wsChannel != null) {
            _wsChannel!.sink.add(jsonEncode({
              'type': 'pong',
              'timestamp': DateTime.now().toIso8601String(),
            }));
            debugPrint('Responded to server ping with pong');
          }
          break;

        case 'request_sync_status':
          // Send sync status to server
          if (_wsChannel != null) {
            _wsChannel!.sink.add(jsonEncode({
              'type': 'sync_status',
              'status': {
                'connected': _isConnected,
                'lastSync': DateTime.now().toIso8601String(),
                'clientId': 'flutter_client',
              },
              'timestamp': DateTime.now().toIso8601String(),
            }));
            debugPrint('Sent sync status to server');
          }
          break;

        case 'force_table_sync':
          // Handle forced table sync request
          final tableName = data['table'] as String?;
          if (tableName != null) {
            debugPrint('Server requesting forced sync for table: $tableName');
            // Request specific table sync
            if (_wsChannel != null) {
              _wsChannel!.sink.add(jsonEncode({
                'type': 'request_table_sync',
                'table': tableName,
                'timestamp': DateTime.now().toIso8601String(),
              }));
            }
          }
          break;

        case 'session_invalidated':
          // Handle session invalidation from another device
          debugPrint('Received session invalidation notification');
          try {
            // Call AuthService to handle the invalidation
            // We'll create a simple mechanism to notify the app
            _syncUpdates.add({
              'type': 'session_invalidated',
              'data': data,
              'timestamp': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('Error handling session invalidation: $e');
          }
          break;

        default:
          debugPrint('Unknown message type: $type');
          debugPrint('Full message data: $data');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
      debugPrint('Message content: $message');
    }
  }

  /// Request full sync from server
  static void _requestFullSync() {
    if (_isConnected && _wsChannel != null) {
      debugPrint('Requesting full sync from server');
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_sync',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      debugPrint('Full sync request sent');
    } else {
      debugPrint('Cannot request sync - not connected to server');
    }
  }

  /// Request user sessions table sync
  static void _requestUserSessionsSync() {
    if (_isConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'user_sessions',
        'priority': 'high',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      debugPrint('Requested user_sessions table sync from server');
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
                // Special handling for user_sessions table to prevent duplicates
                if (table == 'user_sessions') {
                  // Check if session already exists by sessionToken to prevent duplicates
                  if (data['sessionToken'] != null) {
                    final existing = await db.query(
                      table,
                      where: 'sessionToken = ?',
                      whereArgs: [data['sessionToken']],
                    );
                    
                    if (existing.isNotEmpty) {
                      // Update existing session instead of creating duplicate
                      final rowsAffected = await db.update(
                        table, 
                        data, 
                        where: 'sessionToken = ?', 
                        whereArgs: [data['sessionToken']]
                      );
                      debugPrint('Updated existing session instead of duplicate insert: $table.$recordId (rows affected: $rowsAffected)');
                    } else {
                      // Insert new session
                      await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
                      debugPrint('Successfully applied remote session insert: $table.$recordId');
                    }
                  } else {
                    // Fallback to normal insert if no sessionToken
                    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
                    debugPrint('Successfully applied remote insert: $table.$recordId');
                  }
                } else {
                  // Always use INSERT OR REPLACE for all other inserts to handle conflicts
                  await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
                  debugPrint('Successfully applied remote insert: $table.$recordId');
                }
              } catch (e) {
                debugPrint('Error applying remote insert: $e');
                // If insert fails, try update as fallback
                try {
                  String whereColumn = 'id';
                  if (table == 'active_patient_queue') {
                    whereColumn = 'queueEntryId';
                  } else if (table == 'user_sessions') {
                    whereColumn = 'id';
                  }
                  
                  final rowsAffected = await db.update(table, data, where: '$whereColumn = ?', whereArgs: [recordId]);
                  debugPrint('Fallback update successful: $table.$recordId (rows affected: $rowsAffected)');
                } catch (updateError) {
                  debugPrint('Both insert and update failed for $table.$recordId: $updateError');
                }
              }
            }
            break;
          case 'update':
            if (data != null) {
              try {
                String whereColumn = 'id';
                // Handle special cases for tables with different primary key columns
                if (table == 'active_patient_queue') {
                  whereColumn = 'queueEntryId';
                } else if (table == 'user_sessions') {
                  whereColumn = 'id';
                }
                
                final rowsAffected = await db.update(table, data, where: '$whereColumn = ?', whereArgs: [recordId]);
                
                // If no rows were affected, try inserting the record
                if (rowsAffected == 0) {
                  debugPrint('No rows updated, attempting insert for $table.$recordId');
                  await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
                  debugPrint('Successfully inserted instead of updated: $table.$recordId');
                } else {
                  debugPrint('Successfully applied remote update: $table.$recordId (rows affected: $rowsAffected)');
                }
              } catch (e) {
                debugPrint('Error applying remote update: $e');
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
                if (data != null && data['sessionToken'] != null) {
                  whereColumn = 'sessionToken';
                  whereValue = data['sessionToken'];
                  debugPrint('Using sessionToken for session deletion: $whereValue');
                } else {
                  whereColumn = 'id';
                }
              }
              
              final rowsAffected = await db.delete(table, where: '$whereColumn = ?', whereArgs: [whereValue]);
              debugPrint('Successfully applied remote delete: $table.$recordId using $whereColumn=$whereValue (rows affected: $rowsAffected)');
            } catch (e) {
              debugPrint('Error applying remote delete: $e');
            }
            break;
        }

        // Trigger UI refresh for specific queue changes
        if (table == 'active_patient_queue') {
          _syncUpdates.add({
            'type': 'queue_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
          });
        } else if (table == 'appointments') {
          _syncUpdates.add({
            'type': 'appointment_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
          });
        } else if (table == 'user_sessions') {
          _syncUpdates.add({
            'type': 'session_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
            'data': data,
          });
          
          // Additional session validation for authentication integrity
          if (operation == 'insert' || operation == 'update' || operation == 'delete') {
            Future.delayed(const Duration(seconds: 1), () {
              _syncUpdates.add({
                'type': 'auth_conflict_check_needed',
                'timestamp': DateTime.now().toIso8601String(),
                'reason': 'session_${operation}_detected',
                'sessionId': recordId,
              });
            });
          }
        }
        
        // Add general change notification
        _syncUpdates.add({
          'type': 'remote_change_applied',
          'change': change,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } finally {
        // Re-enable change callback
        DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
      }
    } catch (e) {
      debugPrint('Error handling remote database change: $e');
      _syncUpdates.add({
        'type': 'sync_error',
        'error': e.toString(),
        'change': change,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Handle table sync data from server
  static Future<void> _handleTableSync(String tableName, List<dynamic> tableData) async {
    try {
      if (_dbHelper == null) return;

      debugPrint('Applying table sync for $tableName with ${tableData.length} records...');
      
      final db = await _dbHelper!.database;

      // Temporarily disable change callback to prevent sync loops during table sync
      DatabaseHelper.clearDatabaseChangeCallback();
      
      try {
        // For user_sessions table, use selective merge instead of clearing all data
        if (tableName == 'user_sessions') {
          debugPrint('Performing selective merge for user_sessions table');
          
          // Insert or replace each session record individually
          for (final record in tableData) {
            final recordMap = record as Map<String, dynamic>;
            
            try {
              // For user_sessions, use the sessionToken as the unique identifier if available
              // This prevents duplicate sessions for the same user/device combination
              if (recordMap['sessionToken'] != null) {
                // First check if a session with this token already exists
                final existingSession = await db.query(
                  tableName,
                  where: 'sessionToken = ?',
                  whereArgs: [recordMap['sessionToken']],
                );
                
                if (existingSession.isNotEmpty) {
                  // Update existing session record
                  await db.update(
                    tableName,
                    recordMap,
                    where: 'sessionToken = ?',
                    whereArgs: [recordMap['sessionToken']],
                  );
                  debugPrint('Updated existing session: ${recordMap['sessionToken']}');
                } else {
                  // Insert new session record
                  await db.insert(
                    tableName, 
                    recordMap,
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                  debugPrint('Inserted new session: ${recordMap['sessionToken']}');
                }
              } else {
                // Fallback to standard INSERT OR REPLACE by ID
                await db.insert(
                  tableName, 
                  recordMap,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            } catch (e) {
              debugPrint('Error syncing session record ${recordMap['id']}: $e');
            }
          }
        } else {
          // For other tables, use the normal clear and insert approach
          await db.delete(tableName);

          // Insert new data using INSERT OR REPLACE to handle duplicates
          for (final record in tableData) {
            final recordMap = record as Map<String, dynamic>;
            
            // Use INSERT OR REPLACE to handle potential duplicate keys
            await db.insert(
              tableName, 
              recordMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        debugPrint('Table sync completed for $tableName (${tableData.length} records)');
        
        // Notify about sync completion
        _syncUpdates.add({
          'type': 'table_sync_completed',
          'table': tableName,
          'recordCount': tableData.length,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Special handling for user_sessions table sync
        if (tableName == 'user_sessions') {
          _syncUpdates.add({
            'type': 'session_table_synced',
            'table': tableName,
            'recordCount': tableData.length,
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          // Trigger session validation after sync
          _syncUpdates.add({
            'type': 'session_sync_validation_needed',
            'table': tableName,
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          // Also check for authentication conflicts immediately
          Future.delayed(const Duration(seconds: 1), () {
            _checkAuthenticationConflicts();
          });
        }
      } finally {
        // Re-enable change callback
        DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
      }
    } catch (e) {
      debugPrint('Error applying table sync for $tableName: $e');
      _syncUpdates.add({
        'type': 'table_sync_error',
        'table': tableName,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Start heartbeat
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _wsChannel != null) {
        // Alternate between ping and heartbeat messages
        final usePing = timer.tick % 2 == 1;
        if (usePing) {
          _wsChannel!.sink.add(jsonEncode({
            'type': 'ping',
            'timestamp': DateTime.now().toIso8601String(),
          }));
        } else {
          _wsChannel!.sink.add(jsonEncode({
            'type': 'heartbeat',
            'timestamp': DateTime.now().toIso8601String(),
            'clientStatus': {
              'connected': _isConnected,
              'syncActive': _isConnected,
            },
          }));
        }
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
    _stopPeriodicSync(); // Stop periodic sync timers
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

      // Special handling for user_sessions table - request immediate sync back
      if (table == 'user_sessions') {
        debugPrint('Session change detected - requesting immediate bidirectional sync');
        
        // Request immediate sync back from server to ensure all devices are in sync
        Future.delayed(const Duration(milliseconds: 500), () {
          requestImmediateSessionSync();
        });
        
        // Also trigger manual sync to ensure session data reaches the host immediately
        Future.delayed(const Duration(milliseconds: 1000), () async {
          try {
            await manualSync();
            debugPrint('Manual sync completed for session change');
          } catch (e) {
            debugPrint('Error during manual sync for session change: $e');
          }
        });
        
        // Notify listeners about session change
        _syncUpdates.add({
          'type': 'local_session_change_sent',
          'table': table,
          'operation': operation,
          'recordId': recordId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
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
    _stopPeriodicSync(); // Stop periodic sync timers
    await disconnect();
  }

  /// Clear cached sync settings from SharedPreferences
  static Future<void> clearCachedSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lan_server_ip');
      await prefs.remove('lan_server_port');
      await prefs.remove('lan_access_code');
      await prefs.setBool('sync_enabled', false);
      
      // Also disconnect current connection
      await disconnect();
      
      debugPrint('Cleared cached sync settings');
    } catch (e) {
      debugPrint('Error clearing cached sync settings: $e');
    }
  }

  /// Get current sync settings
  static Future<Map<String, dynamic>> getCurrentSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'serverIp': prefs.getString('lan_server_ip'),
        'serverPort': prefs.get('lan_server_port'),
        'accessCode': prefs.getString('lan_access_code'),
        'syncEnabled': prefs.getBool('sync_enabled') ?? false,
        'isConnected': _isConnected,
        'currentServerIp': _serverIp,
        'currentServerPort': _serverPort,
      };
    } catch (e) {
      debugPrint('Error getting sync settings: $e');
      return {};
    }
  }

  /// Save sync settings to SharedPreferences
  static Future<void> saveSyncSettings(String serverIp, int port, String accessCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lan_server_ip', serverIp);
      await prefs.setInt('lan_server_port', port);
      await prefs.setString('lan_access_code', accessCode);
      await prefs.setBool('sync_enabled', true);
      
      debugPrint('Saved sync settings: $serverIp:$port');
    } catch (e) {
      debugPrint('Error saving sync settings: $e');
    }
  }

  /// Start periodic sync for queue updates
  static void _startPeriodicSync() {
    // Cancel existing timer if any
    _periodicSyncTimer?.cancel();
    _queueRefreshTimer?.cancel();
    
    // Start periodic sync check every 30 seconds for normal updates
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _wsChannel != null) {
        _requestQueueSync();
        _requestAppointmentSync(); // Also sync appointments
        _requestUserAndPasswordSync(); // Also sync user/password changes
      } else {
        // Even when not connected, trigger UI refresh for local changes
        _broadcastUIRefresh();
      }
    });
    
    debugPrint('Started enhanced periodic sync: queue/appointment/user sync every 30s');
  }

  /// Request specific queue table sync
  static void _requestQueueSync() {
    if (_isConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'active_patient_queue',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Request appointments table sync
  static void _requestAppointmentSync() {
    if (_isConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'appointments',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Request user/password changes sync
  static void _requestUserAndPasswordSync() {
    if (_isConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'users',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'user_activity_log',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'patient_history',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Broadcast UI refresh event
  static void _broadcastUIRefresh() {
    _syncUpdates.add({
      'type': 'ui_refresh_requested',
      'timestamp': DateTime.now().toIso8601String(),
      'tables': ['active_patient_queue', 'appointments', 'users', 'user_activity_log', 'patient_history', 'patient_bills', 'payments'],
      'source': 'periodic_refresh',
    });
  }

  /// Trigger immediate UI refresh for queue changes
  static void triggerQueueRefresh() {
    _syncUpdates.add({
      'type': 'queue_change_immediate',
      'table': 'active_patient_queue',
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'queue_operation',
    });
    
    // Also request immediate sync if connected
    if (_isConnected && _wsChannel != null) {
      _requestQueueSync();
    }
  }

  /// Force refresh of all queues
  static void forceQueueRefresh() {
    _syncUpdates.add({
      'type': 'force_queue_refresh',
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'force_refresh',
      'tables': ['active_patient_queue', 'appointments'],
    });
    
    // Request immediate sync for all relevant tables
    if (_isConnected && _wsChannel != null) {
      _requestQueueSync();
      _requestAppointmentSync();
    }
  }

  /// Trigger immediate refresh for appointments
  static void triggerAppointmentRefresh() {
    _syncUpdates.add({
      'type': 'appointment_change_immediate',
      'table': 'appointments',
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'appointment_operation',
    });
    
    // Also request immediate sync if connected
    if (_isConnected && _wsChannel != null) {
      _requestAppointmentSync();
    }
  }

  /// Trigger immediate refresh for user/password changes
  static void triggerUserPasswordSync() {
    _syncUpdates.add({
      'type': 'user_password_change_immediate',
      'table': 'users',
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'password_reset_operation',
    });
    
    // Also request immediate sync if connected
    if (_isConnected && _wsChannel != null) {
      _requestUserAndPasswordSync();
    }
  }

  /// Broadcast a custom message to all connected devices
  static void broadcastMessage(Map<String, dynamic> message) {
    if (_isConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode(message));
        debugPrint('Broadcasting message: ${message['type']}');
      } catch (e) {
        debugPrint('Error broadcasting message: $e');
      }
    } else {
      debugPrint('Cannot broadcast message - not connected to server');
    }
  }

  /// Handle session invalidation messages
  static void handleSessionInvalidation(Map<String, dynamic> data) {
    _syncUpdates.add({
      'type': 'session_invalidated',
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Stop periodic sync timers
  static void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _queueRefreshTimer?.cancel();
    _periodicSyncTimer = null;
    _queueRefreshTimer = null;
    debugPrint('Stopped periodic sync timers');
  }

  /// Check for authentication conflicts after session sync
  static void _checkAuthenticationConflicts() {
    try {
      // Notify about potential authentication conflicts
      _syncUpdates.add({
        'type': 'auth_conflict_check_needed',
        'timestamp': DateTime.now().toIso8601String(),
        'reason': 'session_table_sync_completed',
      });
      
      debugPrint('DatabaseSyncClient: Triggered authentication conflict check after session sync');
    } catch (e) {
      debugPrint('DatabaseSyncClient: Error checking authentication conflicts: $e');
    }
  }

  /// Request immediate session sync from host server
  static void requestImmediateSessionSync() {
    if (_isConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'request_immediate_table_sync',
          'table': 'user_sessions',
          'priority': 'immediate',
          'timestamp': DateTime.now().toIso8601String(),
        }));
        
        // Also trigger session validation
        _syncUpdates.add({
          'type': 'immediate_session_sync_requested',
          'table': 'user_sessions',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'real_time_login',
        });
        
        debugPrint('DatabaseSyncClient: Requested immediate session sync from host');
      } catch (e) {
        debugPrint('DatabaseSyncClient: Error requesting immediate session sync: $e');
      }
    } else {
      debugPrint('DatabaseSyncClient: Cannot request immediate sync - not connected');
    }
  }

  /// Force immediate session table sync - called when sessions change
  static Future<void> forceSessionSync() async {
    if (_isConnected && _wsChannel != null) {
      try {
        // Request immediate session table sync
        _wsChannel!.sink.add(jsonEncode({
          'type': 'request_immediate_table_sync',
          'table': 'user_sessions',
          'priority': 'critical',
          'reason': 'session_change',
          'timestamp': DateTime.now().toIso8601String(),
        }));
        
        // Wait a moment then perform manual sync
        await Future.delayed(const Duration(milliseconds: 1000));
        await manualSync();
        
        debugPrint('DatabaseSyncClient: Forced immediate session sync completed');
      } catch (e) {
        debugPrint('DatabaseSyncClient: Error forcing session sync: $e');
      }
    }
  }
}
