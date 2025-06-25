import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Quick script to test if the LAN server allows your network after the fix
Future<void> main() async {
  const String serverIp = '192.168.68.115';
  const int port = 8080;
  const String accessCode = 'xoJDEASe';

  if (kDebugMode) {
    print('=== Testing LAN Server Access After Fix ===');
    print('Target: $serverIp:$port');
    print('Access Code: $accessCode');
    print('');
  }

  // Test every few seconds until server is restarted
  int attempts = 0;
  const maxAttempts = 20;

  while (attempts < maxAttempts) {
    attempts++;
    if (kDebugMode) {
      print('Attempt $attempts/$maxAttempts - Testing server response...');
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request =
          await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();

      if (kDebugMode) {
        print('Status Code: ${response.statusCode}');
        print('Response: $responseBody');
      }

      if (response.statusCode == 403 &&
          responseBody.contains('Non-LAN connection')) {
        if (kDebugMode) {
          print(
              '⚠️  Server still blocking connection - IP range not updated yet');
          print('   Please restart the LAN server in your Flutter app:');
          print('   1. Go to LAN Connection screen');
          print('   2. Turn OFF the LAN Server toggle');
          print('   3. Turn ON the LAN Server toggle');
          print('   4. This will apply the new IP range configuration');
        }
      } else if (response.statusCode == 403 &&
          !responseBody.contains('Non-LAN connection')) {
        if (kDebugMode) {
          print(
              '✓ IP access granted! Now getting 403 for missing/invalid access code');
          print('  This means the LAN IP filtering is working correctly');
        }
        break;
      } else if (response.statusCode == 200) {
        if (kDebugMode) {
          print(
              '✓ SUCCESS! Server is accessible without authentication required');
        }
        break;
      } else {
        if (kDebugMode) {
          print('? Unexpected response: ${response.statusCode}');
        }
      }

      client.close();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Connection failed: $e');
        print('  Server may not be running');
      }
    }

    if (attempts < maxAttempts) {
      if (kDebugMode) {
        print('  Waiting 3 seconds before next attempt...');
      }
      await Future.delayed(const Duration(seconds: 3));
      if (kDebugMode) {
        print('');
      }
    }
  }

  if (attempts >= maxAttempts) {
    if (kDebugMode) {
      print('');
      print('❌ Server access not resolved after $maxAttempts attempts');
      print('');
      print('Manual steps:');
      print('1. In your Flutter app, go to Settings → LAN Connection');
      print('2. Turn OFF the "LAN Server Status" toggle');
      print('3. Wait 2 seconds');
      print('4. Turn ON the "LAN Server Status" toggle');
      print('5. The server will restart with updated IP range configuration');
      print('6. Run this test again or your main connectivity test');
    }
  } else {
    if (kDebugMode) {
      print('');
      print('✅ LAN server access is now working!');
      print('You can now run your full connectivity test:');
      print('  dart run test_lan_server.dart');
    }
  }
}
