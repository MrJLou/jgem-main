import 'dart:io';

/// Simple network diagnostic tool without Flutter dependencies
Future<void> main() async {
  print('=== Network IP Diagnostic Tool ===\n');

  // Get all network interfaces and their IP addresses
  try {
    final interfaces = await NetworkInterface.list();
    
    print('All Network Interfaces:');
    print('=' * 50);
    
    for (final interface in interfaces) {
      print('Interface: ${interface.name}');
      
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          final ip = address.address;
          final isLan = _isLanIp(ip);
          
          print('  IPv4: $ip ${isLan ? "(LAN)" : "(WAN/Other)"}');
          
          if (isLan && !ip.startsWith('127.')) {
            print('  *** RECOMMENDED SERVER IP: $ip ***');
          }
        }
      }
      print('');
    }
    
    // Test connectivity to common IP addresses in your range
    await _testConnectivity();
    
  } catch (e) {
    print('Error getting network interfaces: $e');
  }
}

bool _isLanIp(String ip) {
  return ip.startsWith('192.168.') || 
         ip.startsWith('10.') || 
         ip.startsWith('172.') ||
         ip.startsWith('127.');
}

Future<void> _testConnectivity() async {
  print('Testing Common IP Addresses in Your Network:');
  print('=' * 50);
  
  // Test the IPs mentioned in your issue
  final testIps = ['192.168.68.100', '192.168.68.115'];
  
  for (final ip in testIps) {
    print('Testing $ip...');
    
    try {
      // Test if we can reach this IP on port 8080
      final socket = await Socket.connect(ip, 8080, timeout: const Duration(seconds: 3));
      socket.destroy();
      print('  ✅ $ip:8080 - REACHABLE (Server running)');
    } catch (e) {
      print('  ❌ $ip:8080 - NOT REACHABLE ($e)');
    }
    
    try {
      // Test ping-like connectivity
      final result = await Process.run('ping', ['-n', '1', ip]);
      if (result.exitCode == 0) {
        print('  ✅ $ip - Device responds to ping');
      } else {
        print('  ❌ $ip - Device does not respond to ping');
      }
    } catch (pingError) {
      print('  ⚠️  $ip - Cannot test ping: $pingError');
    }
    print('');
  }
  
  print('Recommendations:');
  print('=' * 50);
  print('1. Use the "RECOMMENDED SERVER IP" shown above as your server IP');
  print('2. Make sure both devices are on the same WiFi network');
  print('3. Disable Windows Firewall temporarily for testing');
  print('4. Check if antivirus is blocking connections');
  print('5. Try restarting the LAN server with the correct IP');
}
