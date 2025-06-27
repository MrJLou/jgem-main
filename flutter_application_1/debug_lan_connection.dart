import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Debug script to check current LAN server connection settings
Future<void> main() async {
  if (kDebugMode) {
    print('=== LAN Connection Debug ===');
    print('Checking current connection settings and server status...');
    print('');
  }

  // Test different IP addresses and access codes that might be in use
  final testConfigs = [
    {'ip': '192.168.68.115', 'port': 8080, 'code': 'w3wiaToG'},
    {'ip': '192.168.68.115', 'port': 8080, 'code': 'xoJDEASe'},
    {'ip': '192.168.1.100', 'port': 8080, 'code': 'w3wiaToG'},
    {'ip': '192.168.0.100', 'port': 8080, 'code': 'w3wiaToG'},
    {'ip': '127.0.0.1', 'port': 8080, 'code': 'w3wiaToG'},
  ];

  String? workingConfig;
  Map<String, dynamic>? serverInfo;

  for (final config in testConfigs) {
    final ip = config['ip'];
    final port = config['port'];
    final code = config['code'];
    
    if (kDebugMode) {
      print('Testing: $ip:$port with access code: $code');
    }

    try {
      // Test basic connectivity
      final socket = await Socket.connect(ip!, port! as int, 
          timeout: const Duration(seconds: 2));
      socket.destroy();
      
      if (kDebugMode) {
        print('  ✓ Socket connection successful');
      }

      // Test HTTP status endpoint
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      
      final request = await client.getUrl(
          Uri.parse('http://$ip:$port/status'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody);
        
        if (kDebugMode) {
          print('  ✓ HTTP status check successful');
          print('  Server status: ${data['status']}');
        }
        
        serverInfo = data;
      } else if (response.statusCode == 403) {
        if (kDebugMode) {
          print('  ⚠️  HTTP 403 - May need different access code');
        }
      } else {
        if (kDebugMode) {
          print('  ✗ HTTP status: ${response.statusCode}');
        }
      }

      // Test database endpoint with authorization
      try {
        final dbRequest = await client.getUrl(
            Uri.parse('http://$ip:$port/db'))
          ..headers.set('Authorization', 'Bearer $code');
        final dbResponse = await dbRequest.close();
        
        if (dbResponse.statusCode == 200) {
          final dbBody = await dbResponse.transform(utf8.decoder).join();
          final dbData = jsonDecode(dbBody);
          
          if (kDebugMode) {
            print('  ✓ Database access successful with this access code');
            print('  Database tables available: ${dbData.keys.toList()}');
            
            if (dbData['patients'] != null) {
              final patients = dbData['patients'] as List;
              print('  Found ${patients.length} patients in database');
            }
          }
          
          workingConfig = '$ip:$port (code: $code)';
          break; // Found working configuration
        } else if (dbResponse.statusCode == 401 || dbResponse.statusCode == 403) {
          if (kDebugMode) {
            print('  ✗ Database access denied: ${dbResponse.statusCode}');
            print('    (Server accessible but access code may be wrong)');
          }
        } else {
          if (kDebugMode) {
            print('  ✗ Database endpoint error: ${dbResponse.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('  ✗ Database access error: $e');
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

  if (kDebugMode) {
    print('=== Results ===');
    if (workingConfig != null) {
      print('✓ Working configuration found: $workingConfig');
      
      if (serverInfo != null) {
        print('');
        print('Server Information:');
        serverInfo.forEach((key, value) {
          if (kDebugMode) {
            print('  $key: $value');
          }
        });
      }
      
      print('');
      print('Use this configuration in your Flutter app:');
      final parts = workingConfig.split(' ');
      final ipPort = parts[0].split(':');
      final codeMatch = RegExp(r'code: (\w+)').firstMatch(workingConfig);
      final code = codeMatch?.group(1);
      
      print('  Server IP: ${ipPort[0]}');
      print('  Port: ${ipPort[1]}');
      print('  Access Code: $code');
      
      print('');
      print('For client devices to connect:');
      print('1. Go to LAN Client Connection screen');
      print('2. Enter Server IP: ${ipPort[0]}');
      print('3. Enter Port: ${ipPort[1]}');
      print('4. Enter Access Code: $code');
      print('5. Click Connect');
      
    } else {
      print('✗ No working LAN server configuration found');
      print('');
      print('Troubleshooting steps:');
      print('1. Ensure the LAN server is running on the main device');
      print('2. Check if both devices are on the same network');
      print('3. Verify the server IP address and access code');
      print('4. Check firewall settings');
      print('5. Try restarting the LAN server');
    }
    
    print('');
    print('Common issues:');
    print('- Access code changed: Check the LAN Server screen for current code');
    print('- IP address changed: Server device got a new IP from router');
    print('- Network isolation: Some WiFi networks block device-to-device communication');
    print('- Firewall: Antivirus or Windows Firewall blocking port 8080');
  }
}
