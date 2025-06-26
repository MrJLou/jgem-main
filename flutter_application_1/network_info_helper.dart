import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Quick network information utility for debugging LAN connections
class NetworkInfoHelper {
  /// Get all available network interfaces and their IP addresses
  static Future<List<Map<String, String>>> getAllNetworkInterfaces() async {
    final interfaces = <Map<String, String>>[];
    
    try {
      final networkInterfaces = await NetworkInterface.list();
      
      for (final interface in networkInterfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            interfaces.add({
              'interface': interface.name,
              'ip': addr.address,
              'isLoopback': addr.isLoopback.toString(),
              'type': 'IPv4',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting network interfaces: $e');
    }
    
    return interfaces;
  }
  
  /// Print network information to console
  static Future<void> printNetworkInfo() async {
    if (kDebugMode) {
      print('🌐 NETWORK INTERFACE INFORMATION');
    }
    if (kDebugMode) {
      print('================================');
    }
    
    final interfaces = await getAllNetworkInterfaces();
    
    if (interfaces.isEmpty) {
      if (kDebugMode) {
        print('❌ No network interfaces found');
      }
      return;
    }
    
    for (final interface in interfaces) {
      final ip = interface['ip']!;
      final name = interface['interface']!;
      final isLoopback = interface['isLoopback'] == 'true';
      
      String type = '';
      if (isLoopback) {
        type = '(Loopback)';
      } else if (ip.startsWith('192.168.')) {
        type = '(Private - WiFi/Ethernet)';
      } else if (ip.startsWith('10.')) {
        type = '(Private - Corporate)';
      } else if (ip.startsWith('172.')) {
        type = '(Private - Corporate)';
      } else {
        type = '(Public/Other)';
      }
      
      if (kDebugMode) {
        print('📍 $name: $ip $type');
      }
    }
    
    // Identify the likely primary IP
    final primaryIp = _getPrimaryIp(interfaces);
    if (primaryIp != null) {
      if (kDebugMode) {
        print('');
      }
      if (kDebugMode) {
        print('⭐ PRIMARY IP (Recommended): $primaryIp');
      }
      if (kDebugMode) {
        print('   Use this IP for LAN server hosting');
      }
    }
  }
  
  /// Get the primary IP address (most suitable for LAN hosting)
  static String? _getPrimaryIp(List<Map<String, String>> interfaces) {
    // Filter out loopback addresses
    final nonLoopback = interfaces.where((i) => i['isLoopback'] != 'true').toList();
    
    if (nonLoopback.isEmpty) return null;
    
    // Prioritize 172.x.x.x (your current network)
    for (final interface in nonLoopback) {
      final ip = interface['ip']!;
      if (ip.startsWith('172.30.')) {
        return ip;
      }
    }
    
    // Then prioritize other private networks
    for (final interface in nonLoopback) {
      final ip = interface['ip']!;
      if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
        return ip;
      }
    }
    
    // Return first non-loopback as fallback
    return nonLoopback.first['ip'];
  }
  
  /// Generate connection JSON for sharing
  static String generateConnectionJson(String serverIp, int port, String accessCode) {
    return jsonEncode({
      'serverIp': serverIp,
      'port': port,
      'accessCode': accessCode,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Generate complete setup instructions
  static String generateSetupInstructions(String serverIp, int port, String accessCode) {
    return '''
📱 LAN SERVER CONNECTION INSTRUCTIONS
====================================

Your LAN server is now available at:

🔗 Connection Details:
   Server IP: $serverIp
   Port: $port
   Access Code: $accessCode

📋 For Client Devices:
1. Open the Patient Management app
2. Go to "LAN Client Connection"
3. Enter the connection details above
4. Tap "Connect to Server"

🔄 For Existing Clients (IP Changed):
1. Use "Update IP" button with new IP: $serverIp
2. Or use "Import Settings" with this JSON:
   ${generateConnectionJson(serverIp, port, accessCode)}

💾 Database URL (for external tools):
   http://$serverIp:$port/db

🔒 Security Note:
   - Only devices on the same local network can connect
   - Access code is required for all connections
   - Server is not accessible from the internet

Generated on: ${DateTime.now().toString()}
''';
  }
}

/// Simple command-line utility function
void main() async {
  if (kDebugMode) {
    print('🚀 LAN Network Information Utility');
  }
  if (kDebugMode) {
    print('');
  }
  
  await NetworkInfoHelper.printNetworkInfo();
  
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('💡 To use in your Flutter app:');
  }
  if (kDebugMode) {
    print('   1. Start your LAN server');
  }
  if (kDebugMode) {
    print('   2. Use the primary IP address shown above');
  }
  if (kDebugMode) {
    print('   3. Share connection details with other devices');
  }
}
