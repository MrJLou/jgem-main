# Separated WebSocket and Shelf Server Architecture

## Overview

The codebase has been successfully refactored to separate concerns between HTTP database operations and real-time WebSocket communication. This provides better maintainability, scalability, and debugging capabilities.

## Architecture Components

### 1. Enhanced Shelf Server (`enhanced_shelf_lan_server.dart`)
**Purpose**: HTTP-based database operations and RESTful API endpoints
**Port**: 8080 (default)

**Responsibilities**:
- HTTP database sync endpoints (`/db/sync`, `/db/download`, `/db/changes/<since>`)
- Table-specific operations (`/tables/<table>`, `/tables/<table>/sync`)
- Server status and health checks (`/status`)
- Change tracking and logging
- Access code management
- LAN IP filtering and security

**Key Features**:
- ✅ RESTful API for database operations
- ✅ Proper change tracking with timestamp-based queries
- ✅ CORS and authentication middleware
- ✅ LAN-only access controls
- ✅ Integration with WebSocket server

### 2. WebSocket Server (`websocket_server.dart`)
**Purpose**: Real-time database synchronization and live updates
**Port**: 8081 (default, auto-started as HTTP port + 1)

**Responsibilities**:
- Real-time database change broadcasting
- WebSocket connection management
- Live sync between multiple devices
- Heartbeat and connection monitoring
- Full database sync on connection

**Key Features**:
- ✅ Pure WebSocket implementation
- ✅ Real-time change broadcasting
- ✅ Connection management and cleanup
- ✅ Heartbeat/ping-pong for connection health
- ✅ Error handling and reconnection support

### 3. WebSocket Client (`websocket_client.dart`)
**Purpose**: Client-side WebSocket connection for real-time sync
**Usage**: Connects to WebSocket server from other devices

**Responsibilities**:
- Connect to remote WebSocket servers
- Handle real-time database updates
- Automatic reconnection on connection loss
- Bi-directional sync (send and receive changes)

**Key Features**:
- ✅ Automatic reconnection logic
- ✅ Heartbeat monitoring
- ✅ Full sync request capability
- ✅ Change conflict prevention

## Data Flow

```
Database Change → DatabaseHelper → EnhancedShelfServer → WebSocketServer → Broadcast to Clients
                      ↓
                 Change Log (HTTP access)
```

### Change Propagation Process:

1. **Database Operation**: Any CRUD operation in DatabaseHelper
2. **Change Callback**: DatabaseHelper triggers change callback
3. **Shelf Server Processing**: EnhancedShelfServer logs change for HTTP access
4. **WebSocket Broadcasting**: WebSocketServer broadcasts change to all connected clients
5. **Client Updates**: Connected devices receive and apply changes in real-time

## Server Startup Process

1. **Database Initialization**: DatabaseHelper setup
2. **Shelf Server Init**: HTTP server initialization with access code
3. **WebSocket Server Init**: WebSocket server initialization with same access code
4. **Callback Setup**: Database change callback registration
5. **Server Start**: Both servers start on consecutive ports (8080, 8081)

## API Endpoints

### HTTP Endpoints (Port 8080)
- `GET /status` - Server status and health information
- `GET /db/download` - Download complete database
- `POST /db/sync` - Upload database changes
- `GET /db/changes/<since>` - Get changes since timestamp
- `GET /tables/<table>` - Get specific table data
- `POST /tables/<table>/sync` - Sync specific table

### WebSocket Endpoint (Port 8081)
- `ws://[ip]:8081/?access_code=[code]` - WebSocket connection for real-time sync

## Message Types (WebSocket)

### Client → Server
- `ping` - Heartbeat message
- `request_full_sync` - Request complete database sync
- `database_change` - Send database change to server
- `heartbeat` - Keep-alive message

### Server → Client
- `connected` - Connection confirmation
- `pong` - Heartbeat response
- `heartbeat_ack` - Heartbeat acknowledgment
- `full_sync` - Complete database data
- `database_change` - Real-time database change
- `error` - Error message

## Security Features

- ✅ Access code authentication for both HTTP and WebSocket
- ✅ LAN-only access (private IP filtering)
- ✅ CORS middleware for web clients
- ✅ Connection limits and cleanup
- ✅ Secure WebSocket upgrade process

## Performance Optimizations

- ✅ Change log with size limits (max 1000 entries)
- ✅ Dead connection cleanup
- ✅ Efficient JSON serialization
- ✅ Table-level last modification tracking
- ✅ Minimal data transfer for incremental sync

## Error Handling

- ✅ Graceful WebSocket connection failures
- ✅ Automatic reconnection with backoff
- ✅ Database operation error isolation
- ✅ Callback error containment
- ✅ Comprehensive logging

## Usage Examples

### Starting Servers
```dart
// Initialize database
final dbHelper = DatabaseHelper();
await dbHelper.database;

// Initialize and start servers
await EnhancedShelfServer.initialize(dbHelper);
final started = await EnhancedShelfServer.startServer();
// WebSocket server starts automatically
```

### Client Connection
```dart
// Initialize client
await WebSocketClient.initialize(dbHelper);

// Connect to server
final connected = await WebSocketClient.connectToWebSocketServer(
  'server_ip', 8081, 'access_code'
);

// Listen for updates
WebSocketClient.syncUpdates.listen((update) {
  print('Received: ${update['type']}');
});
```

### Manual Testing
Run the test script to verify the separation:
```bash
dart run test_separated_servers.dart
```

## Migration Notes

### From Previous Implementation
- ✅ WebSocket functionality moved from `enhanced_shelf_lan_server.dart` to `websocket_server.dart`
- ✅ Database change tracking improved with proper timestamp filtering
- ✅ Cleaner separation of HTTP and WebSocket concerns
- ✅ Better error handling and connection management
- ✅ Enhanced debugging and monitoring capabilities

### Benefits of Separation
1. **Maintainability**: Each server has a single responsibility
2. **Scalability**: Servers can be scaled independently
3. **Debugging**: Easier to isolate issues between HTTP and WebSocket
4. **Testing**: Independent testing of each component
5. **Performance**: Optimized for specific use cases

## Troubleshooting

### Common Issues
1. **Port Conflicts**: Ensure ports 8080 and 8081 are available
2. **Access Code Mismatch**: Verify same access code for both servers
3. **Network Issues**: Check LAN connectivity and firewall settings
4. **WebSocket Upgrade Failures**: Verify proper WebSocket client implementation

### Debug Commands
```dart
// Check server status
final status = EnhancedShelfServer.getServerStatus();
final wsStatus = WebSocketServer.getServerStatus();

// Check connection info
final connInfo = EnhancedShelfServer.getConnectionInfo();
```

This architecture provides a robust, scalable foundation for real-time database synchronization across multiple devices while maintaining clean separation of concerns.
