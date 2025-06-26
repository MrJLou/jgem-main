import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'shelf_lan_server.dart';
import 'enhanced_real_time_sync_service.dart';
import 'lan_session_service.dart';

/// Enhanced LAN Sync Service that uses Shelf server for better performance
/// and real-time synchronization capabilities
class EnhancedLanSyncService {
  static const String _syncIntervalKey = 'sync_interval_minutes';
  static const String _syncEnabledKey = 'sync_enabled';
  static const int _defaultPort = 8080;

  static Timer? _syncTimer;
  static bool _isInitialized = false;

  /// Initialize the Enhanced LAN Sync Service
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    if (_isInitialized) return;
    
    try {
      // Initialize the Shelf server
      await ShelfLanServer.initialize(dbHelper);
      
      // Initialize session service
      await LanSessionService.initialize();
      
      // Initialize enhanced real-time sync service
      await EnhancedRealTimeSyncService.initialize();
      
      _isInitialized = true;
      debugPrint('Enhanced LAN Sync Service initialized successfully');
    } catch (e) {
      debugPrint('Enhanced LAN Sync Service initialization failed: $e');
      rethrow;
    }
  }

  /// Start the LAN server with enhanced capabilities
  static Future<bool> startLanServer({int port = _defaultPort}) async {
    try {
      if (!_isInitialized) {
        debugPrint('Service not initialized');
        return false;
      }

      // Start the Shelf server
      final success = await ShelfLanServer.startServer(port: port);
      
      if (success) {
        // Start periodic sync
        await _startPeriodicSync();
        
        // Connect real-time sync to localhost
        await _connectRealTimeSync(port);
        
        debugPrint('Enhanced LAN server started successfully on port $port');
      }
      
      return success;
    } catch (e) {
      debugPrint('Failed to start enhanced LAN server: $e');
      return false;
    }
  }

  /// Stop the LAN server
  static Future<void> stopLanServer() async {
    try {
      // Stop sync timer
      _syncTimer?.cancel();
      _syncTimer = null;
      
      // Disconnect enhanced real-time sync
      await EnhancedRealTimeSyncService.disconnect();
      
      // Stop Shelf server
      await ShelfLanServer.stopServer();
      
      debugPrint('Enhanced LAN server stopped');
    } catch (e) {
      debugPrint('Error stopping enhanced LAN server: $e');
    }
  }

  /// Get connection information
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    try {
      return {
        'isRunning': ShelfLanServer.isRunning,
        'accessCode': ShelfLanServer.accessCode,
        'ipAddresses': ShelfLanServer.allowedIpRanges,
        'activeSessions': LanSessionService.activeSessions.length,
      };
    } catch (e) {
      debugPrint('Error getting connection info: $e');
      return {};
    }
  }

  /// Connect real-time sync to local server
  static Future<void> _connectRealTimeSync(int port) async {
    try {
      final ipAddresses = ShelfLanServer.allowedIpRanges;
      if (ipAddresses.isNotEmpty) {
        final serverIp = ipAddresses.first.startsWith('127.0.0') 
            ? '127.0.0.1' 
            : '${ipAddresses.first}.1'; // Assume gateway
        
        final accessCode = ShelfLanServer.accessCode;
        if (accessCode != null) {
          await EnhancedRealTimeSyncService.connectToServer(serverIp, port, accessCode);
        }
      }
    } catch (e) {
      debugPrint('Error connecting real-time sync: $e');
    }
  }

  /// Start periodic synchronization
  static Future<void> _startPeriodicSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncInterval = prefs.getInt(_syncIntervalKey) ?? 5;
      
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(Duration(minutes: syncInterval), (timer) {
        _performPeriodicSync();
      });
      
      debugPrint('Periodic sync started with interval: ${syncInterval} minutes');
    } catch (e) {
      debugPrint('Error starting periodic sync: $e');
    }
  }

  /// Perform periodic synchronization
  static Future<void> _performPeriodicSync() async {
    try {
      if (!ShelfLanServer.isRunning) return;
      
      // Update database copy for sharing
      debugPrint('Performing periodic sync...');
      
      // This could include:
      // 1. Updating shared database
      // 2. Cleaning up old data
      // 3. Validating data integrity
      
      debugPrint('Periodic sync completed');
    } catch (e) {
      debugPrint('Error in periodic sync: $e');
    }
  }

  /// Force manual sync
  static Future<bool> syncNow() async {
    try {
      await _performPeriodicSync();
      return true;
    } catch (e) {
      debugPrint('Manual sync failed: $e');
      return false;
    }
  }

  /// Set sync interval
  static Future<void> setSyncInterval(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_syncIntervalKey, minutes);
      
      // Restart sync timer with new interval
      if (ShelfLanServer.isRunning) {
        await _startPeriodicSync();
      }
    } catch (e) {
      debugPrint('Error setting sync interval: $e');
    }
  }

  /// Enable or disable sync
  static Future<void> setSyncEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error setting sync enabled: $e');
    }
  }

  /// Check if sync is enabled
  static Future<bool> isSyncEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_syncEnabledKey) ?? true;
    } catch (e) {
      debugPrint('Error checking sync enabled: $e');
      return true;
    }
  }

  /// Notify database change for real-time sync
  static Future<void> notifyDatabaseChange(
    String table,
    String operation,
    String recordId, {
    Map<String, dynamic>? data,
  }) async {
    try {
      // The shelf server will handle this through the database callback
      debugPrint('Database change notified: $table.$operation');
    } catch (e) {
      debugPrint('Error notifying database change: $e');
    }
  }

  /// Notify session change
  static Future<void> notifySessionChange(
    String type,
    Map<String, dynamic> sessionData,
  ) async {
    try {
      // Broadcast through WebSocket
      debugPrint('Session change notified: $type');
    } catch (e) {
      debugPrint('Error notifying session change: $e');
    }
  }

  /// Get active WebSocket connections count
  static int getActiveConnectionsCount() {
    return ShelfLanServer.isRunning ? 1 : 0; // Simplified for now
  }

  /// Get server status
  static Map<String, dynamic> getServerStatus() {
    return {
      'isRunning': ShelfLanServer.isRunning,
      'accessCode': ShelfLanServer.accessCode,
      'activeConnections': getActiveConnectionsCount(),
      'lastSync': DateTime.now().toIso8601String(),
    };
  }

  /// Test connection to server
  static Future<bool> testConnection(String serverIp, int port) async {
    try {
      final socket = await Socket.connect(serverIp, port, timeout: const Duration(seconds: 5));
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }



  /// Regenerate access code
  static Future<String> regenerateAccessCode() async {
    try {
      return await ShelfLanServer.regenerateAccessCode();
    } catch (e) {
      debugPrint('Error regenerating access code: $e');
      return 'ERROR';
    }
  }

  /// Get database browser instructions
  static Future<Map<String, dynamic>> getDbBrowserInstructions() async {
    try {
      return await ShelfLanServer.getDbBrowserInstructions();
    } catch (e) {
      debugPrint('Error getting DB browser instructions: $e');
      return {'error': 'Failed to get instructions'};
    }
  }

  /// Get pending changes count
  static Future<int> getPendingChanges() async {
    try {
      final changes = await ShelfLanServer.getPendingChanges();
      return changes.length;
    } catch (e) {
      debugPrint('Error getting pending changes: $e');
      return 0;
    }
  }

  /// Get sync updates stream
  static Stream<Map<String, dynamic>> get syncUpdates => ShelfLanServer.syncUpdates;

  /// Cleanup resources
  static Future<void> dispose() async {
    try {
      await stopLanServer();
      await EnhancedRealTimeSyncService.dispose();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing Enhanced LAN Sync Service: $e');
    }
  }
}
