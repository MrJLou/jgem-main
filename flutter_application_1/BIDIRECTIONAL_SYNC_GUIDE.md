# Bidirectional Database Synchronization Implementation Guide

## Overview

Your Flutter application now has a robust bidirectional database synchronization system that ensures real-time data consistency between host and client devices on a local area network (LAN).

## Architecture Components

### 1. Database Helper (`database_helper.dart`)
- **Central database management** with SQLite
- **Change notification system** using callbacks
- **Transaction safety** with proper error handling
- **Real-time sync triggers** for all CRUD operations

### 2. Enhanced Shelf Server (`enhanced_shelf_lan_server.dart`)
- **WebSocket server** for real-time communication
- **HTTP REST API** for database operations
- **Host-side change broadcasting** to all connected clients
- **Client change processing** and propagation

### 3. Database Sync Client (`database_sync_client.dart`)
- **Client-side WebSocket connection** to host servers
- **Automatic reconnection** with backoff strategy
- **Remote change application** with conflict prevention
- **Device identification** to prevent sync loops

### 4. Socket Service (`socket_service.dart`)
- **Unified interface** for both hosting and client connections
- **Connection management** and status monitoring
- **Error handling** and recovery mechanisms

## Bidirectional Sync Flow

### Host to Client (Server → Client)

1. **Database Operation Occurs on Host**
   ```dart
   // Example: User creates a new patient on host device
   await dbHelper.insertPatient(patientData);
   ```

2. **DatabaseHelper Triggers Change Notification**
   ```dart
   await _notifyDatabaseChange('patients', 'insert', patientId, data: patientData);
   ```

3. **EnhancedShelfServer Receives Change**
   ```dart
   await EnhancedShelfServer.onDatabaseChange('patients', 'insert', patientId, patientData);
   ```

4. **WebSocket Broadcasting**
   ```dart
   _broadcastWebSocketChange({
     'table': 'patients',
     'operation': 'insert',
     'recordId': patientId,
     'data': patientData,
     'timestamp': DateTime.now().toIso8601String(),
   });
   ```

5. **Client Receives and Applies Change**
   ```dart
   // DatabaseSyncClient._handleRemoteDatabaseChange()
   await db.insert('patients', patientData, conflictAlgorithm: ConflictAlgorithm.replace);
   ```

### Client to Host (Client → Server)

1. **Database Operation Occurs on Client**
   ```dart
   // Example: User updates patient info on client device
   await dbHelper.updatePatient(updatedPatientData);
   ```

2. **DatabaseHelper Triggers Change Notification**
   ```dart
   await _notifyDatabaseChange('patients', 'update', patientId, data: updatedPatientData);
   ```

3. **DatabaseSyncClient Sends Change to Host**
   ```dart
   _wsChannel.sink.add(jsonEncode({
     'type': 'database_change',
     'change': {
       'table': 'patients',
       'operation': 'update',
       'recordId': patientId,
       'data': updatedPatientData,
       'source': 'client',
     },
     'clientInfo': {
       'deviceId': deviceId,
       'timestamp': DateTime.now().toIso8601String(),
     }
   }));
   ```

4. **Host Receives and Processes Change**
   ```dart
   // EnhancedShelfServer._handleWebSocketDatabaseChange()
   await db.update('patients', updatedPatientData, where: 'id = ?', whereArgs: [patientId]);
   ```

5. **Host Broadcasts to Other Clients**
   ```dart
   _broadcastWebSocketChange(changeData);
   ```

## Key Features

### 🔄 Real-Time Synchronization
- **Instant updates** across all connected devices
- **WebSocket-based** communication for minimal latency
- **Automatic change detection** and propagation

### 🛡️ Conflict Prevention
- **Device identification** prevents sync loops
- **Temporary callback disabling** during remote changes
- **Source tracking** to avoid circular updates

### 🔌 Connection Management
- **Automatic reconnection** with exponential backoff
- **Heartbeat monitoring** for connection health
- **Graceful error handling** and recovery

### 🔒 Data Integrity
- **Transaction safety** with proper rollback mechanisms
- **Conflict resolution** using replace strategy
- **Change logging** for audit trails

