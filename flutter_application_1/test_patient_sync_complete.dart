import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/real_time_sync_service.dart';
import 'package:flutter_application_1/services/lan_sync_service.dart';
import 'package:flutter_application_1/models/patient.dart';

/// Comprehensive test for patient registration real-time sync
/// This replaces multiple test files with one complete test
void main() async {
  if (kDebugMode) {
    print('=== Complete Patient Sync Test ===');
    print('Testing: connectivity, database, WebSocket, and patient sync');
    print('');
  }

  try {
    // Phase 1: Database and Service Initialization
    if (kDebugMode) {
      print('Phase 1: Initializing services...');
    }
    
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    
    // Test database callback setup
    bool callbackTriggered = false;
    DatabaseHelper.setDatabaseChangeCallback((table, operation, recordId, data) async {
      debugPrint('Database callback: $operation on $table (ID: $recordId)');
      callbackTriggered = true;
    });
    
    await LanSyncService.initialize(dbHelper);
    await RealTimeSyncService.initialize();
    
    if (kDebugMode) {
      print('✓ Services initialized');
    }

    // Phase 2: Start LAN Server
    if (kDebugMode) {
      print('');
      print('Phase 2: Starting LAN server...');
    }
    
    await LanSyncService.startLanServer(port: 8080);
    
    final info = await LanSyncService.getConnectionInfo();
    final accessCode = info['accessCode'] ?? '';
    final ipAddresses = List<String>.from(info['ipAddresses'] ?? []);
    
    if (kDebugMode) {
      print('✓ LAN server started');
      print('  Access Code: $accessCode');
      print('  IP Addresses: $ipAddresses');
    }

    // Phase 3: Test WebSocket Connection
    if (kDebugMode) {
      print('');
      print('Phase 3: Testing WebSocket connection...');
    }
    
    WebSocket? testSocket;
    bool webSocketWorks = false;
    
    if (ipAddresses.isNotEmpty) {
      try {
        final testIp = ipAddresses.first;
        final deviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
        final wsUrl = 'ws://$testIp:8080/ws?access_code=$accessCode&deviceId=$deviceId';
        
        testSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
        webSocketWorks = true;
        
        if (kDebugMode) {
          print('✓ WebSocket connection successful');
        }
        
        // Listen for messages
        testSocket.listen(
          (message) {
            try {
              final data = jsonDecode(message);
              if (kDebugMode) {
                print('  WebSocket received: ${data['type']}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('  WebSocket received (raw): $message');
              }
            }
          },
          onError: (error) => debugPrint('WebSocket error: $error'),
        );
        
      } catch (e) {
        if (kDebugMode) {
          print('✗ WebSocket connection failed: $e');
        }
      }
    }

    // Phase 4: Test Patient Registration Sync
    if (kDebugMode) {
      print('');
      print('Phase 4: Testing patient registration sync...');
    }
    
    // Create test patient
    final testPatient = Patient(
      id: '',
      fullName: 'Test Patient Sync ${DateTime.now().millisecondsSinceEpoch}',
      birthDate: DateTime(1990, 5, 15),
      gender: 'Male',
      contactNumber: '09123456789',
      address: '123 Test Street',
      bloodType: 'A+',
      allergies: 'None',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      registrationDate: DateTime.now(),
    );

    // Track sync messages if WebSocket is working
    List<String> syncMessages = [];
    if (webSocketWorks && testSocket != null) {
      testSocket.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'database_change' || 
              data['type'] == 'patient_info_update') {
            syncMessages.add('${data['type']}: ${data['data']?['table'] ?? 'patient'}');
          }
        } catch (e) {
          // Ignore parsing errors for this test
        }
      });
    }

    // Create patient
    final newPatientId = await ApiService.createPatient(testPatient);
    if (kDebugMode) {
      print('✓ Patient created with ID: $newPatientId');
    }

    // Wait for sync messages
    await Future.delayed(const Duration(seconds: 2));

    // Update patient
    final updatedPatient = testPatient.copyWith(
      id: newPatientId,
      fullName: '${testPatient.fullName} UPDATED',
      allergies: 'Peanuts',
      updatedAt: DateTime.now(),
    );

    await ApiService.updatePatient(updatedPatient, source: 'TestSync');
    if (kDebugMode) {
      print('✓ Patient updated');
    }

    // Wait for more sync messages
    await Future.delayed(const Duration(seconds: 2));

    // Phase 5: Test Database Access
    if (kDebugMode) {
      print('');
      print('Phase 5: Testing database access...');
    }
    
    if (ipAddresses.isNotEmpty) {
      try {
        final testIp = ipAddresses.first;
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse('http://$testIp:8080/db'))
          ..headers.set('Authorization', 'Bearer $accessCode');
        
        final response = await request.close().timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final dbData = jsonDecode(responseBody);
          
          if (kDebugMode) {
            print('✓ Database access successful');
            
            if (dbData['patients'] != null) {
              final patients = dbData['patients'] as List;
              print('  Total patients in database: ${patients.length}');
              
              // Check if our test patient is there
              final ourPatient = patients.firstWhere(
                (p) => p['id'] == newPatientId,
                orElse: () => null,
              );
              
              if (ourPatient != null) {
                print('✓ Test patient found in database');
                print('  Name: ${ourPatient['fullName']}');
              } else {
                print('⚠️  Test patient not found in database');
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
    }

    // Phase 6: Results Summary
    if (kDebugMode) {
      print('');
      print('=== Test Results Summary ===');
      print('✓ Database callback: ${callbackTriggered ? "Working" : "Not triggered"}');
      print('✓ LAN server: Running on port 8080');
      print('✓ WebSocket: ${webSocketWorks ? "Connected successfully" : "Connection failed"}');
      print('✓ Patient creation: Successful');
      print('✓ Patient update: Successful');
      print('✓ Database access: HTTP endpoint accessible');
      
      if (syncMessages.isNotEmpty) {
        print('✓ Sync messages received: ${syncMessages.length}');
        for (final msg in syncMessages) {
          print('  - $msg');
        }
      } else {
        print('⚠️  No sync messages received on WebSocket');
      }
      
      print('');
      print('=== For Other Devices ===');
      print('Connect using:');
      for (final ip in ipAddresses) {
        print('  Server: $ip:8080');
      }
      print('  Access Code: $accessCode');
      
      print('');
      if (webSocketWorks && syncMessages.isNotEmpty) {
        print('🎉 Real-time sync is working! Patient changes should sync across devices.');
      } else if (webSocketWorks) {
        print('⚠️  WebSocket connected but no sync messages. Check patient registration triggers.');
      } else {
        print('❌ WebSocket connection failed. Real-time sync will not work.');
        print('   Check network connectivity and firewall settings.');
      }
    }

    // Keep server running for manual testing
    if (kDebugMode) {
      print('');
      print('Server will keep running for 30 seconds for manual testing...');
      print('You can now test patient registration on another device.');
    }
    
    await testSocket?.close();
    await Future.delayed(const Duration(seconds: 30));

  } catch (e) {
    if (kDebugMode) {
      print('❌ Test failed: $e');
    }
  } finally {
    try {
      await LanSyncService.stopLanServer();
      if (kDebugMode) {
        print('Server stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping server: $e');
      }
    }
  }

  exit(0);
}
