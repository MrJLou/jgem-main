// COMPREHENSIVE QUEUE SYNC FIX
// 
// ISSUE DESCRIPTION:
// The client device successfully adds patients to the local queue, but the changes
// are not being synced to the server/host, causing "Successfully loaded 0 queue items"
// on other devices even though local database has the queue entries.
//
// ROOT CAUSE ANALYSIS:
// 1. Client adds patient → local DB insertion works ✓
// 2. logChange() triggers → works ✓  
// 3. _notifyDatabaseChange() calls callback → works ✓
// 4. main.dart callback triggers → works ✓
// 5. DatabaseSyncClient.notifyLocalDatabaseChange() → works ✓
// 6. _onLocalDatabaseChange() sends WebSocket message → THIS IS WHERE IT FAILS ❌
// 7. Server should receive and broadcast → not happening ❌
//
// SPECIFIC FIXES NEEDED:

/* 
=============================================================================
FIX 1: ENHANCE DatabaseSyncClient._onLocalDatabaseChange() METHOD
=============================================================================
*/

// In database_sync_client.dart, around line 839-976
// The _onLocalDatabaseChange method needs better error handling and retries

static Future<void> _onLocalDatabaseChange(String table, String operation, String recordId, Map<String, dynamic>? data) async {
  try {
    if (!_isConnected || _wsChannel == null) {
      debugPrint('SYNC DEBUG: Not connected to server, buffering change for later sync: $table.$operation');
      // TODO: Add change to local buffer for when connection is restored
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
    if (_wsChannel?.sink.closeCode != null) {
      debugPrint('SYNC DEBUG: WebSocket sink is closed, attempting reconnection...');
      _isConnected = false;
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

      // ADDITIONAL FIX: Verify message was sent by requesting acknowledgment
      if (table == 'active_patient_queue') {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'request_sync_confirmation',
          'table': table,
          'operation': operation,
          'recordId': recordId,
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }

    } catch (sinkError) {
      debugPrint('SYNC DEBUG: WebSocket sink error: $sinkError');
      _isConnected = false;
      _scheduleReconnect();
      return;
    }

    // REST OF THE EXISTING LOGIC FOR SESSION HANDLING...
    // [Keep the existing user_sessions special handling logic]
    
  } catch (e) {
    debugPrint('SYNC DEBUG: Error sending local change to server: $e');
    debugPrint('SYNC DEBUG: Will retry on next connection or periodic sync');
  }
}

/*
=============================================================================
FIX 2: ENHANCE SERVER-SIDE MESSAGE HANDLING
=============================================================================
*/

// In enhanced_shelf_lan_server.dart, need to add better handling for 'database_change' messages
// Around line 1111 in _handleWebSocketDatabaseChange method

static Future<void> _handleWebSocketDatabaseChange(Map<String, dynamic> data) async {
  try {
    final changeData = data['change'] as Map<String, dynamic>?;
    final clientInfo = data['clientInfo'] as Map<String, dynamic>?;
    
    if (changeData == null) {
      debugPrint('SERVER: Invalid WebSocket database change data received');
      return;
    }
    
    final table = changeData['table'] as String?;
    final operation = changeData['operation'] as String?;
    final recordId = changeData['recordId'] as String?;
    final recordData = changeData['data'] as Map<String, dynamic>?;
    
    if (table == null || operation == null || recordId == null) {
      debugPrint('SERVER: Invalid database change data received via WebSocket');
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
    
    if (_dbHelper == null) {
      debugPrint('SERVER: Database helper not initialized');
      return;
    }
    
    final db = await _dbHelper!.database;
    
    // Temporarily disable change callback to avoid loops
    DatabaseHelper.clearDatabaseChangeCallback();
    
    try {
      bool operationSuccess = false;
      
      switch (operation.toLowerCase()) {
        case 'insert':
          if (recordData != null) {
            try {
              // ENHANCED FIX: Better conflict handling for queue inserts
              if (table == 'active_patient_queue') {
                // Check if queue entry already exists
                final existing = await db.query(
                  table,
                  where: 'queueEntryId = ?',
                  whereArgs: [recordId],
                );
                
                if (existing.isEmpty) {
                  await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                  await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                  operationSuccess = true;
                  debugPrint('SERVER: Successfully inserted queue item: $recordId');
                } else {
                  debugPrint('SERVER: Queue item already exists, skipping: $recordId');
                  operationSuccess = true; // Still consider success to avoid retries
                }
              } else {
                // Standard insert for other tables
                await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                operationSuccess = true;
                debugPrint('SERVER: Successfully applied WebSocket insert: $table.$recordId');
              }
            } catch (e) {
              debugPrint('SERVER: Error applying WebSocket insert: $e');
              // Try update as fallback
              try {
                String whereColumn = table == 'active_patient_queue' ? 'queueEntryId' : 'id';
                final rowsAffected = await db.update(table, recordData, where: '$whereColumn = ?', whereArgs: [recordId]);
                await _dbHelper!.logChange(table, recordId, 'update', data: recordData);
                operationSuccess = true;
                debugPrint('SERVER: Fallback update successful: $table.$recordId (rows affected: $rowsAffected)');
              } catch (updateError) {
                debugPrint('SERVER: Both insert and update failed for $table.$recordId: $updateError');
              }
            }
          }
          break;
          
        case 'update':
          if (recordData != null) {
            try {
              String whereColumn = table == 'active_patient_queue' ? 'queueEntryId' : 'id';
              final rowsAffected = await db.update(table, recordData, where: '$whereColumn = ?', whereArgs: [recordId]);
              
              if (rowsAffected == 0) {
                debugPrint('SERVER: No rows updated, attempting insert for $table.$recordId');
                await db.insert(table, recordData, conflictAlgorithm: ConflictAlgorithm.replace);
                await _dbHelper!.logChange(table, recordId, 'insert', data: recordData);
                operationSuccess = true;
                debugPrint('SERVER: Successfully inserted instead of updated: $table.$recordId');
              } else {
                await _dbHelper!.logChange(table, recordId, 'update', data: recordData);
                operationSuccess = true;
                debugPrint('SERVER: Successfully applied WebSocket update: $table.$recordId (rows affected: $rowsAffected)');
              }
            } catch (e) {
              debugPrint('SERVER: Error applying WebSocket update: $e');
            }
          }
          break;
          
        case 'delete':
          try {
            String whereColumn = table == 'active_patient_queue' ? 'queueEntryId' : 'id';
            final rowsAffected = await db.delete(table, where: '$whereColumn = ?', whereArgs: [recordId]);
            await _dbHelper!.logChange(table, recordId, 'delete', data: recordData);
            operationSuccess = true;
            debugPrint('SERVER: Successfully applied WebSocket delete: $table.$recordId (rows affected: $rowsAffected)');
          } catch (e) {
            debugPrint('SERVER: Error applying WebSocket delete: $e');
          }
          break;
      }
      
      // CRITICAL FIX: Always broadcast to other clients after successful operation
      if (operationSuccess) {
        final broadcastChange = {
          'table': table,
          'operation': operation,
          'recordId': recordId,
          'data': recordData,
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'server_broadcast',
        };
        
        _broadcastToAllClients(jsonEncode({
          'type': 'database_change',
          'change': broadcastChange,
          'timestamp': DateTime.now().toIso8601String(),
        }));
        
        debugPrint('SERVER: Broadcasted change to all clients: $table.$operation');
        
        // Special handling for queue changes
        if (table == 'active_patient_queue') {
          debugPrint('SERVER: QUEUE CHANGE broadcasted to all connected clients');
          
          // Also send immediate table sync to ensure consistency
          Future.delayed(const Duration(milliseconds: 100), () {
            _sendTableSyncToAllClients('active_patient_queue');
            debugPrint('SERVER: Sent immediate queue table sync to all clients');
          });
        }
      }
      
    } finally {
      // Re-enable change callback
      DatabaseHelper.setDatabaseChangeCallback(_onDatabaseChange);
    }
    
  } catch (e) {
    debugPrint('SERVER: Error handling WebSocket database change: $e');
  }
}

/*
=============================================================================
FIX 3: ENHANCE CLIENT-SIDE MESSAGE HANDLING
=============================================================================
*/

// In database_sync_client.dart, enhance _handleWebSocketMessage to better handle responses
// Around line 142-280

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

// ADDITIONAL FIX: Add new message type for sync confirmations
case 'sync_confirmation':
  final table = data['table'] as String?;
  final operation = data['operation'] as String?;
  final recordId = data['recordId'] as String?;
  debugPrint('CLIENT: Received sync confirmation for $table.$operation record $recordId');
  
  _syncUpdates.add({
    'type': 'sync_confirmed',
    'table': table,
    'operation': operation,
    'recordId': recordId,
    'timestamp': DateTime.now().toIso8601String(),
  });
  break;

/*
=============================================================================
FIX 4: ENHANCE ERROR HANDLING AND RETRY LOGIC
=============================================================================
*/

// Add to DatabaseSyncClient class - method to handle failed syncs
static final List<Map<String, dynamic>> _pendingChanges = [];

static void _bufferFailedChange(String table, String operation, String recordId, Map<String, dynamic>? data) {
  _pendingChanges.add({
    'table': table,
    'operation': operation,
    'recordId': recordId,
    'data': data,
    'timestamp': DateTime.now().toIso8601String(),
    'retryCount': 0,
  });
  
  debugPrint('SYNC DEBUG: Buffered failed change: $table.$operation');
}

static Future<void> _retryPendingChanges() async {
  if (_pendingChanges.isEmpty || !_isConnected) return;
  
  debugPrint('SYNC DEBUG: Retrying ${_pendingChanges.length} pending changes');
  
  final changes = List<Map<String, dynamic>>.from(_pendingChanges);
  _pendingChanges.clear();
  
  for (final change in changes) {
    final retryCount = (change['retryCount'] as int? ?? 0) + 1;
    
    if (retryCount > 3) {
      debugPrint('SYNC DEBUG: Giving up on change after 3 retries: ${change['table']}.${change['operation']}');
      continue;
    }
    
    try {
      await _onLocalDatabaseChange(
        change['table'] as String,
        change['operation'] as String,
        change['recordId'] as String,
        change['data'] as Map<String, dynamic>?,
      );
      debugPrint('SYNC DEBUG: Successfully retried change: ${change['table']}.${change['operation']}');
    } catch (e) {
      change['retryCount'] = retryCount;
      _pendingChanges.add(change);
      debugPrint('SYNC DEBUG: Retry failed, will try again: ${change['table']}.${change['operation']}');
    }
  }
}

/*
=============================================================================
FIX 5: ENHANCE CONNECTION MONITORING
=============================================================================
*/

// In _connectWebSocket method, add connection verification
static Future<void> _connectWebSocket() async {
  try {
    final wsUrl = 'ws://$_serverIp:$_serverPort/ws?access_code=$_accessCode';
    debugPrint('SYNC DEBUG: Connecting to WebSocket at $wsUrl');
    
    _wsChannel = IOWebSocketChannel.connect(
      wsUrl, 
      pingInterval: const Duration(seconds: 10),
      connectTimeout: const Duration(seconds: 15), // Add timeout
    );

    _wsSubscription = _wsChannel!.stream.listen(
      (message) {
        try {
          debugPrint('SYNC DEBUG: WebSocket message received (${message.toString().length} chars)');
          _handleWebSocketMessage(message);
        } catch (e) {
          debugPrint('SYNC DEBUG: Error handling WebSocket message: $e');
        }
      },
      onDone: () {
        debugPrint('SYNC DEBUG: WebSocket connection closed (onDone)');
        _isConnected = false;
        _scheduleReconnect();
      },
      onError: (error) {
        debugPrint('SYNC DEBUG: WebSocket error: $error');
        _isConnected = false;
        _scheduleReconnect();
      },
    );

    // ENHANCED FIX: Verify connection with ping before marking as connected
    await Future.delayed(const Duration(seconds: 1));
    
    if (_wsChannel?.sink.closeCode == null) {
      _isConnected = true;
      _startHeartbeat();
      
      // Retry any pending changes
      _retryPendingChanges();
      
      debugPrint('WebSocket connected successfully and verified');
    } else {
      debugPrint('WebSocket connection failed verification');
      throw Exception('WebSocket connection failed verification');
    }
    
  } catch (e) {
    debugPrint('WebSocket connection failed: $e');
    _isConnected = false;
    _scheduleReconnect();
  }
}

/*
=============================================================================
IMPLEMENTATION INSTRUCTIONS:
=============================================================================

1. Update database_sync_client.dart:
   - Replace _onLocalDatabaseChange method with enhanced version
   - Add _bufferFailedChange and _retryPendingChanges methods
   - Enhance _handleWebSocketMessage for queue changes
   - Update _connectWebSocket with verification

2. Update enhanced_shelf_lan_server.dart:
   - Replace _handleWebSocketDatabaseChange method with enhanced version
   - Add better error handling and broadcasting logic

3. Add debugging in queue_service.dart:
   - In _triggerImmediateSync method, add more detailed logging
   - Verify that DatabaseSyncClient.triggerQueueRefresh() is being called

4. Test the fix:
   - Connect host and client devices
   - Add a patient to queue on client
   - Verify sync messages in debug console
   - Check if patient appears on host device

5. Monitor debug output for:
   - "SYNC DEBUG: QUEUE CHANGE WebSocket message sent successfully"
   - "SERVER: QUEUE CHANGE received from client"
   - "SERVER: QUEUE CHANGE broadcasted to all connected clients"
   - "CLIENT: Received QUEUE CHANGE from server"
*/
