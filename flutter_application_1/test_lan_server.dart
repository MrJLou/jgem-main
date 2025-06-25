import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

Future<void> main() async {
  const String serverIp = '192.168.68.115';
  const int port = 8080;
  const String accessCode =
      'w3wiaToG'; // Updated to match the server's current access code

  if (kDebugMode) {
    print('=== LAN Server Connectivity Test ===');
    print('Testing connection to $serverIp:$port');
    print('Access Code: $accessCode');
    print('');
  }

  // Test 1: Basic socket connectivity
  if (kDebugMode) {
    print('1. Testing basic socket connectivity...');
  }
  try {
    final socket = await Socket.connect(serverIp, port,
        timeout: const Duration(seconds: 5));
    socket.destroy();
    if (kDebugMode) {
      print('✓ Socket connection successful');
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Socket connection failed: $e');
    }
    return;
  }

  // Test 2: HTTP status endpoint (no auth required)
  if (kDebugMode) {
    print('\n2. Testing HTTP status endpoint (no auth)...');
  }
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    final request =
        await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
    final response = await request.close();

    final responseBody = await response.transform(utf8.decoder).join();

    if (kDebugMode) {
      print('✓ Status code: ${response.statusCode}');
      print('✓ Response body: $responseBody');
    }

    client.close();
  } catch (e) {
    if (kDebugMode) {
      print('✗ HTTP status request failed: $e');
    }
  }

  // Test 3: HTTP status endpoint with auth
  if (kDebugMode) {
    print('\n3. Testing HTTP status endpoint (with auth)...');
  }
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    final request =
        await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
    request.headers.add('Authorization', 'Bearer $accessCode');
    final response = await request.close();

    final responseBody = await response.transform(utf8.decoder).join();

    if (kDebugMode) {
      print('✓ Status code: ${response.statusCode}');
      print('✓ Response body: $responseBody');
    }

    client.close();
  } catch (e) {
    if (kDebugMode) {
      print('✗ HTTP status request with auth failed: $e');
    }
  }

  // Test 4: Test database endpoint (requires auth)
  if (kDebugMode) {
    print('\n4. Testing database endpoint (requires auth)...');
  }
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    final request = await client.getUrl(Uri.parse('http://$serverIp:$port/db'));
    request.headers.add('Authorization', 'Bearer $accessCode');
    final response = await request.close();

    if (kDebugMode) {
      print('✓ DB endpoint status code: ${response.statusCode}');
    }
    if (response.statusCode == 200) {
      if (kDebugMode) {
        print('✓ Database endpoint accessible');
      }
    } else {
      final responseBody = await response.transform(utf8.decoder).join();
      if (kDebugMode) {
        print('✗ DB endpoint error: $responseBody');
      }
    }

    client.close();
  } catch (e) {
    if (kDebugMode) {
      print('✗ Database endpoint request failed: $e');
    }
  }

  // Test 5: Check network interfaces
  if (kDebugMode) {
    print('\n5. Checking local network interfaces...');
  }
  try {
    final interfaces = await NetworkInterface.list();
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          if (kDebugMode) {
            print('Interface ${interface.name}: ${addr.address}');
          }
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Failed to list network interfaces: $e');
    }
  }

  if (kDebugMode) {
    print('\n=== Test Complete ===');
  }
}
