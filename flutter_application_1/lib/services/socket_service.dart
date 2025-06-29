import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'database_sync_client.dart';
import 'database_helper.dart';
import 'enhanced_shelf_lan_server.dart';

class SocketService {
  static WebSocketChannel? _channel;
  static bool _isInitialized = false;

  /// Initialize the socket service with database helper
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    if (!_isInitialized) {
      await DatabaseSyncClient.initialize(dbHelper);
      _isInitialized = true;
    }
  }

  /// Connect to server using enhanced sync client
  static Future<bool> connect(String serverIp, int port, String accessCode) async {
    if (!_isInitialized) {
      throw Exception('SocketService not initialized. Call initialize() first.');
    }
    
    return await DatabaseSyncClient.connectToServer(serverIp, port, accessCode);
  }

  /// Connect with token (legacy method for backward compatibility)
  static void connectWithToken(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://your-api-endpoint.com/ws?token=$token'),
    );
  }

  /// Disconnect from server
  static Future<void> disconnect() async {
    await DatabaseSyncClient.disconnect();
    _channel?.sink.close();
    _channel = null;
  }

  /// Check if connected
  static bool get isConnected => DatabaseSyncClient.isConnected;

  /// Get sync updates stream
  static Stream get stream => DatabaseSyncClient.syncUpdates;

  /// Legacy stream for backward compatibility
  static Stream get legacyStream => _channel?.stream ?? const Stream.empty();

  /// Manual sync with server
  static Future<bool> manualSync() async {
    return await DatabaseSyncClient.manualSync();
  }

  /// Get connection status details
  static Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': isConnected,
      'isInitialized': _isInitialized,
      'clientType': 'DatabaseSyncClient',
      'lastSyncAttempt': DateTime.now().toIso8601String(),
    };
  }

  /// Force reconnection
  static Future<bool> reconnect() async {
    if (_isInitialized && DatabaseSyncClient.isConnected) {
      await DatabaseSyncClient.disconnect();
      // Note: Reconnection will be handled automatically by the client
      return true;
    }
    return false;
  }

  /// Start hosting a server (making this device a host)
  static Future<bool> startHosting({int port = 8080}) async {
    try {
      if (!_isInitialized) {
        throw Exception('SocketService not initialized. Call initialize() first.');
      }
      
      return await EnhancedShelfServer.startServer(port: port);
    } catch (e) {
      debugPrint('Error starting host server: $e');
      return false;
    }
  }

  /// Stop hosting server
  static Future<void> stopHosting() async {
    try {
      await EnhancedShelfServer.stopServer();
      debugPrint('Host server stopped successfully');
    } catch (e) {
      debugPrint('Error stopping host server: $e');
    }
  }

  /// Get hosting status
  static bool get isHosting => EnhancedShelfServer.isRunning;

  /// Get host connection info
  static Future<Map<String, dynamic>> getHostConnectionInfo() async {
    return await EnhancedShelfServer.getConnectionInfo();
  }
}