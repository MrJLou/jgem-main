import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shelf_lan_server.dart';

/// Enhanced real-time sync service that works with Shelf LAN server
class EnhancedRealTimeSyncService {
  static WebSocketChannel? _wsChannel;
  static Timer? _reconnectTimer;
  static Timer? _heartbeatTimer;
  static bool _isConnected = false;
  static String? _serverIp;
  static int? _serverPort;
  static String? _accessCode;
  static StreamSubscription? _wsSubscription;
  static StreamSubscription? _serverUpdatesSubscription;

  // Stream controllers for real-time events
  static final StreamController<Map<String, dynamic>> _patientQueueUpdates =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _patientInfoUpdates =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _databaseUpdates =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<String> _connectionStatus =
      StreamController<String>.broadcast();

  // Connection retry settings
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const int _maxReconnectAttempts = 10;
  static int _reconnectAttempts = 0;

  // Getters for streams
  static Stream<Map<String, dynamic>> get patientQueueUpdates =>
      _patientQueueUpdates.stream;
  static Stream<Map<String, dynamic>> get patientInfoUpdates =>
      _patientInfoUpdates.stream;
  static Stream<Map<String, dynamic>> get databaseUpdates =>
      _databaseUpdates.stream;
  static Stream<String> get connectionStatus => _connectionStatus.stream;

  // Connection status getter
  static bool get isConnected => _isConnected;
  static String? get serverInfo => _serverIp != null && _serverPort != null 
      ? '$_serverIp:$_serverPort' : null;

  /// Initialize the enhanced real-time sync service
  static Future<void> initialize() async {
    try {
      await _loadConnectionSettings();
      
      // Listen to server updates when running as server
      _listenToServerUpdates();
      
      debugPrint('EnhancedRealTimeSyncService initialized');
    } catch (e) {
      debugPrint('Failed to initialize EnhancedRealTimeSyncService: $e');
    }
  }

