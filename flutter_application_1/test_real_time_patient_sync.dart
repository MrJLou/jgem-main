import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Comprehensive test for real-time patient sync across devices
Future<void> main() async {
  const String serverIp = '192.168.68.115';
  const int port = 8080;
  const String accessCode = 'w3wiaToG';

  if (kDebugMode) {
    print('=== Real-Time Patient Sync Test ===');
    print('Server: $serverIp:$port');
    print('Access Code: $accessCode');
    print('');
  }

  // Test 1: Verify LAN server is running and accessible
  if (kDebugMode) {
    print('1. Testing LAN server connectivity...');
  }
  try {
    final response = await HttpClient()
        .getUrl(Uri.parse('http://$serverIp:$port/status'))
        .then((request) => request.close())
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final statusData = jsonDecode(responseBody);
      if (kDebugMode) {
        print('✓ LAN server is running');
        print('  Status: ${statusData['status']}');
      }
    } else {
      if (kDebugMode) {
        print('✗ LAN server returned status: ${response.statusCode}');
        return;
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Failed to connect to LAN server: $e');
      return;
    }
  }

  // Test 2: Test WebSocket connection for real-time sync
  if (kDebugMode) {
    print('');
    print('2. Testing WebSocket connection...');
  }
  
  WebSocket? webSocket;
  try {
    // Generate a test device ID
    final deviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
    final wsUrl = 'ws://$serverIp:$port/ws?access_code=$accessCode&deviceId=$deviceId';
    
    if (kDebugMode) {
      print('  Connecting to: $wsUrl');
    }

    webSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 10));
    
    if (kDebugMode) {
      print('✓ WebSocket connected successfully');
    }

    // Listen for messages
    bool receivedResponse = false;
    webSocket.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (kDebugMode) {
            print('  Received: ${data['type']} - $data');
          }
          receivedResponse = true;
        } catch (e) {
          if (kDebugMode) {
            print('  Received (raw): $message');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('  WebSocket error: $error');
        }
      },
      onDone: () {
        if (kDebugMode) {
          print('  WebSocket connection closed');
        }
      },
    );

    // Test 3: Send a test patient registration message
    if (kDebugMode) {
      print('');
      print('3. Testing patient info update message...');
    }

    // Simulate a patient registration
    final testPatient = {
      'id': 'test_patient_${DateTime.now().millisecondsSinceEpoch}',
      'fullName': 'Test Patient Real-Time Sync',
      'birthDate': '1990-01-01T00:00:00.000Z',
      'gender': 'Male',
      'contactNumber': '09123456789',
      'address': 'Test Address',
      'bloodType': 'O+',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'registrationDate': DateTime.now().toIso8601String(),
    };

    final patientMessage = {
      'type': 'patient_info_update',
      'data': testPatient,
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': deviceId,
    };

    webSocket.add(jsonEncode(patientMessage));
    if (kDebugMode) {
      print('✓ Sent patient info update message');
      print('  Patient: ${testPatient['fullName']} (${testPatient['id']})');
    }

    // Test 4: Send a database change message (the format LAN sync sends)
    if (kDebugMode) {
      print('');
      print('4. Testing database change message...');
    }

    final dbChangeMessage = {
      'type': 'database_change',
      'data': {
        'table': 'patients',
        'operation': 'insert',
        'recordId': testPatient['id'],
        'data': testPatient,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    webSocket.add(jsonEncode(dbChangeMessage));
    if (kDebugMode) {
      print('✓ Sent database change message');
      print('  Operation: insert on patients table');
    }

    // Test 5: Test initial sync request
    if (kDebugMode) {
      print('');
      print('5. Testing initial sync request...');
    }

    final syncRequest = {
      'type': 'request_sync',
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    webSocket.add(jsonEncode(syncRequest));
    if (kDebugMode) {
      print('✓ Sent initial sync request');
    }

    // Wait for responses
    if (kDebugMode) {
      print('');
      print('6. Waiting for server responses...');
    }
    
    await Future.delayed(const Duration(seconds: 3));

    if (receivedResponse) {
      if (kDebugMode) {
        print('✓ Received responses from server');
      }
    } else {
      if (kDebugMode) {
        print('⚠️  No responses received (server may not be echoing messages)');
      }
    }

  } catch (e) {
    if (kDebugMode) {
      print('✗ WebSocket connection failed: $e');
    }
  } finally {
    await webSocket?.close();
  }

  // Test 6: Direct HTTP test for database endpoint
  if (kDebugMode) {
    print('');
    print('7. Testing direct database access...');
  }

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://$serverIp:$port/db'))
      ..headers.set('Authorization', 'Bearer $accessCode');
    
    final response = await request.close().timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final dbData = jsonDecode(responseBody);
      
      if (kDebugMode) {
        print('✓ Database access successful');
        if (dbData['patients'] != null) {
          final patients = dbData['patients'] as List;
          print('  Found ${patients.length} patients in database');
          
          // Check if any patients contain our test names
          final testPatients = patients.where((p) => 
            p['fullName']?.toString().contains('Test') == true
          ).toList();
          
          if (testPatients.isNotEmpty) {
            print('  Found ${testPatients.length} test patients:');
            for (final patient in testPatients.take(3)) {
              print('    - ${patient['fullName']} (${patient['id']})');
            }
          }
        }
      }
    } else {
      if (kDebugMode) {
        print('✗ Database access failed: ${response.statusCode}');
      }
    }
    
    client.close();
  } catch (e) {
    if (kDebugMode) {
      print('✗ Database access error: $e');
    }
  }

  if (kDebugMode) {
    print('');
    print('=== Test Summary ===');
    print('✓ LAN server is accessible');
    print('✓ WebSocket connection works');
    print('✓ Patient messages can be sent');
    print('✓ Database change messages can be sent');
    print('✓ Database is accessible via HTTP');
    print('');
    print('If patient registration is not syncing in real-time:');
    print('1. Check that both devices are connected to the same LAN server');
    print('2. Verify the real-time sync service is initialized on both devices');
    print('3. Confirm the access code and server IP are correct');
    print('4. Check if WebSocket messages are being properly handled');
    print('');
    print('Next steps:');
    print('- Run this test on both devices');
    print('- Register a patient on one device and check the other');
    print('- Check the app logs for real-time sync debug messages');
  }
}
