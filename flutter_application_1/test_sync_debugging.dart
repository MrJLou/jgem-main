// Test file to debug real-time sync issues
import 'package:flutter/foundation.dart';
import 'lib/services/database_helper.dart';
import 'lib/services/lan_sync_service.dart';
import 'lib/services/real_time_sync_service.dart';
import 'lib/services/lan_client_service.dart';

/// Test to debug why sync isn't working
Future<void> debugSyncIssues() async {
  debugPrint('=== DEBUG SYNC ISSUES ===');

  try {
    // Test 1: Check if database callback is set up
    debugPrint('Test 1: Database callback setup');
    final dbHelper = DatabaseHelper();

    bool callbackTriggered = false;
    DatabaseHelper.setDatabaseChangeCallback(
        (table, operation, recordId, data) async {
      debugPrint('✓ Database callback triggered: $table $operation $recordId');
      callbackTriggered = true;
    });

    // Simulate a database change to test callback
    await dbHelper
        .logChange('test_table', 'test_id', 'insert', data: {'test': 'data'});

    await Future.delayed(const Duration(milliseconds: 100));
    if (callbackTriggered) {
      debugPrint('✓ Database callback is working');
    } else {
      debugPrint('✗ Database callback NOT working');
    }

    // Test 2: Check LAN sync service initialization
    debugPrint('\nTest 2: LAN Sync Service');
    await LanSyncService.initialize(dbHelper);

    final connectionInfo = await LanSyncService.getConnectionInfo();
    debugPrint('Connection info: $connectionInfo');

    final isServerEnabled = connectionInfo['serverEnabled'] ?? false;
    debugPrint('Server enabled: $isServerEnabled');

    // Test 3: Check if server is running
    debugPrint('\nTest 3: Server status');
    if (isServerEnabled) {
      final ipAddresses = connectionInfo['ipAddresses'] as List?;
      final port = connectionInfo['port'] ?? 8080;

      if (ipAddresses != null && ipAddresses.isNotEmpty) {
        debugPrint('Server IPs: $ipAddresses');
        debugPrint('Server port: $port');

        // Test connection to our own server
        final testIp = ipAddresses.first;
        final canConnect = await LanClientService.testConnection(testIp, port);
        debugPrint('Can connect to own server: $canConnect');
      }
    } else {
      debugPrint('Server is not enabled - this is the issue!');
      debugPrint('Please start the LAN server to enable sync');
    }

    // Test 4: Check real-time sync service
    debugPrint('\nTest 4: Real-time sync service');
    await RealTimeSyncService.initialize();

    final isRealTimeConnected = RealTimeSyncService.isConnected;
    debugPrint('Real-time sync connected: $isRealTimeConnected');

    if (!isRealTimeConnected) {
      debugPrint('Real-time sync is not connected - this could be the issue!');
    }

    // Test 5: Simulate adding a patient to see if notifications work
    debugPrint('\nTest 5: Test patient addition simulation');

    // This should trigger the database callback
    await dbHelper.logChange(
        DatabaseHelper.tablePatients, 'test_patient_123', 'insert',
        data: {
          'id': 'test_patient_123',
          'full_name': 'Test Patient',
          'age': 30,
        });

    debugPrint(
        'Patient addition logged - check if callback was triggered above');
  } catch (e) {
    debugPrint('Error during sync debugging: $e');
  }
}

void main() async {
  await debugSyncIssues();
}
