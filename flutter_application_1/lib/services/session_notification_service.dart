import 'package:flutter/material.dart';
import 'dart:async';

class SessionNotificationService {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isShowingDialog = false;
  static bool _isNavigating = false;
  static Timer? _navigationTimer;

  /// Initialize with the navigator key from main app
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    debugPrint('SESSION_NOTIFICATION: Service initialized with navigator key');
  }

  /// Get current context for navigation
  static BuildContext? getCurrentContext() {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('SESSION_NOTIFICATION: No context available from navigator key');
    }
    return context;
  }

  /// Check if we have a valid overlay context
  static bool _hasValidOverlay() {
    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) return false;
      
      // Check if we can find an Overlay widget ancestor
      try {
        Overlay.of(context, rootOverlay: false);
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      debugPrint('SESSION_NOTIFICATION: Error checking overlay: $e');
      return false;
    }
  }

  /// Navigate to login screen safely (prevents multiple navigation)
  static void navigateToLogin() {
    // Prevent multiple navigation calls
    if (_isNavigating) {
      debugPrint('SESSION_NOTIFICATION: Already navigating, skipping');
      return;
    }

    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('SESSION_NOTIFICATION: No context available for navigation');
        return;
      }

      _isNavigating = true;
      
      // Cancel any pending navigation
      _navigationTimer?.cancel();
      
      // Delay navigation slightly to ensure context is ready
      _navigationTimer = Timer(const Duration(milliseconds: 100), () {
        try {
          final currentContext = _navigatorKey?.currentContext;
          if (currentContext != null && currentContext.mounted) {
            Navigator.of(currentContext).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
            debugPrint('SESSION_NOTIFICATION: Successfully navigated to login');
          }
        } catch (e) {
          debugPrint('SESSION_NOTIFICATION: Error in delayed navigation: $e');
        } finally {
          _isNavigating = false;
        }
      });
    } catch (e) {
      _isNavigating = false;
      debugPrint('SESSION_NOTIFICATION: Error navigating to login: $e');
    }
  }

  /// Show session conflict notification
  static void showSessionInvalidatedNotification() {
    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('SESSION_NOTIFICATION: No context available, cannot show notification');
        _fallbackToDirectNavigation();
        return;
      }

      // Prevent multiple dialogs
      if (_isShowingDialog) {
        debugPrint('SESSION_NOTIFICATION: Dialog already showing, skipping');
        return;
      }

      // Check if we have a valid overlay before showing dialog
      if (!_hasValidOverlay()) {
        debugPrint('SESSION_NOTIFICATION: No valid overlay found, using snackbar fallback');
        showSnackBarNotification(
          'Your session has been ended. You were logged in from another device.',
          backgroundColor: Colors.orange[700],
        );
        // Navigate after a short delay
        Timer(const Duration(seconds: 2), navigateToLogin);
        return;
      }

      // Try to show as a dialog first, fallback to snackbar
      try {
        _isShowingDialog = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true, // Use root navigator to avoid overlay issues
          builder: (BuildContext dialogContext) => const _SessionInvalidatedDialog(),
        ).whenComplete(() {
          _isShowingDialog = false;
        });
      } catch (dialogError) {
        _isShowingDialog = false;
        debugPrint('SESSION_NOTIFICATION: Dialog failed, using snackbar: $dialogError');
        // Fallback to snackbar notification
        showSnackBarNotification(
          'Your session has been ended. You were logged in from another device.',
          backgroundColor: Colors.orange[700],
        );
        // Navigate after showing snackbar
        Timer(const Duration(seconds: 2), navigateToLogin);
      }
    } catch (e) {
      _isShowingDialog = false;
      debugPrint('SESSION_NOTIFICATION: Error showing session invalidated notification: $e');
      _fallbackToDirectNavigation();
    }
  }

  /// Fallback to direct navigation when UI components fail
  static void _fallbackToDirectNavigation() {
    debugPrint('SESSION_NOTIFICATION: Using fallback navigation');
    Timer(const Duration(milliseconds: 500), navigateToLogin);
  }

  /// Show a simple snackbar notification
  static void showSnackBarNotification(String message, {Color? backgroundColor}) {
    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('SESSION_NOTIFICATION: No context available, cannot show snackbar');
        return;
      }

      // Ensure we have a mounted ScaffoldMessenger
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor ?? Colors.orange,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (scaffoldError) {
        debugPrint('SESSION_NOTIFICATION: ScaffoldMessenger error: $scaffoldError');
        // Last resort - just navigate without notification
        Timer(const Duration(milliseconds: 500), navigateToLogin);
      }
    } catch (e) {
      debugPrint('SESSION_NOTIFICATION: Error showing snackbar notification: $e');
      // Last resort - just navigate
      Timer(const Duration(milliseconds: 500), navigateToLogin);
    }
  }

  /// Clean up resources
  static void dispose() {
    _navigationTimer?.cancel();
    _isShowingDialog = false;
    _isNavigating = false;
  }
}

class _SessionInvalidatedDialog extends StatelessWidget {
  const _SessionInvalidatedDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.logout, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('Session Ended'),
        ],
      ),
      content: const Text(
        'Your account has been logged in from another device. For security reasons, this session has been ended.',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Use safe navigation to login
            SessionNotificationService.navigateToLogin();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
