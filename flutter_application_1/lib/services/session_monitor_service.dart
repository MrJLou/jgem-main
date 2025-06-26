import 'dart:async';
import 'package:flutter/foundation.dart';
import 'lan_session_service.dart';
import 'auth_service.dart';

/// Service to monitor session events and handle automatic logout
class SessionMonitorService {
  static StreamSubscription? _sessionSubscription;
  static bool _isInitialized = false;

  /// Initialize session monitoring
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Listen for session updates
      _sessionSubscription = LanSessionService.sessionUpdates.listen((update) {
        debugPrint(
            'SessionMonitorService: Received session update: ${update['type']}');
        _handleSessionUpdate(update);
      });

      _isInitialized = true;
      debugPrint('SessionMonitorService: Initialized successfully');
    } catch (e) {
      debugPrint('SessionMonitorService: Failed to initialize: $e');
    }
  }

  /// Handle session updates
  static void _handleSessionUpdate(Map<String, dynamic> update) async {
    try {
      final type = update['type'] as String?;

      switch (type) {
        case 'session_invalidated':
          await _handleSessionInvalidated(update);
          break;
        case 'user_logout':
          await _handleUserLogout(update);
          break;
        case 'database_changed':
          await _handleDatabaseChanged(update);
          break;
      }
    } catch (e) {
      debugPrint('SessionMonitorService: Error handling session update: $e');
    }
  }

  /// Handle session invalidation (user logged in from another device)
  static Future<void> _handleSessionInvalidated(
      Map<String, dynamic> update) async {
    try {
      final deviceId = await AuthService.getDeviceId();
      final targetDeviceId = update['deviceId'] as String?;

      // Check if this device is the target of the invalidation
      if (targetDeviceId == deviceId) {
        debugPrint(
            'SessionMonitorService: Session invalidated for this device');

        // Force logout on this device
        await AuthService.forceLogoutDueToSessionInvalidation();

        // Notify UI components that logout occurred
        _sessionInvalidatedController.add({
          'reason': update['reason'] ?? 'Session invalidated',
          'username': update['username'],
        });
      }
    } catch (e) {
      debugPrint(
          'SessionMonitorService: Error handling session invalidation: $e');
    }
  }

  /// Handle user logout events
  static Future<void> _handleUserLogout(Map<String, dynamic> update) async {
    try {
      final currentUsername = await AuthService.getCurrentUsername();
      final loggedOutUsername = update['username'] as String?;

      // Check if current user was logged out
      if (currentUsername == loggedOutUsername) {
        // Validate our session is still valid
        final isValid = await AuthService.validateCurrentSession();
        if (!isValid) {
          debugPrint('SessionMonitorService: Current session no longer valid');
          _sessionInvalidatedController.add({
            'reason': 'You have been logged out from another device',
            'username': loggedOutUsername,
          });
        }
      }
    } catch (e) {
      debugPrint('SessionMonitorService: Error handling user logout: $e');
    }
  }

  /// Handle database changes (for real-time updates)
  static Future<void> _handleDatabaseChanged(
      Map<String, dynamic> update) async {
    try {
      // Notify UI components that database has changed
      _databaseChangedController.add(update);
    } catch (e) {
      debugPrint('SessionMonitorService: Error handling database change: $e');
    }
  }

  // Stream controllers for UI notifications
  static final StreamController<Map<String, dynamic>>
      _sessionInvalidatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>>
      _databaseChangedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream for session invalidation events (UI should listen to this)
  static Stream<Map<String, dynamic>> get sessionInvalidated =>
      _sessionInvalidatedController.stream;

  /// Stream for database change events (UI should listen to this)
  static Stream<Map<String, dynamic>> get databaseChanged =>
      _databaseChangedController.stream;

  /// Dispose the service
  static Future<void> dispose() async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;

    if (!_sessionInvalidatedController.isClosed) {
      await _sessionInvalidatedController.close();
    }
    if (!_databaseChangedController.isClosed) {
      await _databaseChangedController.close();
    }

    _isInitialized = false;
    debugPrint('SessionMonitorService: Disposed');
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;
}