## Usage Examples

### Starting as Host Device

```dart
// Initialize the socket service
await SocketService.initialize(DatabaseHelper());

// Start hosting server
final hostingStarted = await SocketService.startHosting(port: 8080);

if (hostingStarted) {
  final connectionInfo = SocketService.getHostConnectionInfo();
  print('Server started! Access code: ${connectionInfo['accessCode']}');
  print('IP: ${connectionInfo['serverIp']}:${connectionInfo['port']}');
}
```

### Connecting as Client Device

```dart
// Initialize the socket service
await SocketService.initialize(DatabaseHelper());

// Connect to host server
final connected = await SocketService.connect(
  '192.168.1.100', // Host IP
  8080,           // Host port
  'ABCD1234'      // Access code from host
);

if (connected) {
  print('Connected to host server successfully!');
  
  // Listen for sync updates
  SocketService.stream.listen((update) {
    print('Received update: ${update['type']}');
  });
}
```

### Manual Synchronization

```dart
// Force a manual sync (useful for recovery)
final syncSuccess = await SocketService.manualSync();

if (syncSuccess) {
  print('Manual sync completed successfully');
} else {
  print('Manual sync failed');
}
```

### Getting Connection Status

```dart
final status = SocketService.getConnectionStatus();
print('Connected: ${status['isConnected']}');
print('Initialized: ${status['isInitialized']}');
print('Client Type: ${status['clientType']}');
```

## Error Handling and Recovery

### Connection Failures
- **Automatic retry** with exponential backoff
- **Connection status monitoring** and reporting
- **Graceful degradation** when offline

### Database Conflicts
- **Replace strategy** for insert conflicts
- **Detailed logging** for troubleshooting
- **Non-blocking error handling** to prevent app crashes

### Network Issues
- **Offline operation** support
- **Change queuing** for when connection is restored
- **Network state monitoring**

## Security Features

### Access Control
- **Generated access codes** for each host session
- **LAN-only access** with IP filtering
- **WebSocket authentication** using access codes

### Data Protection
- **Local network only** (no internet exposure)
- **Encrypted WebSocket** connections (WSS support)
- **Session-based access** with automatic expiration

## Performance Optimizations

### Memory Management
- **Change log size limits** (max 1000 entries)
- **Dead connection cleanup** to prevent memory leaks
- **Efficient JSON serialization** for large datasets

### Network Efficiency
- **Incremental sync** for large databases
- **Compressed message format** when possible
- **Batched operations** for multiple changes

### Database Optimization
- **Indexed tables** for faster queries
- **Transaction batching** for bulk operations
- **Connection pooling** for concurrent access

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check if host server is running
   - Verify network connectivity
   - Confirm access code is correct

2. **Sync Loops**
   - Device identification system prevents this
   - Check for proper callback clearing

3. **Data Inconsistency**
   - Force manual sync on all devices
   - Check network connectivity
   - Review error logs for failures

### Debug Commands

```dart
// Check server status
final hostStatus = SocketService.getHostConnectionInfo();

// Check client connection
final clientStatus = SocketService.getConnectionStatus();

// Force reconnection
await SocketService.reconnect();

// Manual sync
await SocketService.manualSync();
```

## Best Practices

### For Host Devices
1. **Keep the app running** while others are connected
2. **Monitor connection count** and performance
3. **Regularly backup** the database
4. **Use stable network connections**

### For Client Devices
1. **Ensure stable WiFi** connection
2. **Handle offline scenarios** gracefully
3. **Monitor sync status** in the UI
4. **Implement retry logic** for failed operations

### For Developers
1. **Test network failure scenarios**
2. **Monitor memory usage** during long sessions
3. **Implement proper error handling**
4. **Use meaningful device identifiers**

## Implementation Notes

The bidirectional synchronization system is designed to be:
- **Robust**: Handles network failures and recovers automatically
- **Efficient**: Minimizes data transfer and processing overhead
- **Secure**: Protects data with access controls and encryption
- **Scalable**: Supports multiple clients with minimal performance impact

This implementation ensures that your patient management application maintains data consistency across all devices in real-time, providing a seamless experience for healthcare professionals working collaboratively.
