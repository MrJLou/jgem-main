import 'package:flutter/material.dart';

class SessionNotificationService {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static OverlayEntry? _overlayEntry;

  /// Initialize with the navigator key from main app
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Get current context for navigation
  static BuildContext? getCurrentContext() {
    return _navigatorKey?.currentContext;
  }

  /// Show session conflict notification
  static void showSessionInvalidatedNotification() {
    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('SESSION_NOTIFICATION: No context available, cannot show overlay');
        return;
      }

      // Remove any existing overlay
      _overlayEntry?.remove();

      _overlayEntry = OverlayEntry(
        builder: (context) => _SessionInvalidatedOverlay(
          onDismiss: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
        ),
      );

      final overlay = Overlay.of(context);
      overlay.insert(_overlayEntry!);
    } catch (e) {
      debugPrint('SESSION_NOTIFICATION: Error showing session invalidated notification: $e');
      _overlayEntry = null;
    }
  }

  /// Show a simple snackbar notification
  static void showSnackBarNotification(String message, {Color? backgroundColor}) {
    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('SESSION_NOTIFICATION: No context available, cannot show snackbar');
        return;
      }

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
        ),
      );
    } catch (e) {
      debugPrint('SESSION_NOTIFICATION: Error showing snackbar notification: $e');
    }
  }
}

class _SessionInvalidatedOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _SessionInvalidatedOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.logout,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Session Ended',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has been logged in from another device. For security reasons, this session has been ended.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
