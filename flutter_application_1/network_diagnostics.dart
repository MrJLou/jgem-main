import 'dart:io';

import 'package:flutter/foundation.dart';

Future<void> main() async {
  const String serverIp = '192.168.68.115';
  const int port = 8080;

  if (kDebugMode) {
    print('=== Network Diagnostics ===');
    print('Target: $serverIp:$port');
    print('');
  }

  // Step 1: Ping test
  if (kDebugMode) {
    print('1. Testing basic network connectivity (ping)...');
  }
  try {
    final result = await Process.run('ping', ['-n', '4', serverIp]);
    if (result.exitCode == 0) {
      if (kDebugMode) {
        print('✓ Ping successful - Device is reachable on network');
        print('Ping output:');
        print(result.stdout);
      }
    } else {
      if (kDebugMode) {
        print('✗ Ping failed - Device may not be on network');
        print('Error: ${result.stderr}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Ping test failed: $e');
    }
  }

  if (kDebugMode) {
    print('\n${'=' * 50}\n');
  }

  // Step 2: Port connectivity test
  if (kDebugMode) {
    print('2. Testing port connectivity...');
  }
  try {
    final socket = await Socket.connect(serverIp, port,
        timeout: const Duration(seconds: 10));
    socket.destroy();
    if (kDebugMode) {
      print('✓ Port $port is open and accepting connections');
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Port $port is not accessible: $e');
      print('');
      print('Possible causes:');
      print('- LAN server is not running on target device');
      print('- Firewall is blocking port $port');
      print('- Application is not listening on port $port');
      print('- Wrong IP address');
    }
  }

  if (kDebugMode) {
    print('\n${'=' * 50}\n');
  }

  // Step 3: Network interface info
  if (kDebugMode) {
    print('3. Local network information...');
  }
  try {
    final interfaces = await NetworkInterface.list();
    for (final interface in interfaces) {
      if (interface.addresses.isNotEmpty) {
        if (kDebugMode) {
          print('Interface: ${interface.name}');
        }
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            if (kDebugMode) {
              print('  IPv4: ${addr.address}');
            }
            // Check if target IP is in same subnet
            if (addr.address.startsWith('192.168.68.')) {
              if (kDebugMode) {
                print('  ✓ Same subnet as target IP');
              }
            }
          }
        }
        if (kDebugMode) {
          print('');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Failed to get network info: $e');
    }
  }

  if (kDebugMode) {
    if (kDebugMode) {
      print('\n${'=' * 50}\n');
    }
  }

  // Step 4: Recommendations
  if (kDebugMode) {
    print('4. Troubleshooting recommendations:');
  }
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('If port connectivity failed:');
  }
  if (kDebugMode) {
    print('a) Ensure LAN server is running on $serverIp:');
  }
  if (kDebugMode) {
    print('   - Launch the app on that device');
  }
  if (kDebugMode) {
    print('   - Go to Settings → LAN Connection');
  }
  if (kDebugMode) {
    print('   - Enable "LAN Server Status"');
  }
  if (kDebugMode) {
    print('   - Verify it shows "Server running on port $port"');
  }
  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('b) Check Windows Firewall:');
    print('   - Add exception for port $port');
    print('   - Or temporarily disable firewall for testing');
    print('');
    print('c) Verify IP address:');
    print('   - Run "ipconfig" on target device');
    print('   - Ensure IP matches $serverIp');
    print('');
    print('d) Test from same device:');
    print('   - Try connecting to 127.0.0.1:$port first');
    print('   - This tests if server is running locally');
  }
}
