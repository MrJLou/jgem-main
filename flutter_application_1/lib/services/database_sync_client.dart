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
  
  // Prevent infinite sync loops
  static DateTime? _lastAuthConflictCheck;
  static DateTime? _lastSessionSyncRequest;
  static bool _isProcessingSessionSync = false;

  static bool get isConnected => _isConnected;
  static Stream<Map<String, dynamic>> get syncUpdates => _syncUpdates.stream;

  /// Initialize the client
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    _dbHelper = dbHelper;
    
    // NOTE: Database change callback is now handled in main.dart to prevent conflicts
    
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
      debugPrint('SYNC DEBUG: Connecting to WebSocket at $wsUrl');
      _wsChannel = IOWebSocketChannel.connect(wsUrl, pingInterval: const Duration(seconds: 10));

      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          try {
            debugPrint('SYNC DEBUG: WebSocket message received');
            _handleWebSocketMessage(message);
          } catch (e) {
            debugPrint('SYNC DEBUG: Error handling WebSocket message: $e');
          }
        },
        onDone: () {
          debugPrint('SYNC DEBUG: WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('SYNC DEBUG: WebSocket error: $error');
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
          final changeData = data['change'] as Map<String, dynamic>?;
          if (changeData != null) {
            final table = changeData['table'] as String?;
            final operation = changeData['operation'] as String?;
            
            // ENHANCED FIX: Add specific logging for queue changes
            if (table == 'active_patient_queue') {
              debugPrint('CLIENT: Received QUEUE CHANGE from server - operation=$operation');
              debugPrint('CLIENT: Queue change data: $changeData');
            }
            
            _handleRemoteDatabaseChange(changeData);
            
            // ADDITIONAL FIX: Trigger immediate UI refresh for queue changes
            if (table == 'active_patient_queue') {
              _syncUpdates.add({
                'type': 'queue_change_immediate',
                'table': table,
                'operation': operation,
                'timestamp': DateTime.now().toIso8601String(),
                'source': 'server_broadcast',
              });
              
              debugPrint('CLIENT: Triggered immediate queue UI refresh');
            }
          }
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
            
            // For user_sessions, implement stronger loop prevention
            if (tableName == 'user_sessions') {
              final now = DateTime.now();
              
              // Check if we're already processing session sync
              if (_isProcessingSessionSync) {
                debugPrint('SYNC_LOOP_PREVENTION: Ignoring force_table_sync for user_sessions - already processing');
                break;
              }
              
              // Check if we've recently processed this table (increased to 30 seconds)
              if (_lastSessionSyncRequest != null && 
                  now.difference(_lastSessionSyncRequest!).inSeconds < 30) {
                debugPrint('SYNC_LOOP_PREVENTION: Ignoring force_table_sync for user_sessions - too recent (${now.difference(_lastSessionSyncRequest!).inSeconds}s ago)');
                break;
              }
              
              // Set processing flags
              _lastSessionSyncRequest = now;
              _isProcessingSessionSync = true;
              
              debugPrint('SYNC_LOOP_PREVENTION: Processing user_sessions sync (will block for 30s)');
              
              // Reset processing flag after longer delay
              Future.delayed(const Duration(seconds: 30), () {
                _isProcessingSessionSync = false;
                debugPrint('SYNC_LOOP_PREVENTION: Released user_sessions sync lock');
              });
            }
            
            // Request specific table sync (only if not blocked)
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

  /// Request user sessions table sync - CRITICAL for authentication consistency
  static void _requestSessionSync() {
    if (_isConnected && _wsChannel != null) {
      // Prevent excessive session sync requests - limit to once every 60 seconds (increased from 30s)
      final now = DateTime.now();
      if (_lastSessionSyncRequest != null && 
          now.difference(_lastSessionSyncRequest!).inSeconds < 60) {
        debugPrint('PERIODIC_SYNC: Skipping session sync - too recent (${now.difference(_lastSessionSyncRequest!).inSeconds}s ago)');
        return;
      }
      
      _lastSessionSyncRequest = now;
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'user_sessions',
        'priority': 'high',
        'timestamp': now.toIso8601String(),
      }));
      debugPrint('PERIODIC_SYNC: Requested user_sessions table sync');
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
        // Re-enable change callback - handled in main.dart now
        // DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
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
        // Filter data based on table schema before processing
        Map<String, dynamic>? filteredData;
        if (data != null) {
          filteredData = Map<String, dynamic>.from(data);
          
          // Filter out non-database fields for user_sessions table
          if (table == 'user_sessions') {
            // Remove fields that don't exist in the database schema
            filteredData.remove('type');
            filteredData.remove('action');
            filteredData.remove('timestamp'); // Use database-specific timestamp fields
            
            // Map snake_case field names from server to camelCase for database
            if (filteredData.containsKey('session_token')) {
              filteredData['sessionToken'] = filteredData.remove('session_token');
            }
            if (filteredData.containsKey('device_id')) {
              filteredData['deviceId'] = filteredData.remove('device_id');
            }
            if (filteredData.containsKey('device_name')) {
              filteredData['deviceName'] = filteredData.remove('device_name');
            }
            
            debugPrint('SYNC_CLIENT: Filtered user_sessions data - removed non-schema fields (type, action, timestamp)');
            debugPrint('SYNC_CLIENT: Mapped snake_case to camelCase field names');
            debugPrint('SYNC_CLIENT: Remaining fields: ${filteredData.keys.toList()}');
          }
        }

        // Use shorter transactions to prevent database locking
        // Apply each change individually to avoid long-running transactions
        switch (operation.toLowerCase()) {
          case 'insert':
            if (filteredData != null) {
              final dataToInsert = filteredData; // Create non-null reference
              try {
                if (table == 'user_sessions') {
                  // Check if session already exists by sessionToken to prevent duplicates
                  if (dataToInsert['sessionToken'] != null) {
                    final sessionToken = dataToInsert['sessionToken'] as String;
                    await db.transaction((txn) async {
                      final existing = await txn.query(
                        table,
                        where: 'sessionToken = ?',
                        whereArgs: [sessionToken],
                      );
                      
                      if (existing.isNotEmpty) {
                        // Update existing session instead of creating duplicate
                        final rowsAffected = await txn.update(
                          table, 
                          dataToInsert, 
                          where: 'sessionToken = ?', 
                          whereArgs: [sessionToken]
                        );
                        debugPrint('Updated existing session instead of duplicate insert: $table.$recordId (rows affected: $rowsAffected)');
                      } else {
                        // Insert new session
                        await txn.insert(table, dataToInsert, conflictAlgorithm: ConflictAlgorithm.replace);
                        debugPrint('Successfully applied remote session insert: $table.$recordId');
                      }
                    });
                  } else {
                    // Fallback to normal insert if no sessionToken
                    await db.insert(table, dataToInsert, conflictAlgorithm: ConflictAlgorithm.replace);
                    debugPrint('Successfully applied remote insert: $table.$recordId');
                  }
                } else {
                  // Always use INSERT OR REPLACE for all other inserts to handle conflicts
                  await db.insert(table, dataToInsert, conflictAlgorithm: ConflictAlgorithm.replace);
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
                  
                  // Use filtered data for fallback update as well
                  final rowsAffected = await db.update(table, dataToInsert, where: '$whereColumn = ?', whereArgs: [recordId]);
                  debugPrint('Fallback update successful: $table.$recordId (rows affected: $rowsAffected)');
                } catch (updateError) {
                  debugPrint('Both insert and update failed for $table.$recordId: $updateError');
                }
              }
            }
            break;
          case 'update':
            if (filteredData != null) {
              final dataToUpdate = filteredData; // Create non-null reference
              try {
                String whereColumn = 'id';
                // Handle special cases for tables with different primary key columns
                if (table == 'active_patient_queue') {
                  whereColumn = 'queueEntryId';
                } else if (table == 'user_sessions') {
                  whereColumn = 'id';
                }
                
                final rowsAffected = await db.update(table, dataToUpdate, where: '$whereColumn = ?', whereArgs: [recordId]);
                
                // If no rows were affected, try inserting the record
                if (rowsAffected == 0) {
                  debugPrint('No rows updated, attempting insert for $table.$recordId');
                  await db.insert(table, dataToUpdate, conflictAlgorithm: ConflictAlgorithm.replace);
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
        } else if (table == 'patient_bills' || table == 'payments' || table == 'bill_items') {
          _syncUpdates.add({
            'type': 'billing_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
          });
        } else if (table == 'patients' || table == 'patient_history' || table == 'medical_records') {
          _syncUpdates.add({
            'type': 'patient_data_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
          });
        } else if (table == 'users' || table == 'user_activity_log') {
          _syncUpdates.add({
            'type': 'user_data_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
          });
        } else {
          // Generic immediate update for other tables
          _syncUpdates.add({
            'type': 'data_change_immediate',
            'table': table,
            'operation': operation,
            'recordId': recordId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'remote_sync',
          });
        }
        
        // Add general change notification
        _syncUpdates.add({
          'type': 'remote_change_applied',
          'change': change,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } finally {
        // Re-enable change callback - handled in main.dart now  
        // DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
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
          
          // Process user_sessions in a smaller transaction
          // Since this table typically has very few records, we can process them in a single transaction
          await db.transaction((txn) async {
            // Insert or replace each session record individually
            for (final record in tableData) {
              final recordMap = record as Map<String, dynamic>;
              
              try {
                // For user_sessions, use the sessionToken as the unique identifier if available
                // This prevents duplicate sessions for the same user/device combination
                if (recordMap['sessionToken'] != null) {
                  // First check if a session with this token already exists
                  final existingSession = await txn.query(
                    tableName,
                    where: 'sessionToken = ?',
                    whereArgs: [recordMap['sessionToken']],
                    columns: ['id'], // Only get ID to minimize data transfer
                  );
                  
                  if (existingSession.isNotEmpty) {
                    // Update existing session record
                    await txn.update(
                      tableName,
                      recordMap,
                      where: 'sessionToken = ?',
                      whereArgs: [recordMap['sessionToken']],
                    );
                    debugPrint('Updated existing session: ${recordMap['sessionToken']}');
                  } else {
                    // Insert new session record
                    await txn.insert(
                      tableName, 
                      recordMap,
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                    debugPrint('Inserted new session: ${recordMap['sessionToken']}');
                  }
                } else {
                  // Fallback to standard INSERT OR REPLACE by ID
                  await txn.insert(
                    tableName, 
                    recordMap,
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
              } catch (e) {
                debugPrint('Error syncing session record ${recordMap['id']}: $e');
              }
            }
          });
        } else {
          // For other tables, use batch operations for better performance
          final batch = db.batch();
          
          // Clear existing data first
          batch.delete(tableName);
          
          // Add all records to the batch
          for (final record in tableData) {
            final recordMap = record as Map<String, dynamic>;
            batch.insert(
              tableName, 
              recordMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          
          // Execute all operations in a single transaction
          await batch.commit(noResult: true);
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
          
          // Only trigger session validation if we're not already processing session sync
          // and it's been at least 30 seconds since the last auth conflict check (increased from 10s)
          final now = DateTime.now();
          if (!_isProcessingSessionSync && 
              (_lastAuthConflictCheck == null || 
               now.difference(_lastAuthConflictCheck!).inSeconds >= 30)) {
            
            _lastAuthConflictCheck = now;
            _syncUpdates.add({
              'type': 'session_sync_validation_needed',
              'table': tableName,
              'timestamp': now.toIso8601String(),
            });
            
            // Check for authentication conflicts with longer debouncing (increased from 2s)
            Future.delayed(const Duration(seconds: 5), () {
              if (!_isProcessingSessionSync) {
                _checkAuthenticationConflicts();
              }
            });
          } else {
            debugPrint('CROSS_DEVICE_MONITOR: Skipping auth conflict check - too recent or already processing (${_lastAuthConflictCheck != null ? now.difference(_lastAuthConflictCheck!).inSeconds : 'N/A'}s ago)');
          }
        }
      } finally {
        // Re-enable change callback - handled in main.dart now
        // DatabaseHelper.setDatabaseChangeCallback(_onLocalDatabaseChange);
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
        debugPrint('SYNC DEBUG: Not connected to server, change will sync later: $table.$operation');
        return;
      }

      debugPrint('SYNC DEBUG: Sending local change to server: $table.$operation for record $recordId');
      
      // Extra debug for queue changes
      if (table == 'active_patient_queue') {
        debugPrint('SYNC DEBUG: QUEUE CHANGE - operation=$operation, recordId=$recordId');
        if (data != null) {
          debugPrint('SYNC DEBUG: QUEUE DATA - patientName=${data['patientName']}, status=${data['status']}');
        }
      }

      final changeMessage = {
        'type': 'database_change',
        'change': {
          'table': table,
          'operation': operation,
          'recordId': recordId,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'client',
          'deviceId': await _getDeviceId(),
        },
        'clientInfo': {
          'timestamp': DateTime.now().toIso8601String(),
          'deviceId': await _getDeviceId(),
        }
      };

      // CRITICAL FIX: Add connection verification before sending
      if (!_isConnected || _wsChannel == null) {
        debugPrint('SYNC DEBUG: Connection lost, attempting reconnection...');
        _scheduleReconnect();
        return;
      }

      try {
        _wsChannel!.sink.add(jsonEncode(changeMessage));
        debugPrint('SYNC DEBUG: Successfully sent local change to server via WebSocket: $table.$operation');
        
        if (table == 'active_patient_queue') {
          debugPrint('SYNC DEBUG: QUEUE CHANGE WebSocket message sent successfully');
          
          // ADDITIONAL FIX: Force immediate queue sync request as backup
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_isConnected && _wsChannel != null) {
              _requestQueueSync();
              debugPrint('SYNC DEBUG: Backup queue sync request sent');
            }
          });
        }

      } catch (sinkError) {
        debugPrint('SYNC DEBUG: WebSocket sink error: $sinkError');
        _isConnected = false;
        _scheduleReconnect();
        return;
      }

      // CRITICAL: Special handling for user_sessions table - IMMEDIATE sync required
      if (table == 'user_sessions') {
        debugPrint('SESSION_SYNC: CRITICAL - User session $operation detected - triggering IMMEDIATE sync');
        
        // Check if we're already processing a session sync to prevent floods
        final now = DateTime.now();
        if (_isProcessingSessionSync) {
          debugPrint('SESSION_SYNC: Already processing a session sync - skipping additional sync requests');
        } else if (_lastSessionSyncRequest != null && 
                  now.difference(_lastSessionSyncRequest!).inSeconds < 15) {
          debugPrint('SESSION_SYNC: Recent sync detected (${now.difference(_lastSessionSyncRequest!).inSeconds}s ago) - using single sync request');
          
          // Just send one high-priority sync request
          _wsChannel!.sink.add(jsonEncode({
            'type': 'force_immediate_session_sync',
            'table': 'user_sessions',
            'priority': 'critical',
            'operation': operation,
            'recordId': recordId,
            'data': data,
            'timestamp': DateTime.now().toIso8601String(),
          }));
        } else {
          // Set processing flag
          _isProcessingSessionSync = true;
          _lastSessionSyncRequest = now;
          
          // Send a single sync request with critical priority
          _wsChannel!.sink.add(jsonEncode({
            'type': 'force_immediate_session_sync',
            'table': 'user_sessions',
            'priority': 'critical',
            'operation': operation,
            'recordId': recordId,
            'data': data,
            'timestamp': now.toIso8601String(),
          }));
          
          // Trigger manual sync to ensure session data reaches the host after a delay
          Future.delayed(const Duration(seconds: 1), () async {
            try {
              await manualSync();
              debugPrint('SESSION_SYNC: Manual sync completed for session $operation');
            } catch (e) {
              debugPrint('SESSION_SYNC: Error during manual sync for session $operation: $e');
            }
          });
          
          // Reset processing flag after some time
          Future.delayed(const Duration(seconds: 30), () {
            _isProcessingSessionSync = false;
            debugPrint('SESSION_SYNC: Released session sync lock after 30s timeout');
          });
        }
        
        // Notify listeners about session change
        _syncUpdates.add({
          'type': 'local_session_change_sent',
          'table': table,
          'operation': operation,
          'recordId': recordId,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error sending local change to server: $e');
    }
  }

  /// Public method to notify local database changes (called from main.dart callback)
  static Future<void> notifyLocalDatabaseChange(String table, String operation, String recordId, Map<String, dynamic>? data) async {
    await _onLocalDatabaseChange(table, operation, recordId, data);
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
    
    // Start periodic sync check every 3 minutes for normal updates (increased from 2 min to prevent overloading)
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (_isConnected && _wsChannel != null) {
        // Stagger requests to prevent database contention
        _requestQueueSync();
        
        // Delay each subsequent request to prevent overwhelming the database
        Future.delayed(const Duration(seconds: 5), () {
          _requestAppointmentSync();
        });
        
        Future.delayed(const Duration(seconds: 10), () {
          _requestUserAndPasswordSync();
        });
        
        // Only sync sessions if not already processing a session sync
        Future.delayed(const Duration(seconds: 15), () {
          if (!_isProcessingSessionSync) {
            _requestSessionSync();
          }
        });
        
        // Delay patient data sync to the end
        Future.delayed(const Duration(seconds: 20), () {
          _requestPatientDataSync();
        });
      } else {
        // Even when not connected, trigger UI refresh for local changes (now throttled)
        _broadcastUIRefresh();
      }
    });
    
    debugPrint('Started optimized periodic sync: staggered queue/appointment/user/session/patient-data sync every 3 minutes');
  }

  /// Request specific queue table sync
  static void _requestQueueSync() {
    if (_isConnected && _wsChannel != null) {
      debugPrint('SYNC DEBUG: Sending queue sync request via WebSocket');
      final message = jsonEncode({
        'type': 'request_table_sync',
        'table': 'active_patient_queue',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _wsChannel!.sink.add(message);
      debugPrint('SYNC DEBUG: Queue sync request sent to server: $message');
    } else {
      debugPrint('SYNC DEBUG: Cannot request queue sync - WebSocket not connected');
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

  /// Request patient-related data sync (bills, payments, history)
  static void _requestPatientDataSync() {
    if (_isConnected && _wsChannel != null) {
      // Sync patient bills and payment data
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'patient_bills',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'bill_items',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'payments',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'patient_history',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'patient_queue',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _wsChannel!.sink.add(jsonEncode({
        'type': 'request_table_sync',
        'table': 'medical_records',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
      debugPrint('SYNC_CLIENT: Requested patient data sync (bills, payments, history, medical records)');
    }
  }

  /// Broadcast UI refresh event with throttling
  static DateTime? _lastUIRefreshBroadcast;
  static void _broadcastUIRefresh() {
    // Throttle UI refresh broadcasts to every 60 seconds minimum
    final now = DateTime.now();
    if (_lastUIRefreshBroadcast != null && 
        now.difference(_lastUIRefreshBroadcast!).inSeconds < 60) {
      return; // Skip this broadcast due to throttling
    }
    
    _lastUIRefreshBroadcast = now;
    _syncUpdates.add({
      'type': 'ui_refresh_requested',
      'timestamp': now.toIso8601String(),
      'tables': [
        'active_patient_queue', 
        'appointments', 
        'users', 
        'user_activity_log', 
        'patient_history', 
        'patient_bills', 
        'bill_items',
        'payments',
        'medical_records',
        'patients',
        'clinic_services',
        'patient_queue'
      ],
      'source': 'periodic_refresh_throttled',
    });
  }

  /// Trigger immediate UI refresh for queue changes
  static void triggerQueueRefresh() {
    debugPrint('SYNC DEBUG: triggerQueueRefresh called, connected=${_isConnected}');
    
    _syncUpdates.add({
      'type': 'queue_change_immediate',
      'table': 'active_patient_queue',
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'queue_operation',
    });
    
    // Also request immediate sync if connected
    if (_isConnected && _wsChannel != null) {
      debugPrint('SYNC DEBUG: WebSocket is connected, requesting queue sync');
      _requestQueueSync();
    } else {
      debugPrint('SYNC DEBUG: WebSocket is NOT connected, skipping queue sync request');
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
      // Prevent excessive auth conflict checks - limit to once every 15 seconds
      final now = DateTime.now();
      if (_lastAuthConflictCheck != null && 
          now.difference(_lastAuthConflictCheck!).inSeconds < 15) {
        debugPrint('DatabaseSyncClient: Skipping auth conflict check - too recent (${now.difference(_lastAuthConflictCheck!).inSeconds}s ago)');
        return;
      }
      
      _lastAuthConflictCheck = now;
      
      // Notify about potential authentication conflicts
      _syncUpdates.add({
        'type': 'auth_conflict_check_needed',
        'timestamp': now.toIso8601String(),
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
        // Prevent excessive immediate session sync requests
        final now = DateTime.now();
        if (_isProcessingSessionSync) {
          debugPrint('DatabaseSyncClient: Already processing session sync - skipping immediate sync');
          return;
        }
        
        if (_lastSessionSyncRequest != null && 
            now.difference(_lastSessionSyncRequest!).inSeconds < 15) {
          debugPrint('DatabaseSyncClient: Skipping immediate session sync - too recent (${now.difference(_lastSessionSyncRequest!).inSeconds}s ago)');
          return;
        }
        
        _lastSessionSyncRequest = now;
        _isProcessingSessionSync = true;
        
        // Send single sync request to prevent loops
        _wsChannel!.sink.add(jsonEncode({
          'type': 'request_immediate_table_sync',
          'table': 'user_sessions',
          'priority': 'immediate',
          'timestamp': now.toIso8601String(),
        }));
        
        // Also trigger session validation
        _syncUpdates.add({
          'type': 'immediate_session_sync_requested',
          'table': 'user_sessions',
          'timestamp': now.toIso8601String(),
          'source': 'real_time_login',
        });
        
        debugPrint('DatabaseSyncClient: Requested immediate session sync from host');
        
        // Reset processing flag after a delay
        Future.delayed(const Duration(seconds: 15), () {
          _isProcessingSessionSync = false;
          debugPrint('DatabaseSyncClient: Released immediate sync lock');
        });
      } catch (e) {
        debugPrint('DatabaseSyncClient: Error requesting immediate session sync: $e');
        // Reset flag on error
        _isProcessingSessionSync = false;
      }
    } else {
      debugPrint('DatabaseSyncClient: Cannot request immediate sync - not connected');
    }
  }

  /// Force immediate session table sync - called when sessions change
  static Future<void> forceSessionSync() async {
    if (_isConnected && _wsChannel != null) {
      try {
        // Check if we're already processing or recently processed
        final now = DateTime.now();
        if (_isProcessingSessionSync) {
          debugPrint('DatabaseSyncClient: Already processing session sync - skipping force sync');
          return;
        }
        
        if (_lastSessionSyncRequest != null && 
            now.difference(_lastSessionSyncRequest!).inSeconds < 15) {
          debugPrint('DatabaseSyncClient: Recent session sync detected (${now.difference(_lastSessionSyncRequest!).inSeconds}s ago) - skipping force sync');
          return;
        }
        
        // Set processing flags
        _isProcessingSessionSync = true;
        _lastSessionSyncRequest = now;
        
        debugPrint('DatabaseSyncClient: Starting CONTROLLED session sync...');
        
        // Send a single critical priority request
        _wsChannel!.sink.add(jsonEncode({
          'type': 'request_immediate_table_sync',
          'table': 'user_sessions',
          'priority': 'critical',
          'reason': 'session_change',
          'timestamp': now.toIso8601String(),
        }));
        
        // Wait briefly then perform a single manual sync
        await Future.delayed(const Duration(seconds: 1));
        await manualSync();
        
        debugPrint('DatabaseSyncClient: CONTROLLED session sync completed');
        
        // Reset processing flag after delay
        Future.delayed(const Duration(seconds: 15), () {
          _isProcessingSessionSync = false;
          debugPrint('DatabaseSyncClient: Released session sync lock');
        });
      } catch (e) {
        debugPrint('DatabaseSyncClient: Error forcing session sync: $e');
        // Reset flag on error
        _isProcessingSessionSync = false;
      }
    } else {
      debugPrint('DatabaseSyncClient: Cannot force session sync - not connected');
    }
  }
}
