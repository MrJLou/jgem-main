import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class RealTimeSyncService {
  static WebSocketChannel? _wsChannel;
  static Timer? _reconnectTimer;
  static bool _isConnected = false;
  static String? _serverIp;
  static int? _serverPort;
  static String? _accessCode;
  static final DatabaseHelper _dbHelper = DatabaseHelper();
  static StreamSubscription? _wsSubscription;

  // Stream controllers for real-time events
  static final StreamController<Map<String, dynamic>> _patientQueueUpdates =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _patientInfoUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  static Stream<Map<String, dynamic>> get patientQueueUpdates =>
      _patientQueueUpdates.stream;
  static Stream<Map<String, dynamic>> get patientInfoUpdates =>
      _patientInfoUpdates.stream;

  // Connection status getter
  static bool get isConnected => _isConnected;

  /// Initialize the real-time sync service
  static Future<void> initialize() async {
    await _loadConnectionSettings();
    if (_serverIp != null && _accessCode != null) {
      await connectToServer(_serverIp!, _serverPort ?? 8080, _accessCode!);
    }
  }

  /// Load saved connection settings
  static Future<void> _loadConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIp = prefs.getString('lan_server_ip');
    _serverPort = prefs.getInt('lan_server_port') ?? 8080;
    _accessCode = prefs.getString('lan_access_code');
  }

  /// Connect to WebSocket server for real-time updates
  static Future<bool> connectToServer(
      String serverIp, int port, String accessCode) async {
    try {
      _serverIp = serverIp;
      _serverPort = port;
      _accessCode = accessCode;

      // Save connection settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lan_server_ip', serverIp);
      await prefs.setInt('lan_server_port', port);
      await prefs.setString('lan_access_code', accessCode);

      // Close existing connection and cancel old subscription
      await disconnect();

      // Connect to WebSocket
      final wsUrl = 'ws://$serverIp:$port/ws?access_code=$accessCode';
      _wsChannel = IOWebSocketChannel.connect(wsUrl);

      // Listen for messages and store the subscription
      _wsSubscription = _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _isConnected = true;

      // Send initial sync request
      await _requestInitialSync();

      debugPrint('Real-time sync connected to $serverIp:$port');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to real-time sync: $e');
      _isConnected = false;
      _scheduleReconnect();
      return false;
    }
  }

  /// Handle incoming WebSocket messages
  static void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;

      switch (type) {
        case 'patient_queue_update':
          _handlePatientQueueUpdate(data);
          break;
        case 'patient_info_update':
          _handlePatientInfoUpdate(data);
          break;
        case 'sync_complete':
          debugPrint('Server sync complete');
          break;
        case 'ping':
          _sendPong();
          break;
        default:
          debugPrint('Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  /// Handle patient queue updates
  static void _handlePatientQueueUpdate(Map<String, dynamic> data) async {
    try {
      final queueData = data['data'] as Map<String, dynamic>;

      // Update local database
      await _dbHelper.updatePatientQueueFromSync(queueData);

      // Notify listeners
      _patientQueueUpdates.add({
        'type': 'queue_update',
        'data': queueData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('Patient queue updated: ${queueData['patientId']}');
    } catch (e) {
      debugPrint('Error handling patient queue update: $e');
    }
  }

  /// Handle patient info updates
  static void _handlePatientInfoUpdate(Map<String, dynamic> data) async {
    try {
      final patientData = data['data'] as Map<String, dynamic>;

      // Update local database
      await _dbHelper.updatePatientFromSync(patientData);

      // Notify listeners
      _patientInfoUpdates.add({
        'type': 'patient_update',
        'data': patientData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('Patient info updated: ${patientData['id']}');
    } catch (e) {
      debugPrint('Error handling patient info update: $e');
    }
  }

  /// Send patient queue update to other devices
  static Future<void> sendPatientQueueUpdate(
      Map<String, dynamic> queueData) async {
    if (!_isConnected || _wsChannel == null) return;

    try {
      final message = {
        'type': 'patient_queue_update',
        'data': queueData,
        'timestamp': DateTime.now().toIso8601String(),
        'device_id': await _getDeviceId(),
      };

      _wsChannel!.sink.add(jsonEncode(message));
      debugPrint('Sent patient queue update');
    } catch (e) {
      debugPrint('Error sending patient queue update: $e');
    }
  }

  /// Send patient info update to other devices
  static Future<void> sendPatientInfoUpdate(
      Map<String, dynamic> patientData) async {
    if (!_isConnected || _wsChannel == null) return;

    try {
      final message = {
        'type': 'patient_info_update',
        'data': patientData,
        'timestamp': DateTime.now().toIso8601String(),
        'device_id': await _getDeviceId(),
      };

      _wsChannel!.sink.add(jsonEncode(message));
      debugPrint('Sent patient info update');
    } catch (e) {
      debugPrint('Error sending patient info update: $e');
    }
  }

  /// Request initial sync when connecting
  static Future<void> _requestInitialSync() async {
    if (!_isConnected || _wsChannel == null) return;

    try {
      final message = {
        'type': 'request_sync',
        'device_id': await _getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      _wsChannel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error requesting initial sync: $e');
    }
  }

  /// Send pong response to server ping
  static void _sendPong() {
    if (!_isConnected || _wsChannel == null) return;

    try {
      _wsChannel!.sink.add(jsonEncode({'type': 'pong'}));
    } catch (e) {
      debugPrint('Error sending pong: $e');
    }
  }

  /// Schedule reconnection attempt
  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_serverIp != null && _accessCode != null) {
      _reconnectTimer = Timer(const Duration(seconds: 5), () async {
        debugPrint('Attempting to reconnect...');
        await connectToServer(_serverIp!, _serverPort ?? 8080, _accessCode!);
      });
    }
  }

  /// Get unique device ID
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  /// Disconnect from real-time sync
  static Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    if (_wsChannel != null) {
      await _wsChannel!.sink.close();
      _wsChannel = null;
    }

    _isConnected = false;
    debugPrint('Disconnected from real-time sync');
  }

  /// Dispose the service
  static Future<void> dispose() async {
    await disconnect();
    if (!_patientQueueUpdates.isClosed) {
      await _patientQueueUpdates.close();
    }
    if (!_patientInfoUpdates.isClosed) {
      await _patientInfoUpdates.close();
    }
  }
}
