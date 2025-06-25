import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/lan_sync_service.dart';
import 'package:flutter_application_1/services/database_helper.dart';

/// Quick utility to start LAN server for testing
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print('=== LAN Server Startup Utility ===');
    print('This utility will start the LAN server for testing purposes.');
    print('');
  }

  try {
    // Initialize database helper
    if (kDebugMode) {
      print('1. Initializing database...');
    }
    final dbHelper = DatabaseHelper();
    await dbHelper.database; // Initialize database
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

    // Get connection info
    final info = await LanSyncService.getConnectionInfo();
    final accessCode = info['accessCode'] ?? '';
    final ipAddresses = List<String>.from(info['ipAddresses'] ?? []);

    if (kDebugMode) {
      print('');
      print('=== SERVER RUNNING ===');
      print('Access Code: $accessCode');
      print('Server URLs:');
      for (final ip in ipAddresses) {
        print('  http://$ip:8080');
      }
      print('');
      print('You can now run your connectivity test from another terminal:');
      print('  dart run test_lan_server.dart');
      print('');
      print('Press Ctrl+C to stop the server...');
    }

    // Keep the server running
    while (true) {
      await Future.delayed(const Duration(seconds: 5));

      // Test local connectivity
      try {
        final socket = await Socket.connect('127.0.0.1', 8080,
            timeout: const Duration(seconds: 2));
        socket.destroy();
        // Server is running fine
      } catch (e) {
        if (kDebugMode) {
          print('⚠️  Server connection test failed: $e');
        }
        break;
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('✗ Error starting LAN server: $e');
      print('');
      print('Troubleshooting:');
      print('- Make sure no other service is using port 8080');
      print('- Check if the app has necessary permissions');
      print('- Try running with administrator privileges');
    }
    exit(1);
  }
}
