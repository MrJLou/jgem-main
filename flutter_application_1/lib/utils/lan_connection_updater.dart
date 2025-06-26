import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class to help update LAN client connections when server IP changes
class LanConnectionUpdater {
  /// Update the stored server IP address for LAN client connections
  static Future<bool> updateServerIp(String newServerIp, {int? port, String? accessCode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update server IP
      await prefs.setString('lan_server_ip', newServerIp);
      
      // Update port if provided
      if (port != null) {
        await prefs.setInt('lan_server_port', port);
      }
      
      // Update access code if provided
      if (accessCode != null) {
        await prefs.setString('lan_access_code', accessCode);
      }
      
      // Clear connection state to force reconnection
      await prefs.setBool('was_connected', false);
      
      if (kDebugMode) {
        print('✅ Updated LAN server connection settings:');
      }
      if (kDebugMode) {
        print('   Server IP: $newServerIp');
      }
      // ignore: curly_braces_in_flow_control_structures
      if (port != null) if (kDebugMode) {
        print('   Port: $port');
      }
      if (accessCode != null) if (kDebugMode) {
        print('   Access Code: $accessCode');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating server IP: $e');
      }
      return false;
    }
  }
  
  /// Import connection settings from JSON (useful for bulk updates)
  static Future<bool> importConnectionSettings(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      final serverIp = data['serverIp'] as String?;
      final port = data['port'] as int?;
      final accessCode = data['accessCode'] as String?;
      
      if (serverIp == null) {
        if (kDebugMode) {
          print('❌ Invalid JSON: missing serverIp');
        }
        return false;
      }
      
      return await updateServerIp(serverIp, port: port, accessCode: accessCode);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error importing connection settings: $e');
      }
      return false;
    }
  }
  
  /// Get current connection settings
  static Future<Map<String, dynamic>> getCurrentSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'serverIp': prefs.getString('lan_server_ip') ?? '',
        'port': prefs.getInt('lan_server_port') ?? 8080,
        'accessCode': prefs.getString('lan_access_code') ?? '',
        'wasConnected': prefs.getBool('was_connected') ?? false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting current settings: $e');
      }
      return {};
    }
  }
  
  /// Clear all connection settings
  static Future<bool> clearConnectionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('lan_server_ip');
      await prefs.remove('lan_server_port');
      await prefs.remove('lan_access_code');
      await prefs.setBool('was_connected', false);
      
      if (kDebugMode) {
        print('✅ Cleared all LAN connection settings');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing connection settings: $e');
      }
      return false;
    }
  }
  
  /// Generate connection update instructions
  static String generateUpdateInstructions(String newServerIp, int port, String accessCode) {
    final jsonData = jsonEncode({
      'serverIp': newServerIp,
      'port': port,
      'accessCode': accessCode,
    });
    
    return '''
📱 LAN CLIENT UPDATE INSTRUCTIONS
================================

Your server IP has changed to: $newServerIp

🔧 AUTOMATIC UPDATE (Recommended):
1. Copy this JSON data: $jsonData
2. In the app, go to Settings > Import Connection Settings
3. Paste the JSON data and tap Import

🔧 MANUAL UPDATE:
1. Open the app on each client device
2. Go to "LAN Client Connection"
3. Update the connection details:
   • Server IP: $newServerIp
   • Port: $port
   • Access Code: $accessCode
4. Tap "Connect to Server"

💡 Save these instructions and share with all team members who need to connect to your server.
''';
  }
}
