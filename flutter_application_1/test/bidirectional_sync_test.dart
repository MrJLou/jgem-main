import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/enhanced_shelf_lan_server.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'package:flutter_application_1/services/socket_service.dart';

/// Test suite for bidirectional database synchronization
void main() {
  group('Bidirectional Database Sync Tests', () {
    late DatabaseHelper dbHelper1; // Host
    late DatabaseHelper dbHelper2; // Client

    setUpAll(() async {
      // Initialize test databases
      dbHelper1 = DatabaseHelper();
      dbHelper2 = DatabaseHelper();
      
      await dbHelper1.database;
      await dbHelper2.database;
    });

    tearDownAll(() async {
      // Cleanup
      await EnhancedShelfServer.stopServer();
      await DatabaseSyncClient.disconnect();
    });

    test('Host can start server and accept connections', () async {
      // Initialize and start host server
      await EnhancedShelfServer.initialize(dbHelper1);
      final serverStarted = await EnhancedShelfServer.startServer(port: 8080);
      
      expect(serverStarted, isTrue);
      expect(EnhancedShelfServer.isRunning, isTrue);
      
      final connectionInfo = EnhancedShelfServer.getConnectionInfo();
      expect(connectionInfo['isRunning'], isTrue);
      expect(connectionInfo['port'], equals(8080));
      expect(connectionInfo['accessCode'], isNotNull);
    });

    test('Client can connect to host server', () async {
      // Get host connection details
      final connectionInfo = EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      // Initialize client
      await DatabaseSyncClient.initialize(dbHelper2);
      
      // Connect to host
      final connected = await DatabaseSyncClient.connectToServer(
        'localhost', 
        8080, 
        accessCode
      );
      
      expect(connected, isTrue);
      expect(DatabaseSyncClient.isConnected, isTrue);
    });

    test('Host changes are propagated to client', () async {
      final completer = Completer<Map<String, dynamic>>();
      
      // Listen for sync updates on client
      late StreamSubscription subscription;
      subscription = DatabaseSyncClient.syncUpdates.listen((update) {
        if (update['type'] == 'remote_change_applied' && 
            update['change']['table'] == 'patients') {
          subscription.cancel();
          completer.complete(update);
        }
      });
      
      // Create a test patient on host
      final testPatient = {
        'id': 'test_patient_001',
        'firstName': 'John',
        'lastName': 'Doe',
        'dateOfBirth': '1990-01-01',
        'gender': 'Male',
        'contactNumber': '123-456-7890',
        'address': '123 Test St',
        'emergencyContactName': 'Jane Doe',
        'emergencyContactNumber': '098-765-4321',
        'medicalHistory': 'None',
        'allergies': 'None',
        'currentMedications': 'None',
        'insuranceInformation': 'Test Insurance',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      // Insert patient on host (this should trigger sync)
      await dbHelper1.insertPatient(testPatient);
      
      // Wait for sync to complete
      final syncUpdate = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Sync timeout'),
      );
      
      expect(syncUpdate['type'], equals('remote_change_applied'));
      expect(syncUpdate['change']['table'], equals('patients'));
      expect(syncUpdate['change']['operation'], equals('insert'));
      
      // Verify patient exists in client database
      final clientPatient = await dbHelper2.getPatient('test_patient_001');
      expect(clientPatient, isNotNull);
      expect(clientPatient!['firstName'], equals('John'));
      expect(clientPatient['lastName'], equals('Doe'));
    });

    test('Client changes are propagated to host', () async {
      final completer = Completer<Map<String, dynamic>>();
      
      // Listen for changes on host (through WebSocket broadcasting)
      late StreamSubscription subscription;
      subscription = EnhancedShelfServer.syncUpdates.listen((update) {
        if (update['table'] == 'patients' && 
            update['operation'] == 'update' &&
            update['recordId'] == 'test_patient_001') {
          subscription.cancel();
          completer.complete(update);
        }
      });
      
      // Update patient on client
      final updatedPatient = {
        'id': 'test_patient_001',
        'firstName': 'John',
        'lastName': 'Smith', // Changed last name
        'dateOfBirth': '1990-01-01',
        'gender': 'Male',
        'contactNumber': '123-456-7890',
        'address': '456 Updated St', // Changed address
        'emergencyContactName': 'Jane Smith',
        'emergencyContactNumber': '098-765-4321',
        'medicalHistory': 'None',
        'allergies': 'None',
        'currentMedications': 'None',
        'insuranceInformation': 'Test Insurance',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      // Update patient on client (this should trigger sync)
      await dbHelper2.updatePatient(updatedPatient);
      
      // Wait for sync to complete
      final syncUpdate = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Sync timeout'),
      );
      
      expect(syncUpdate['table'], equals('patients'));
      expect(syncUpdate['operation'], equals('update'));
      expect(syncUpdate['recordId'], equals('test_patient_001'));
      
      // Verify patient is updated in host database
      final hostPatient = await dbHelper1.getPatient('test_patient_001');
      expect(hostPatient, isNotNull);
      expect(hostPatient!['lastName'], equals('Smith'));
      expect(hostPatient['address'], equals('456 Updated St'));
    });

    test('Socket Service provides unified interface', () async {
      // Test SocketService methods
      await SocketService.initialize(dbHelper1);
      
      final status = SocketService.getConnectionStatus();
      expect(status['isInitialized'], isTrue);
      
      final hostInfo = SocketService.getHostConnectionInfo();
      expect(hostInfo['isRunning'], isTrue);
      
      expect(SocketService.isHosting, isTrue);
      expect(SocketService.isConnected, isTrue);
    });

    test('Manual sync works correctly', () async {
      // Disconnect client
      await DatabaseSyncClient.disconnect();
      expect(DatabaseSyncClient.isConnected, isFalse);
      
      // Create another patient on host while client is disconnected
      final offlinePatient = {
        'id': 'test_patient_002',
        'firstName': 'Jane',
        'lastName': 'Wilson',
        'dateOfBirth': '1985-05-15',
        'gender': 'Female',
        'contactNumber': '555-123-4567',
        'address': '789 Offline St',
        'emergencyContactName': 'John Wilson',
        'emergencyContactNumber': '555-765-4321',
        'medicalHistory': 'Diabetes',
        'allergies': 'Peanuts',
        'currentMedications': 'Metformin',
        'insuranceInformation': 'Offline Insurance',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      await dbHelper1.insertPatient(offlinePatient);
      
      // Reconnect client
      final connectionInfo = EnhancedShelfServer.getConnectionInfo();
      final accessCode = connectionInfo['accessCode'] as String;
      
      final reconnected = await DatabaseSyncClient.connectToServer(
        'localhost', 
        8080, 
        accessCode
      );
      
      expect(reconnected, isTrue);
      
      // Perform manual sync
      final syncSuccess = await DatabaseSyncClient.manualSync();
      expect(syncSuccess, isTrue);
      
      // Verify offline patient is now in client database
      await Future.delayed(const Duration(seconds: 2)); // Allow time for sync
      final clientOfflinePatient = await dbHelper2.getPatient('test_patient_002');
      expect(clientOfflinePatient, isNotNull);
      expect(clientOfflinePatient!['firstName'], equals('Jane'));
      expect(clientOfflinePatient['lastName'], equals('Wilson'));
    });

    test('Connection recovery works after network interruption', () async {
      // Stop server to simulate network interruption
      await EnhancedShelfServer.stopServer();
      expect(EnhancedShelfServer.isRunning, isFalse);
      
      // Wait a moment for client to detect disconnection
      await Future.delayed(const Duration(seconds: 2));
      
      // Restart server
      final serverRestarted = await EnhancedShelfServer.startServer(port: 8080);
      expect(serverRestarted, isTrue);
      
      // Client should automatically reconnect
      await Future.delayed(const Duration(seconds: 10)); // Allow time for reconnection
      
      // Verify connection is restored
      expect(DatabaseSyncClient.isConnected, isTrue);
    });
  });
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}
