import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/database_helper.dart';
import 'lib/services/enhanced_shelf_lan_server.dart';

/// Diagnostic script to troubleshoot LAN connection issues
Future<void> main() async {
  print('=== LAN Connection Diagnostic Tool ===\n');
  
  try {
    // 1. Check current device network configuration
    print('1. Current Device Network Configuration:');
    final interfaces = await NetworkInterface.list();
    
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          final ip = address.address;
          print('   Interface: ${interface.name} => IP: $ip');
        }
      }
    }
    
    // 2. Check what the server thinks its IP is
    print('\n2. Server IP Detection:');
    await EnhancedShelfServer.initialize(DatabaseHelper());
    final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
    
    if (connectionInfo.containsKey('error')) {
      print('   Server not running: ${connectionInfo['error']}');
    } else {
      print('   Server IP: ${connectionInfo['serverIp']}');
      print('   Server Port: ${connectionInfo['port']}');
      print('   Access Code: ${connectionInfo['accessCode']}');
      print('   Server Running: ${EnhancedShelfServer.isRunning}');
    }
    
    // 3. Check stored sync settings
    print('\n3. Stored Sync Settings (SharedPreferences):');
    final prefs = await SharedPreferences.getInstance();
    final storedServerIp = prefs.getString('lan_server_ip');
    final storedServerPort = prefs.get('lan_server_port');
    final storedAccessCode = prefs.getString('lan_access_code');
    final syncEnabled = prefs.getBool('sync_enabled') ?? false;
    
    print('   Stored Server IP: $storedServerIp');
    print('   Stored Server Port: $storedServerPort');
    print('   Stored Access Code: $storedAccessCode');
    print('   Sync Enabled: $syncEnabled');
    
    // 4. Provide recommendations
    print('\n4. Recommendations:');
    
    // Get actual current IP
    String? currentIp;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          final ip = address.address;
          if (ip.startsWith('192.168.') && !ip.startsWith('127.')) {
            currentIp = ip;
            break;
          }
        }
      }
      if (currentIp != null) break;
    }
    
    if (currentIp != null) {
      print('   ✅ Your current IP: $currentIp');
      
      if (storedServerIp != null && storedServerIp != currentIp) {
        final currentNetwork = currentIp.split('.').take(3).join('.');
        final storedNetwork = storedServerIp.split('.').take(3).join('.');
        
        if (currentNetwork != storedNetwork) {
          print('   ⚠️  WARNING: Stored server IP ($storedServerIp) is on different network!');
          print('   ⚠️  Current network: $currentNetwork.x');
          print('   ⚠️  Stored network: $storedNetwork.x');
          print('   💡 SOLUTION: Clear sync settings and reconnect');
        }
      }
      
      if (connectionInfo['serverIp'] != null && connectionInfo['serverIp'] != currentIp) {
        print('   ℹ️  Server detected IP: ${connectionInfo['serverIp']}');
        print('   ℹ️  Your device IP: $currentIp');
        if (connectionInfo['serverIp'] != storedServerIp) {
          print('   💡 SOLUTION: Update client connection with correct server IP');
        }
      }
    } else {
      print('   ❌ Could not detect your current LAN IP');
    }
    
    // 5. Provide fix commands
    print('\n5. Quick Fixes:');
    print('   To clear stale sync settings:');
    print('   - Open your app');
    print('   - Go to Settings → LAN Connection');  
    print('   - Click "Clear Sync Settings" (if available)');
    print('   - Or manually disconnect and reconnect');
    
    print('\n   To fix server connection:');
    print('   - Make sure server is running on main device');
    print('   - Use the correct IP address shown above');
    print('   - Use port 8080');
    print('   - Get fresh access code from server device');
    
  } catch (e) {
    print('Error during diagnosis: $e');
  }
  
  print('\n=== Diagnostic Complete ===');
}
