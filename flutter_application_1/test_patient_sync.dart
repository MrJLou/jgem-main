import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/real_time_sync_service.dart';
import 'package:flutter_application_1/services/lan_sync_service.dart';
import 'package:flutter_application_1/models/patient.dart';

/// Test script to verify patient registration real-time sync
void main() async {
  if (kDebugMode) {
    print('=== Patient Real-Time Sync Test ===');
    print('This will test patient registration sync between devices');
    print('');
  }

  try {
    // Initialize database helper
    if (kDebugMode) {
      print('1. Initializing database...');
    }
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    if (kDebugMode) {
      print('✓ Database initialized');
    }

    // Initialize LAN sync service
    if (kDebugMode) {
      print('2. Initializing LAN sync service...');
    }
    await LanSyncService.initialize(dbHelper);
    if (kDebugMode) {
      print('✓ LAN sync service initialized');
    }

    // Start the LAN server
    if (kDebugMode) {
      print('3. Starting LAN server on port 8080...');
    }
    await LanSyncService.startLanServer(port: 8080);
    if (kDebugMode) {
      print('✓ LAN server started successfully');
    }

    // Initialize real-time sync service
    if (kDebugMode) {
      print('4. Initializing real-time sync service...');
    }
    await RealTimeSyncService.initialize();
    if (kDebugMode) {
      print('✓ Real-time sync service initialized');
    }

    // Create a test patient
    if (kDebugMode) {
      print('5. Creating test patient...');
    }

    final testPatient = Patient(
      id: '',
      fullName: 'John Doe Test',
      birthDate: DateTime(1990, 5, 15),
      gender: 'Male',
      contactNumber: '123-456-7890',
      address: '123 Test Street',
      bloodType: 'A+',
      allergies: 'None',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      registrationDate: DateTime.now(),
    );

    final newPatientId = await ApiService.createPatient(testPatient);
    if (kDebugMode) {
      print('✓ Test patient created with ID: $newPatientId');
    }

    // Wait a bit to see if sync messages are sent
    await Future.delayed(const Duration(seconds: 2));

    // Update the patient
    if (kDebugMode) {
      print('6. Updating test patient...');
    }

    final updatedPatient = testPatient.copyWith(
      id: newPatientId,
      fullName: 'John Doe Updated',
      allergies: 'Peanuts',
      updatedAt: DateTime.now(),
    );

    await ApiService.updatePatient(updatedPatient, source: 'TestScript');
    if (kDebugMode) {
      print('✓ Test patient updated');
    }

    // Wait a bit more to see sync messages
    await Future.delayed(const Duration(seconds: 2));

    // Get connection info
    final info = await LanSyncService.getConnectionInfo();
    final accessCode = info['accessCode'] ?? '';
    final ipAddresses = List<String>.from(info['ipAddresses'] ?? []);

    if (kDebugMode) {
      print('');
      print('=== Connection Information ===');
      print('Access Code: $accessCode');
      print('Server running on port 8080');
      print('Available IP addresses:');
      for (final ip in ipAddresses) {
        print('  - $ip:8080');
      }
      print('');
      print('Test completed! Check the console output for sync messages.');
      print(
          'You should see "Sent patient info update" messages if sync is working.');
      print('');
      print('To test from another device:');
      print('1. Connect to the same WiFi network');
      print('2. Use any of the IP addresses above');
      print('3. Use access code: $accessCode');
    }

    // Keep the server running for a bit
    if (kDebugMode) {
      print('Keeping server running for 30 seconds...');
    }
    await Future.delayed(const Duration(seconds: 30));
  } catch (e) {
    if (kDebugMode) {
      print('❌ Test failed: $e');
    }
  } finally {
    // Clean up
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
