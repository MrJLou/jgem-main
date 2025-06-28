import 'dart:io';

/// Simple script to test IP detection logic outside of Flutter
Future<void> main() async {
  print('=== IP Detection Test Script ===');
  print('');
  
  try {
    final interfaces = await NetworkInterface.list();
    final validIps = <Map<String, String>>[];
    
    print('=== Available Network Interfaces ===');
    
    for (final interface in interfaces) {
      print('Interface: ${interface.name}');
      
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          final ip = address.address;
          print('  IPv4: $ip (isLoopback: ${address.isLoopback})');
          
          if (_isLanIp(ip) && !ip.startsWith('127.') && !address.isLoopback) {
            validIps.add({
              'ip': ip,
              'interface': interface.name,
              'priority': _getIpPriority(ip).toString(),
            });
            print('  ✓ Valid LAN IP: $ip (priority: ${_getIpPriority(ip)})');
          } else {
            print('  ✗ Skipped: $ip');
          }
        }
      }
      print('');
    }
    
    print('=== IP Selection Results ===');
    print('Found ${validIps.length} valid LAN IPs');
    
    if (validIps.isNotEmpty) {
      // Sort by priority (higher number = higher priority)
      validIps.sort((a, b) => int.parse(b['priority']!) - int.parse(a['priority']!));
      
      print('');
      print('All valid IPs (sorted by priority):');
      for (final ipInfo in validIps) {
        print('  ${ipInfo['ip']} on ${ipInfo['interface']} (priority: ${ipInfo['priority']})');
      }
      
      final selectedIp = validIps.first['ip']!;
      final selectedInterface = validIps.first['interface']!;
      
      print('');
      print('🎯 SELECTED IP FOR SERVER:');
      print('   IP Address: $selectedIp');
      print('   Interface: $selectedInterface');
      print('   Priority: ${validIps.first['priority']}');
      print('');
      print('📱 Clients should connect to:');
      print('   Server IP: $selectedIp');
      print('   Port: 8080');
      print('   WebSocket URL: ws://$selectedIp:8080/ws');
      print('   HTTP URL: http://$selectedIp:8080');
    } else {
      print('❌ No LAN IP found!');
      print('This means clients won\'t be able to connect from other devices.');
      print('The server will only be accessible on localhost.');
    }
    
  } catch (e) {
    print('❌ Error during IP detection: $e');
  }
  
  print('');
  print('=== Test Complete ===');
}

/// Check if IP is in LAN range (enhanced for your network)
bool _isLanIp(String ip) {
  if (ip == 'localhost') return true;
  if (ip == '127.0.0.1' || ip == '::1') return true;
  
  // Your specific network ranges
  if (ip.startsWith('192.168.68.')) return true; // Your current network
  
  // Standard private network ranges
  final lanRanges = [
    '192.168.',   // Class C private networks
    '10.',        // Class A private networks
    '172.16.', '172.17.', '172.18.', '172.19.',
    '172.20.', '172.21.', '172.22.', '172.23.',
    '172.24.', '172.25.', '172.26.', '172.27.',
    '172.28.', '172.29.', '172.30.', '172.31.',  // Class B private networks
  ];
  
  return lanRanges.any((range) => ip.startsWith(range));
}

/// Get IP priority for selection (higher = better)
int _getIpPriority(String ip) {
  // Prioritize based on common network patterns
  if (ip.startsWith('192.168.68.')) return 100; // Your specific network
  if (ip.startsWith('172.30.')) return 95;       // Corporate network pattern
  if (ip.startsWith('192.168.1.')) return 90;    // Common home network
  if (ip.startsWith('192.168.0.')) return 85;    // Common home network
  if (ip.startsWith('192.168.')) return 80;      // Other 192.168.x.x networks
  if (ip.startsWith('10.')) return 70;           // Class A private networks
  if (ip.startsWith('172.')) return 60;          // Other Class B private networks
  return 10; // Other IPs (lowest priority)
}
