import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Quick connection test for LAN server - finds working server configuration
Future<void> main() async {
  if (kDebugMode) {
    print('=== LAN Server Connection Test ===');
    print('Finding working server configuration...');
    print('');
  }

  // Test configurations from your logs
  final testConfigs = [
    {'ip': '192.168.68.115', 'port': 8080, 'code': 'w3wiaToG'},
    {'ip': '192.168.68.115', 'port': 8080, 'code': 'xoJDEASe'},
    {'ip': '192.168.1.100', 'port': 8080, 'code': 'w3wiaToG'},
    {'ip': '127.0.0.1', 'port': 8080, 'code': 'w3wiaToG'},
  ];

  String? workingConfig;
  Map<String, dynamic>? serverStatus;

  for (final config in testConfigs) {
    final ip = config['ip']!;
    final port = config['port']! as int;
    final code = config['code']!;

    if (kDebugMode) {
      print('Testing: $ip:$port (code: $code)');
    }

    try {
      // Test basic connectivity
      final socket =
          await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
      socket.destroy();

      if (kDebugMode) {
        print('  ✓ Socket connection OK');
      }

      // Test HTTP status endpoint
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse('http://$ip:$port/status'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody);

        if (kDebugMode) {
          print('  ✓ Server status: ${data['status']}');
        }

        serverStatus = data;
      }

      // Test database access with authorization
      final dbRequest = await client.getUrl(Uri.parse('http://$ip:$port/db'))
        ..headers.set('Authorization', 'Bearer $code');
      final dbResponse = await dbRequest.close();

      if (dbResponse.statusCode == 200) {
        final dbBody = await dbResponse.transform(utf8.decoder).join();
        final dbData = jsonDecode(dbBody);

        if (kDebugMode) {
          print('  ✓ Database access OK');

          if (dbData['patients'] != null) {
            final patients = dbData['patients'] as List;
            print('  ✓ Found ${patients.length} patients');
          }
        }

        workingConfig = '$ip:$port';
        client.close();
        break; // Found working config
      } else {
        if (kDebugMode) {
          print('  ✗ Database access failed: ${dbResponse.statusCode}');
        }
      }

      client.close();
    } catch (e) {
      if (kDebugMode) {
        print('  ✗ Connection failed: $e');
      }
    }

    if (kDebugMode) {
      print('');
    }
  }

  // Test WebSocket if we found a working config
  if (workingConfig != null) {
    final parts = workingConfig.split(':');
    final ip = parts[0];
    final port = int.parse(parts[1]);
    final code = testConfigs
        .firstWhere((c) => c['ip'] == ip && c['port'] == port)['code']!;

    if (kDebugMode) {
      print('Testing WebSocket connection...');
    }

    try {
      final deviceId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final wsUrl = 'ws://$ip:$port/ws?access_code=$code&deviceId=$deviceId';

      final webSocket =
          await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        print('✓ WebSocket connected successfully');
      }

      // Send a test message
      final testMessage = {
        'type': 'request_sync',
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      webSocket.add(jsonEncode(testMessage));

      // Listen for a response
      bool receivedResponse = false;
      final subscription = webSocket.listen((message) {
        if (kDebugMode) {
          print('✓ WebSocket response: $message');
        }
        receivedResponse = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!receivedResponse) {
        if (kDebugMode) {
          print('⚠️  No WebSocket response (normal for some servers)');
        }
      }

      await subscription.cancel();
      await webSocket.close();
    } catch (e) {
      if (kDebugMode) {
        print('✗ WebSocket connection failed: $e');
      }
    }
  }

  if (kDebugMode) {
    print('');
    print('=== Results ===');

    if (workingConfig != null) {
      final parts = workingConfig.split(':');
      final ip = parts[0];
      final port = parts[1];
      final code = testConfigs.firstWhere(
          (c) => c['ip'] == ip && c['port'] == int.parse(port))['code']!;

      print('✅ Working Configuration Found:');
      print('   Server IP: $ip');
      print('   Port: $port');
      print('   Access Code: $code');

      if (serverStatus != null) {
        print('');
        print('Server Details:');
        serverStatus.forEach((key, value) {
          print('   $key: $value');
        });
      }

      print('');
      print('📱 To connect other devices:');
      print('1. Open the app on another device');
      print('2. Go to LAN Client Connection');
      print('3. Enter:');
      print('   - Server IP: $ip');
      print('   - Port: $port');
      print('   - Access Code: $code');
      print('4. Click Connect');
    } else {
      print('❌ No working server found');
      print('');
      print('🔧 Troubleshooting:');
      print('1. Start the LAN server on the main device');
      print('2. Check if devices are on same WiFi network');
      print('3. Verify firewall is not blocking port 8080');
      print('4. Check the access code in LAN Server settings');
    }
  }
}