  /// Load saved connection settings
  static Future<void> _loadConnectionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverIp = prefs.getString('lan_server_ip');
      _serverPort = prefs.getInt('lan_server_port') ?? 8080;
      _accessCode = prefs.getString('lan_access_code');
    } catch (e) {
      debugPrint('Error loading connection settings: $e');
    }
  }

  /// Save connection settings
  static Future<void> _saveConnectionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_serverIp != null) await prefs.setString('lan_server_ip', _serverIp!);
      if (_serverPort != null) await prefs.setInt('lan_server_port', _serverPort!);
      if (_accessCode != null) await prefs.setString('lan_access_code', _accessCode!);
    } catch (e) {
      debugPrint('Error saving connection settings: $e');
    }
  }

  /// Connect to WebSocket server for real-time updates
  static Future<bool> connectToServer(
    String serverIp,
    int serverPort,
    String accessCode, {
    bool autoReconnect = true,
  }) async {
    _serverIp = serverIp;
    _serverPort = serverPort;
    _accessCode = accessCode;

    await _saveConnectionSettings();

    return await _attemptConnection(autoReconnect: autoReconnect);
  }

  /// Attempt to establish WebSocket connection
  static Future<bool> _attemptConnection({bool autoReconnect = true}) async {
    if (_serverIp == null || _serverPort == null || _accessCode == null) {
      _connectionStatus.add('Missing connection parameters');
      return false;
    }

    try {
      _connectionStatus.add('Connecting...');
      
      // Close existing connection
      await _closeConnection();

      // Create WebSocket connection
      final uri = Uri.parse('ws://$_serverIp:$_serverPort/ws?access_code=$_accessCode');
      _wsChannel = IOWebSocketChannel.connect(uri);

      // Set up message handling
      _wsSubscription = _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onDone: () {
          debugPrint('WebSocket connection closed');
          _handleConnectionLost(autoReconnect);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleConnectionLost(autoReconnect);
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStatus.add('Connected');
      
      // Start heartbeat
      _startHeartbeat();

      // Send initial ping
      _sendMessage({
        'type': 'ping',
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('Connected to WebSocket server at $_serverIp:$_serverPort');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to WebSocket server: $e');
      _connectionStatus.add('Connection failed: $e');
      _handleConnectionLost(autoReconnect);
      return false;
    }
  }

  /// Handle WebSocket connection lost
  static void _handleConnectionLost(bool autoReconnect) {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    
    if (autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      _connectionStatus.add('Reconnecting... (attempt $_reconnectAttempts)');
      
      _reconnectTimer = Timer(_reconnectDelay, () {
        _attemptConnection(autoReconnect: true);
      });
    } else {
      _connectionStatus.add('Disconnected');
    }
  }

  /// Start heartbeat to keep connection alive
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        _sendMessage({
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Send message to server
  static void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('Error sending WebSocket message: $e');
        _handleConnectionLost(true);
      }
    }
  }

  /// Handle incoming WebSocket messages
  static void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'pong':
          // Heartbeat response
          break;
        case 'database_change':
          _handleDatabaseChangeFromServer(data);
          break;
        case 'patient_queue_update':
          _handlePatientQueueUpdate(data);
          break;
        case 'patient_info_update':
          _handlePatientInfoUpdate(data);
          break;
        case 'sync_init':
          _handleSyncInit(data);
          break;
        case 'full_sync_required':
          _handleFullSyncRequired(data);
          break;
        default:
          debugPrint('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  /// Handle database change from server
  static void _handleDatabaseChangeFromServer(Map<String, dynamic> data) {
    final table = data['table'] as String?;
    final operation = data['operation'] as String?;
    final changeData = data['data'] as Map<String, dynamic>?;

    if (table != null && operation != null) {
      debugPrint('Received database change: $table.$operation');
      
      // Apply change to local database
      _applyDatabaseChange(table, operation, changeData ?? {});
      
      // Emit to streams
      _databaseUpdates.add(data);
    }
  }

  /// Apply database change locally
  static void _applyDatabaseChange(String table, String operation, Map<String, dynamic> data) {
    // This should be implemented based on your specific database operations
    // For now, we'll just log it
    debugPrint('Applying database change: $table.$operation with data: $data');
    
    // TODO: Implement actual database change application
    // Example:
    // switch (operation) {
    //   case 'INSERT':
    //     // Insert into local database
    //     break;
    //   case 'UPDATE':
    //     // Update local database
    //     break;
    //   case 'DELETE':
    //     // Delete from local database
    //     break;
    // }
  }

  /// Handle patient queue updates
  static void _handlePatientQueueUpdate(Map<String, dynamic> data) {
    debugPrint('Patient queue update received');
    _patientQueueUpdates.add(data);
  }

  /// Handle patient info updates
  static void _handlePatientInfoUpdate(Map<String, dynamic> data) {
    debugPrint('Patient info update received');
    _patientInfoUpdates.add(data);
  }

  /// Handle sync initialization
  static void _handleSyncInit(Map<String, dynamic> data) {
    debugPrint('Sync initialization received');
    // Request full sync if needed
    _sendMessage({
      'type': 'request_sync',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle full sync requirement
  static void _handleFullSyncRequired(Map<String, dynamic> data) {
    debugPrint('Full sync required');
    // TODO: Implement full database sync
  }

  /// Listen to server updates when running as server
  static void _listenToServerUpdates() {
    _serverUpdatesSubscription?.cancel();
    _serverUpdatesSubscription = ShelfLanServer.syncUpdates.listen((update) {
      // Broadcast server updates to all connected clients
      _databaseUpdates.add(update);
    });
  }

  /// Start server mode
  static Future<bool> startServer({int port = 8080}) async {
    try {
      final success = await ShelfLanServer.startServer(port: port);
      if (success) {
        _connectionStatus.add('Server running on port $port');
        debugPrint('Server started successfully');
      } else {
        _connectionStatus.add('Failed to start server');
      }
      return success;
    } catch (e) {
      debugPrint('Error starting server: $e');
      _connectionStatus.add('Server error: $e');
      return false;
    }
  }

  /// Stop server mode
  static Future<void> stopServer() async {
    try {
      await ShelfLanServer.stopServer();
      _connectionStatus.add('Server stopped');
      debugPrint('Server stopped');
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }

  /// Get server status
  static Map<String, dynamic> getServerStatus() {
    return {
      'isRunning': ShelfLanServer.isRunning,
      'accessCode': ShelfLanServer.accessCode,
      'allowedIpRanges': ShelfLanServer.allowedIpRanges,
    };
  }

  /// Disconnect from server
  static Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeConnection();
    _connectionStatus.add('Disconnected');
  }

  /// Close WebSocket connection
  static Future<void> _closeConnection() async {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    
    try {
      await _wsSubscription?.cancel();
      await _wsChannel?.sink.close();
    } catch (e) {
      debugPrint('Error closing WebSocket connection: $e');
    }
    
    _wsChannel = null;
    _wsSubscription = null;
  }

  /// Send database change to server
  static void broadcastDatabaseChange(String table, String operation, Map<String, dynamic> data) {
    if (_isConnected) {
      _sendMessage({
        'type': 'database_change',
        'table': table,
        'operation': operation,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Request full database sync from server
  static void requestFullSync() {
    if (_isConnected) {
      _sendMessage({
        'type': 'request_sync',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Cleanup resources
  static Future<void> dispose() async {
    await _closeConnection();
    _reconnectTimer?.cancel();
    
    await _patientQueueUpdates.close();
    await _patientInfoUpdates.close();
    await _databaseUpdates.close();
    await _connectionStatus.close();
    
    await _serverUpdatesSubscription?.cancel();
  }

  /// Get connection info for sharing
  static Map<String, dynamic>? getConnectionInfo() {
    if (_serverIp != null && _serverPort != null && _accessCode != null) {
      return {
        'serverIp': _serverIp,
        'port': _serverPort,
        'accessCode': _accessCode,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
    return null;
  }

  /// Import connection settings from JSON
  static Future<bool> importConnectionSettings(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      _serverIp = data['serverIp'] as String?;
      _serverPort = data['port'] as int?;
      _accessCode = data['accessCode'] as String?;
      
      if (_serverIp != null && _serverPort != null && _accessCode != null) {
        await _saveConnectionSettings();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error importing connection settings: $e');
      return false;
    }
  }

  /// Test connection to server
  static Future<bool> testConnection(String serverIp, int port) async {
    try {
      final socket = await Socket.connect(serverIp, port, timeout: const Duration(seconds: 5));
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
}
