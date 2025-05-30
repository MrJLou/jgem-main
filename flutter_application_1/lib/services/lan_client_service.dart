import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LanClientService {
  static String? _serverUrl;
  static String? _accessCode;
  static bool _isConnected = false;

  // Connect to a LAN server
  static Future<bool> connectToServer(String serverIp, int port, String accessCode) async {
    try {
      _serverUrl = 'http://$serverIp:$port';
      _accessCode = accessCode;

      // Test connection by checking server status
      final response = await http.get(
        Uri.parse('$_serverUrl/status'),
        headers: {
          'Authorization': 'Bearer $accessCode',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isConnected = true;
        debugPrint('Connected to LAN server: ${data['status']}');
        return true;
      } else {
        debugPrint('Failed to connect: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  // Download database from LAN server
  static Future<String?> downloadDatabase() async {
    if (!_isConnected || _serverUrl == null || _accessCode == null) {
      debugPrint('Not connected to server');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/db'),
        headers: {
          'Authorization': 'Bearer $_accessCode',
        },
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        // Save the database file locally
        final appDir = await getApplicationDocumentsDirectory();
        final dbPath = join(appDir.path, 'patient_management_lan.db');
        final file = File(dbPath);
        
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('Database downloaded to: $dbPath');
        return dbPath;
      } else {
        debugPrint('Failed to download database: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  // Get server status
  static Future<Map<String, dynamic>?> getServerStatus() async {
    if (_serverUrl == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Status check error: $e');
    }
    return null;
  }

  // Send changes to server
  static Future<bool> uploadChanges(List<Map<String, dynamic>> changes) async {
    if (!_isConnected || _serverUrl == null || _accessCode == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/sync'),
        headers: {
          'Authorization': 'Bearer $_accessCode',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'changes': changes,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Upload changes error: $e');
      return false;
    }
  }

  // Get changes from server
  static Future<List<Map<String, dynamic>>?> downloadChanges() async {
    if (!_isConnected || _serverUrl == null || _accessCode == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/changes'),
        headers: {
          'Authorization': 'Bearer $_accessCode',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['changes'] ?? []);
      }
    } catch (e) {
      debugPrint('Download changes error: $e');
    }
    return null;
  }

  // Disconnect from server
  static void disconnect() {
    _serverUrl = null;
    _accessCode = null;
    _isConnected = false;
    debugPrint('Disconnected from LAN server');
  }

  // Check if connected
  static bool get isConnected => _isConnected;
  
  // Get server URL
  static String? get serverUrl => _serverUrl;
}
