import 'package:flutter/material.dart';
import '../services/authentication_manager.dart';
import '../services/enhanced_user_token_service.dart';
import '../screens/dashboard_screen_refactored.dart';
import '../screens/login_screen.dart';

/// Example integration of the Enhanced Authentication System
/// 
/// This file shows how to integrate the new token-based authentication
/// with your existing login flow. Replace your existing login logic
/// with this enhanced version.
class EnhancedLoginIntegration {
  
  /// Enhanced login method that prevents multiple device logins
  static Future<void> performLogin({
    required BuildContext context,
    required String username,
    required String password,
    bool showForceLoginDialog = true,
  }) async {
    try {
      // Show loading
      _showLoadingDialog(context);
      
      // Attempt login
      final response = await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: false, // Initially try without forcing logout
      );
      
      // Hide loading dialog
      Navigator.of(context).pop();
      
      if (response['success'] == true) {
        final user = response['user'];
        
        // Show success message
        _showSuccessMessage(context, 'Login successful!');
        
        // Navigate to dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              accessLevel: user.role,
            ),
          ),
          (route) => false,
        );
      }
    } on UserSessionConflictException catch (e) {
      // Hide loading dialog
      Navigator.of(context).pop();
      
      if (showForceLoginDialog) {
        // Show session conflict dialog
        await _showSessionConflictDialog(
          context: context,
          username: username,
          password: password,
          activeSessions: e.activeSessions,
        );
      } else {
        _showErrorMessage(context, 'User is already logged in on another device');
      }
    } catch (e) {
      // Hide loading dialog
      Navigator.of(context).pop();
      
      _showErrorMessage(context, 'Login failed: ${e.toString()}');
    }
  }

  /// Show session conflict dialog with force login option
  static Future<void> _showSessionConflictDialog({
    required BuildContext context,
    required String username,
    required String password,
    required List<Map<String, dynamic>> activeSessions,
  }) async {
    final shouldForceLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Account Already Active'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This account is already logged in on another device:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...activeSessions.map((session) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  const Icon(Icons.devices, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${session['deviceName'] ?? 'Unknown Device'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 15),
            const Text(
              'For security reasons, only one device can be logged in at a time.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ Continuing will automatically log out the other device.',
              style: TextStyle(
                fontSize: 12, 
                color: Colors.orange, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Force Login'),
          ),
        ],
      ),
    );

    if (shouldForceLogin == true) {
      // Perform force login
      await performForceLogin(
        context: context,
        username: username,
        password: password,
      );
    }
  }

  /// Perform force login (logout other devices)
  static Future<void> performForceLogin({
    required BuildContext context,
    required String username,
    required String password,
  }) async {
    try {
      // Show loading
      _showLoadingDialog(context, message: 'Logging out other devices...');
      
      // Login with force logout
      final response = await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: true,
      );
      
      // Hide loading dialog
      Navigator.of(context).pop();
      
      if (response['success'] == true) {
        final user = response['user'];
        
        // Show success message
        _showSuccessMessage(
          context, 
          'Login successful! Other device has been logged out.'
        );
        
        // Navigate to dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              accessLevel: user.role,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Hide loading dialog
      Navigator.of(context).pop();
      
      _showErrorMessage(context, 'Force login failed: ${e.toString()}');
    }
  }

  /// Check login status on app startup
  static Future<Widget> checkAuthenticationStatus() async {
    try {
      // Initialize authentication manager
      await AuthenticationManager.initialize();
      
      // Check if user is logged in
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      
      if (isLoggedIn) {
        final accessLevel = await AuthenticationManager.getCurrentUserAccessLevel();
        return DashboardScreen(accessLevel: accessLevel ?? 'user');
      } else {
        return const LoginScreen();
      }
    } catch (e) {
      // On error, go to login screen
      return const LoginScreen();
    }
  }

  /// Logout with proper cleanup
  static Future<void> performLogout(BuildContext context) async {
    try {
      _showLoadingDialog(context, message: 'Logging out...');
      
      await AuthenticationManager.logout();
      
      Navigator.of(context).pop(); // Hide loading
      
      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      
      _showSuccessMessage(context, 'Logged out successfully');
    } catch (e) {
      Navigator.of(context).pop(); // Hide loading
      _showErrorMessage(context, 'Logout failed: ${e.toString()}');
    }
  }

  /// Check if current user has required role
  static Future<bool> checkUserRole(String requiredRole) async {
    return await AuthenticationManager.hasRole(requiredRole);
  }

  /// Get session statistics (for admin users)
  static Future<Map<String, dynamic>> getSessionStatistics() async {
    return await AuthenticationManager.getSessionStatistics();
  }

  // Helper methods for UI feedback

  static void _showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message ?? 'Please wait...'),
          ],
        ),
      ),
    );
  }

  static void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Example usage in your main.dart file:
/// 
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       title: 'Your App',
///       home: FutureBuilder<Widget>(
///         future: EnhancedLoginIntegration.checkAuthenticationStatus(),
///         builder: (context, snapshot) {
///           if (snapshot.connectionState == ConnectionState.waiting) {
///             return const Scaffold(
///               body: Center(child: CircularProgressIndicator()),
///             );
///           }
///           return snapshot.data ?? const LoginScreen();
///         },
///       ),
///     );
///   }
/// }
/// ```
/// 
/// Example usage in your login screen:
/// 
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     await EnhancedLoginIntegration.performLogin(
///       context: context,
///       username: _usernameController.text,
///       password: _passwordController.text,
///     );
///   },
///   child: const Text('Login'),
/// )
/// ```
