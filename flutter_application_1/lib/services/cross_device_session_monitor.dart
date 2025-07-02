import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enhanced_user_token_service.dart';
import 'database_sync_client.dart';
import 'enhanced_shelf_lan_server.dart';
import 'authentication_manager.dart';

/// Cross-Device Session Monitor
/// 
/// This service monitors session changes across all connected devices
/// and ensures proper session invalidation when a user logs in from a new device.
class CrossDeviceSessionMonitor {
  static Timer? _monitorTimer;
  static bool _isMonitoring = false;
  static StreamSubscription? _syncSubscription;
  static DateTime? _lastSyncRequest;
  static const Duration _syncCooldown = Duration(seconds: 10); // Throttle sync requests
  
  /// Initialize cross-device session monitoring
  static Future<void> initialize() async {
    try {
      // Listen for session-related sync updates
      _syncSubscription = DatabaseSyncClient.syncUpdates.listen((update) {
        _handleSyncUpdate(update);
      });
      
      // Start periodic session validation every 2 minutes
      startMonitoring();
      
      debugPrint('CROSS_DEVICE_MONITOR: Cross-device session monitoring initialized');
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error initializing: $e');
    }
  }
  
  /// Start monitoring sessions across devices
  static void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    // Increased interval to 5 minutes to reduce system load
    _monitorTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _checkSessionConsistency();
    });
    
    debugPrint('CROSS_DEVICE_MONITOR: Started session monitoring (5-minute intervals)');
  }
  
  /// Stop monitoring
  static void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    
    debugPrint('CROSS_DEVICE_MONITOR: Stopped session monitoring');
  }
  
  /// Dispose the monitor
  static void dispose() {
    stopMonitoring();
    _syncSubscription?.cancel();
    _syncSubscription = null;
  }
  
  /// Handle sync updates related to sessions
  static void _handleSyncUpdate(Map<String, dynamic> update) {
    try {
      final type = update['type'] as String?;
      
      switch (type) {
        case 'remote_change_applied':
          final change = update['change'] as Map<String, dynamic>?;
          if (change?['table'] == 'user_sessions') {
            _handleSessionTableChange(change);
          }
          break;
          
        case 'session_invalidated':
          _handleSessionInvalidation(update['data'] as Map<String, dynamic>?);
          break;
          
        case 'session_update':
          _handleSessionUpdate(update);
          break;
          
        case 'session_change_immediate':
          debugPrint('CROSS_DEVICE_MONITOR: Immediate session change detected');
          _handleSessionTableChange(update);
          break;
          
        case 'session_table_synced':
          debugPrint('CROSS_DEVICE_MONITOR: Session table sync completed');
          // Wait a moment for sync to fully complete before validation
          Future.delayed(const Duration(seconds: 2), () async {
            final isLoggedIn = await AuthenticationManager.isLoggedIn();
            if (isLoggedIn) {
              _checkCurrentSessionValidity();
            } else {
              debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping session table sync validation');
            }
          });
          break;
          
        case 'session_sync_validation_needed':
          debugPrint('CROSS_DEVICE_MONITOR: Session sync validation needed');
          Future.delayed(const Duration(seconds: 2), () async {
            final isLoggedIn = await AuthenticationManager.isLoggedIn();
            if (isLoggedIn) {
              _checkCurrentSessionValidity();
            } else {
              debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping session sync validation');
            }
          });
          break;
          
        case 'table_sync_completed':
          if (update['table'] == 'user_sessions') {
            debugPrint('CROSS_DEVICE_MONITOR: User sessions table sync completed');
            // Wait for sync operations to complete before checking
            Future.delayed(const Duration(seconds: 3), () async {
              final isLoggedIn = await AuthenticationManager.isLoggedIn();
              if (isLoggedIn) {
                _checkCurrentSessionValidity();
              } else {
                debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping table sync validation');
              }
            });
          }
          break;
          
        case 'force_table_sync':
          if (update['table'] == 'user_sessions') {
            _requestSessionRefresh();
          }
          break;
          
        case 'auth_conflict_check_needed':
          debugPrint('CROSS_DEVICE_MONITOR: Authentication conflict check requested');
          Future.delayed(const Duration(seconds: 2), () async {
            final isLoggedIn = await AuthenticationManager.isLoggedIn();
            if (isLoggedIn) {
              _checkForAuthenticationConflicts();
            } else {
              debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping auth conflict check');
            }
          });
          break;
      }
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error handling sync update: $e');
    }
  }
  
  /// Handle changes to the user_sessions table
  static void _handleSessionTableChange(Map<String, dynamic>? change) async {
    if (change == null) return;
    
    final operation = change['operation'] as String?;
    final recordId = change['recordId'] as String?;
    final table = change['table'] as String?;
    
    debugPrint('CROSS_DEVICE_MONITOR: Session table change detected: $operation for $recordId on table $table');
    
    // Only check session validity if we have an active session
    if (table == 'user_sessions') {
      // CRITICAL: First check if we're actually logged in before validating sessions
      final prefs = await SharedPreferences.getInstance();
      final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
      
      if (!hasStoredSession) {
        debugPrint('CROSS_DEVICE_MONITOR: No stored session state, ignoring session table change');
        return;
      }
      
      // Double-check authentication state
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CROSS_DEVICE_MONITOR: No active session, ignoring session table change');
        return;
      }
      
      switch (operation) {
        case 'insert':
          debugPrint('CROSS_DEVICE_MONITOR: New session created, checking for conflicts');
          _checkCurrentSessionValidity();
          break;
        case 'update':
          debugPrint('CROSS_DEVICE_MONITOR: Session updated, validating current session');
          _checkCurrentSessionValidity();
          break;
        case 'delete':
          debugPrint('CROSS_DEVICE_MONITOR: Session deleted, checking current session');
          _checkCurrentSessionValidity();
          break;
      }
    }
  }
  
  /// Handle session invalidation messages
  static void _handleSessionInvalidation(Map<String, dynamic>? data) async {
    if (data == null) return;
    
    final username = data['username'] as String?;
    debugPrint('CROSS_DEVICE_MONITOR: Session invalidation received for user: $username');
    
    // CRITICAL: Only check if we're actually logged in to prevent false invalidations
    final prefs = await SharedPreferences.getInstance();
    final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
    
    if (!hasStoredSession) {
      debugPrint('CROSS_DEVICE_MONITOR: No stored session state, ignoring session invalidation');
      return;
    }
    
    // Double-check authentication state
    final isLoggedIn = await AuthenticationManager.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('CROSS_DEVICE_MONITOR: No active session, ignoring session invalidation');
      return;
    }
    
    // Check if this affects the current user
    _checkCurrentSessionValidity();
  }
  
  /// Handle session update messages
  static void _handleSessionUpdate(Map<String, dynamic> update) async {
    debugPrint('CROSS_DEVICE_MONITOR: Session update received: ${update['action']}');
    
    // CRITICAL: Only check if we're actually logged in to prevent false triggers
    final prefs = await SharedPreferences.getInstance();
    final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
    
    if (!hasStoredSession) {
      debugPrint('CROSS_DEVICE_MONITOR: No stored session state, ignoring session update');
      return;
    }
    
    // Double-check authentication state
    final isLoggedIn = await AuthenticationManager.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('CROSS_DEVICE_MONITOR: No active session, ignoring session update');
      return;
    }
    
    // Trigger session validation for current user
    _checkCurrentSessionValidity();
  }
  
  /// Check if current session is still valid
  static Future<void> _checkCurrentSessionValidity() async {
    try {
      // CRITICAL: First check stored session state before making expensive calls
      final prefs = await SharedPreferences.getInstance();
      final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
      
      if (!hasStoredSession) {
        debugPrint('CROSS_DEVICE_MONITOR: No stored session state, skipping session validity check');
        return;
      }
      
      // Then check if we're actually logged in to avoid false triggers
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CROSS_DEVICE_MONITOR: No active session to validate, skipping');
        return;
      }
      
      final isValid = await EnhancedUserTokenService.isCurrentSessionValid();
      
      if (!isValid) {
        debugPrint('CROSS_DEVICE_MONITOR: Current session is no longer valid, triggering logout');
        await AuthenticationManager.handleSessionInvalidation();
      } else {
        debugPrint('CROSS_DEVICE_MONITOR: Current session is valid');
      }
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error checking session validity: $e');
    }
  }
  
  /// Request session data refresh from network
  static void _requestSessionRefresh() {
    try {
      EnhancedUserTokenService.refreshSessionDataFromNetwork();
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error requesting session refresh: $e');
    }
  }
  
  /// Check session consistency across devices
  static Future<void> _checkSessionConsistency() async {
    try {
      if (!_isMonitoring) return;
      
      // CRITICAL: Only check if we have an active session to prevent false triggers
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping consistency check');
        return;
      }
      
      // Double-check we have a stored session state
      final prefs = await SharedPreferences.getInstance();
      final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
      if (!hasStoredSession) {
        debugPrint('CROSS_DEVICE_MONITOR: No stored session state, skipping consistency check');
        return;
      }
      
      // Refresh session data from network
      await EnhancedUserTokenService.refreshSessionDataFromNetwork();
      
      // Check if current session is still valid
      final isValid = await EnhancedUserTokenService.isCurrentSessionValid();
      
      if (!isValid) {
        debugPrint('CROSS_DEVICE_MONITOR: Session inconsistency detected, logging out');
        await AuthenticationManager.handleSessionInvalidation();
      }
      
      debugPrint('CROSS_DEVICE_MONITOR: Session consistency check completed');
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error during session consistency check: $e');
    }
  }
  
  /// Trigger immediate session sync after login/logout
  static Future<void> triggerImmediateSessionSync() async {
    try {
      // CRITICAL: Check stored session state first to prevent false triggers
      final prefs = await SharedPreferences.getInstance();
      final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
      
      if (!hasStoredSession) {
        debugPrint('CROSS_DEVICE_MONITOR: No stored session state, skipping immediate sync');
        return;
      }
      
      // Only sync if we have an active session to avoid triggering sync on login screen
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping immediate sync');
        return;
      }
      
      // Throttle sync requests to prevent system overload
      final now = DateTime.now();
      if (_lastSyncRequest != null && 
          now.difference(_lastSyncRequest!) < _syncCooldown) {
        debugPrint('CROSS_DEVICE_MONITOR: Sync request throttled, cooldown period active');
        return;
      }
      
      _lastSyncRequest = now;
      debugPrint('CROSS_DEVICE_MONITOR: Triggering immediate session sync');
      
      // Request immediate sync via client if connected to host
      if (DatabaseSyncClient.isConnected) {
        await DatabaseSyncClient.forceSessionSync();
        debugPrint('CROSS_DEVICE_MONITOR: Sent immediate session sync request to host');
      }
      
      // Force sync from host if running
      if (EnhancedShelfServer.isRunning) {
        await EnhancedShelfServer.forceSyncTable('user_sessions');
        debugPrint('CROSS_DEVICE_MONITOR: Forced session sync from host to all clients');
      }
      
      // Also trigger immediate session validation after a longer delay
      Future.delayed(const Duration(seconds: 3), () {
        _checkCurrentSessionValidity();
      });
      
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error triggering immediate session sync: $e');
    }
  }

  /// Force session sync across all devices for a specific user
  static Future<void> forceSyncUserSessions(String username) async {
    try {
      // Broadcast session sync request
      if (EnhancedShelfServer.isRunning) {
        await EnhancedShelfServer.forceSyncTable('user_sessions');
      }
      
      // Request sync via client if connected
      if (DatabaseSyncClient.isConnected) {
        DatabaseSyncClient.broadcastMessage({
          'type': 'request_table_sync',
          'table': 'user_sessions',
          'username': username,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      debugPrint('CROSS_DEVICE_MONITOR: Forced session sync for user: $username');
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error forcing session sync: $e');
    }
  }
  
  /// Get monitoring status
  static Map<String, dynamic> getStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'hasTimer': _monitorTimer != null,
      'hasSyncSubscription': _syncSubscription != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Check for authentication conflicts after session sync
  static Future<void> _checkForAuthenticationConflicts() async {
    try {
      // CRITICAL: Check stored session state first to prevent false triggers
      final prefs = await SharedPreferences.getInstance();
      final hasStoredSession = prefs.getBool('is_logged_in') ?? false;
      
      if (!hasStoredSession) {
        debugPrint('CROSS_DEVICE_MONITOR: No stored session state, skipping conflict check');
        return;
      }
      
      // Only check if we have an active session
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CROSS_DEVICE_MONITOR: No active session, skipping conflict check');
        return;
      }
      
      // Get current username
      final username = await AuthenticationManager.getCurrentUsername();
      if (username == null) {
        debugPrint('CROSS_DEVICE_MONITOR: No current username, skipping conflict check');
        return;
      }
      
      // Check for session conflicts after the sync
      final hasConflicts = await EnhancedUserTokenService.checkNetworkSessionConflicts(username);
      
      if (hasConflicts) {
        debugPrint('CROSS_DEVICE_MONITOR: Authentication conflict detected after sync');
        
        // Get the current session to see if it's still valid
        final isCurrentSessionValid = await EnhancedUserTokenService.isCurrentSessionValid();
        
        if (!isCurrentSessionValid) {
          debugPrint('CROSS_DEVICE_MONITOR: Current session is no longer valid, triggering logout');
          await AuthenticationManager.handleSessionInvalidation();
        } else {
          debugPrint('CROSS_DEVICE_MONITOR: Current session is still valid despite conflicts');
        }
      } else {
        debugPrint('CROSS_DEVICE_MONITOR: No authentication conflicts detected');
      }
    } catch (e) {
      debugPrint('CROSS_DEVICE_MONITOR: Error checking authentication conflicts: $e');
    }
  }
}
