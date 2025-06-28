import 'dart:io';
import 'package:flutter/foundation.dart';

/// Simple diagnostic tool to check network configuration and IP addresses
Future<void> main() async {
  if (kDebugMode) {
    print('=== Network IP Diagnostic Tool ===\n');
  }

  // Get all network interfaces and their IP addresses
  try {
    final interfaces = await NetworkInterface.list();
    
    if (kDebugMode) {
      print('All Network Interfaces:');
      print('=' * 50);
    }
    
    for (final interface in interfaces) {
      if (kDebugMode) {
        print('Interface: ${interface.name}');
      }
      
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          final ip = address.address;
          final isLan = _isLanIp(ip);
          
          if (kDebugMode) {
            print('  IPv4: $ip ${isLan ? "(LAN)" : "(WAN/Other)"}');
          }
          
          if (isLan && !ip.startsWith('127.')) {
            if (kDebugMode) {
              print('  *** RECOMMENDED SERVER IP: $ip ***');
            }
          }
        }
      }
      if (kDebugMode) {
        print('');
      }
    }
    
    // Test connectivity to common IP addresses in your range
    await _testConnectivity();
    
  } catch (e) {
    if (kDebugMode) {
      print('Error getting network interfaces: $e');
    }
  }
}

bool _isLanIp(String ip) {
  return ip.startsWith('192.168.') || 
         ip.startsWith('10.') || 
         ip.startsWith('172.') ||
         ip.startsWith('127.');
}

Future<void> _testConnectivity() async {
  if (kDebugMode) {
    print('Testing Common IP Addresses in Your Network:');
    print('=' * 50);
  }
  
  // Test the IPs mentioned in your issue
  final testIps = ['192.168.68.100', '192.168.68.115'];
  
  for (final ip in testIps) {
    if (kDebugMode) {
      print('Testing $ip...');
    }
    
    try {
      // Test if we can reach this IP on port 8080
      final socket = await Socket.connect(ip, 8080, timeout: const Duration(seconds: 3));
      socket.destroy();
      if (kDebugMode) {
        print('  ✅ $ip:8080 - REACHABLE (Server running)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('  ❌ $ip:8080 - NOT REACHABLE ($e)');
      }
    }
    
    try {
      // Test ping-like connectivity
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
      socket.destroy();
      if (kDebugMode) {
        print('  ✅ $ip - Device is online');
      }
    } catch (e) {
      // Try a different approach - just basic network reachability
      try {
        final result = await Process.run('ping', ['-n', '1', ip]);
        if (result.exitCode == 0) {
          if (kDebugMode) {
            print('  ✅ $ip - Device responds to ping');
          }
        } else {
          if (kDebugMode) {
            print('  ❌ $ip - Device does not respond to ping');
          }
        }
      } catch (pingError) {
        if (kDebugMode) {
          print('  ⚠️  $ip - Cannot test ping: $pingError');
        }
      }
    }
    if (kDebugMode) {
      print('');
    }
  }
  
  if (kDebugMode) {
    print('Recommendations:');
    print('=' * 50);
    print('1. Use the "RECOMMENDED SERVER IP" shown above as your server IP');
    print('2. Make sure both devices are on the same WiFi network');
    print('3. Disable Windows Firewall temporarily for testing');
    print('4. Check if antivirus is blocking connections');
    print('5. Try restarting the LAN server with the correct IP');
  }
}
