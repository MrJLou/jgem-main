import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Simple test to verify if LAN server can be reached
Future<void> main() async {
  const String serverIp = '192.168.68.115';
  const int port = 8080;

  if (kDebugMode) {
    if (kDebugMode) {
      print('=== Quick Server Test ===');
    }
  }
  if (kDebugMode) {
    print('Checking if LAN server is reachable at $serverIp:$port');
  }
  if (kDebugMode) {
    print('');
  }

  // Test every 5 seconds until server is found or user stops
  int attempts = 0;
  const maxAttempts = 60; // 5 minutes

  while (attempts < maxAttempts) {
    attempts++;
    if (kDebugMode) {
      print('Attempt $attempts/$maxAttempts - Testing connection...');
    }

    try {
      final socket = await Socket.connect(serverIp, port,
          timeout: const Duration(seconds: 3));
      socket.destroy();

      if (kDebugMode) {
        print('✓ SUCCESS! LAN server is now accessible at $serverIp:$port');
      }
      if (kDebugMode) {
        print('');
      }
      if (kDebugMode) {
        print('You can now run your full connectivity test:');
      }
      if (kDebugMode) {
        print('  dart run test_lan_server.dart');
      }
      if (kDebugMode) {
        print('');
      }

      // Try a basic HTTP request
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);

        final request =
            await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
        final response = await request.close();

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          if (kDebugMode) {
            print('✓ HTTP Status check successful');
          }
          if (kDebugMode) {
            print('Response: $responseBody');
          }
        } else {
          if (kDebugMode) {
            print('⚠️  HTTP Status returned: ${response.statusCode}');
          }
        }

        client.close();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️  HTTP test failed (but socket connection worked): $e');
        }
      }

      return;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Connection failed: ${e.toString().split('\n')[0]}');
      }

      if (attempts == 1) {
        if (kDebugMode) {
          print('');
        }
        if (kDebugMode) {
          print('INSTRUCTIONS:');
        }
        if (kDebugMode) {
          print('1. Open your Flutter app');
        }
        if (kDebugMode) {
          print('2. Go to Settings → LAN Connection (or WiFi icon)');
        }
        if (kDebugMode) {
          print('3. Enable "LAN Server Status" toggle');
        }
        if (kDebugMode) {
          print('4. Verify port is set to 8080');
        }
        if (kDebugMode) {
          print('5. Wait for this test to detect the server...');
        }
        if (kDebugMode) {
          print('');
        }
      }
    }

    if (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  if (kDebugMode) {
    print('');
  }
  if (kDebugMode) {
    print('❌ Server not found after $maxAttempts attempts');
  }
  if (kDebugMode) {
    print('Please ensure:');
  }
  if (kDebugMode) {
    print('- Flutter app is running');
  }
  if (kDebugMode) {
    print('- LAN server is enabled in the app');
  }
  if (kDebugMode) {
    print('- Port 8080 is not blocked by firewall');
  }
}
