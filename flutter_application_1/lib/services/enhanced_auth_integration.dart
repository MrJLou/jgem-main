import 'package:flutter/material.dart';
import 'authentication_manager.dart';
import 'auth_service.dart';
import 'enhanced_user_token_service.dart';
import '../models/user.dart';

/// Enhanced Authentication Integration Service
/// 
/// This service provides a unified interface that combines:
/// 1. AuthService - Original service with forgot password and security questions
/// 2. AuthenticationManager - New token-based session management
/// 
/// Features:
/// - Seamless integration between old and new authentication systems
/// - Maintains all legacy functionality (forgot password, security questions)
/// - Adds new token-based session management
/// - Proper session cleanup and conflict resolution
/// - Backward compatibility
class EnhancedAuthIntegration {
  
  /// Initialize the enhanced authentication system
  /// Call this in your main.dart before runApp()
  static Future<void> initialize() async {
    try {
      debugPrint('ENHANCED_AUTH: Initializing enhanced authentication system');
      
      // Initialize the new authentication manager
      await AuthenticationManager.initialize();
      
      debugPrint('ENHANCED_AUTH: Enhanced authentication system initialized successfully');
    } catch (e) {
      debugPrint('ENHANCED_AUTH: Error initializing authentication system: $e');
      // Don't rethrow - allow app to continue even if initialization fails
    }
  }

  /// Dispose the authentication system
  /// Call this when the app is closing
  static void dispose() {
    AuthenticationManager.dispose();
  }

  /// Comprehensive login method that handles both session management and legacy features
  /// 
  /// [username] - User's username
  /// [password] - User's password
  /// [forceLogout] - Whether to force logout from other devices
  /// 
  /// Returns authentication response with user data and session info
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    bool forceLogout = false,
  }) async {
    try {
      debugPrint('ENHANCED_AUTH: Starting login for user: $username');
      
      // Use the new AuthenticationManager for login with session management
      final result = await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: forceLogout,
      );
      
      debugPrint('ENHANCED_AUTH: Login successful for user: $username');
      return result;
      
    } on UserSessionConflictException catch (e) {
      debugPrint('ENHANCED_AUTH: Session conflict detected for user: $username');
      // Return structured response for UI handling
      return {
        'success': false,
        'error': 'session_conflict',
        'message': e.message,
        'activeSessions': e.activeSessions,
        'requiresForceLogout': true,
      };
    } catch (e) {
      debugPrint('ENHANCED_AUTH: Login failed for user: $username - $e');
      return {
        'success': false,
        'error': 'login_failed',
        'message': e.toString(),
      };
    }
  }

  /// Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    return await AuthenticationManager.isLoggedIn();
  }

  /// Get current logged-in user
  static Future<User?> getCurrentUser() async {
    return await AuthenticationManager.getCurrentUser();
  }

  /// Get current username
  static Future<String?> getCurrentUsername() async {
    return await AuthenticationManager.getCurrentUsername();
  }

  /// Get current user's access level
  static Future<String?> getCurrentUserAccessLevel() async {
    return await AuthenticationManager.getCurrentUserAccessLevel();
  }

  /// Check if current user has specific role
  static Future<bool> hasRole(String requiredRole) async {
    return await AuthenticationManager.hasRole(requiredRole);
  }

  /// Logout current user
  static Future<void> logout() async {
    await AuthenticationManager.logout();
  }

  /// Force logout a specific user (admin function)
  static Future<void> forceLogoutUser(String username) async {
    await AuthenticationManager.forceLogoutUser(username);
  }

  /// Check if user is logged in on other devices
  static Future<bool> isUserLoggedInElsewhere(String username) async {
    return await AuthenticationManager.isUserLoggedInElsewhere(username);
  }

  /// Get session statistics (admin function)
  static Future<Map<String, dynamic>> getSessionStatistics() async {
    return await AuthenticationManager.getSessionStatistics();
  }

  // ============== LEGACY AUTH SERVICE METHODS ==============
  // These methods provide access to the original AuthService functionality

  /// Reset password using security questions
  static Future<Map<String, dynamic>> resetPasswordWithSecurityQuestions({
    required String username,
    required String securityAnswer1,
    required String securityAnswer2,
    required String newPassword,
  }) async {
    return await AuthService.resetPasswordWithSecurityQuestions(
      username: username,
      securityAnswer1: securityAnswer1,
      securityAnswer2: securityAnswer2,
      newPassword: newPassword,
    );
  }

  /// Update security questions for a user
  static Future<Map<String, dynamic>> updateSecurityQuestions({
    required String username,
    required String currentPassword,
    required String securityQuestion1,
    required String securityAnswer1,
    required String securityQuestion2,
    required String securityAnswer2,
  }) async {
    return await AuthService.updateSecurityQuestions(
      username: username,
      currentPassword: currentPassword,
      securityQuestion1: securityQuestion1,
      securityAnswer1: securityAnswer1,
      securityQuestion2: securityQuestion2,
      securityAnswer2: securityAnswer2,
    );
  }

  /// Get security questions for a user
  static Future<Map<String, dynamic>> getSecurityQuestions(String username) async {
    return await AuthService.getSecurityQuestions(username);
  }

  /// Change password for logged in user
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await AuthService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Hash password (utility method)
  static String hashPassword(String password) {
    return AuthService.hashPassword(password);
  }

  /// Verify password (utility method)
  static bool verifyPassword(String password, String hashedPassword) {
    return AuthService.verifyPassword(password, hashedPassword);
  }

  /// Hash security answer (utility method)
  static String hashSecurityAnswer(String answer) {
    return AuthService.hashSecurityAnswer(answer);
  }

  /// Verify security answer (utility method)
  static bool verifySecurityAnswer(String providedAnswer, String hashedAnswer) {
    return AuthService.verifySecurityAnswer(providedAnswer, hashedAnswer);
  }

  // ============== ENHANCED SESSION MANAGEMENT ==============

  /// Get active sessions for a user (admin function)
  static Future<List<Map<String, dynamic>>> getActiveUserSessions(String username) async {
    return await EnhancedUserTokenService.getActiveUserSessions(username);
  }

  /// Clean up expired sessions (maintenance function)
  static Future<void> cleanupExpiredSessions() async {
    await EnhancedUserTokenService.cleanupExpiredSessions();
  }

  /// Validate a specific session token
  static Future<bool> validateSessionToken(String username, String sessionToken) async {
    return await EnhancedUserTokenService.validateSessionToken(username, sessionToken);
  }

  /// Extend current session
  static Future<bool> extendCurrentSession({Duration? duration}) async {
    try {
      final token = await EnhancedUserTokenService.getCurrentSessionToken();
      if (token != null) {
        return await EnhancedUserTokenService.extendSession(token, duration: duration);
      }
      return false;
    } catch (e) {
      debugPrint('ENHANCED_AUTH: Error extending session: $e');
      return false;
    }
  }
}

/// Enhanced Login Integration for UI Components
/// 
/// This class provides high-level methods for UI components to handle
/// the complete login flow including session conflicts.
class EnhancedLoginIntegration {
  
  /// Perform login with automatic session conflict handling
  /// 
  /// [context] - BuildContext for showing dialogs
  /// [username] - User's username
  /// [password] - User's password
  /// [onSuccess] - Callback for successful login
  /// [onError] - Callback for login errors
  /// [onSessionConflict] - Callback for session conflicts (optional)
  /// 
  /// Returns true if login was successful
  static Future<bool> performLogin({
    required BuildContext context,
    required String username,
    required String password,
    VoidCallback? onSuccess,
    Function(String error)? onError,
    Function(List<Map<String, dynamic>> activeSessions)? onSessionConflict,
  }) async {
    try {
      // First attempt login without forcing logout
      final result = await EnhancedAuthIntegration.login(
        username: username,
        password: password,
        forceLogout: false,
      );

      if (result['success'] == true) {
        onSuccess?.call();
        return true;
      }

      // Handle session conflict
      if (result['error'] == 'session_conflict') {
        final activeSessions = result['activeSessions'] as List<Map<String, dynamic>>? ?? [];
        
        if (onSessionConflict != null) {
          onSessionConflict(activeSessions);
          return false;
        }
        
        // Show default session conflict dialog
        final shouldForceLogin = await _showSessionConflictDialog(context, activeSessions);
        
        if (shouldForceLogin) {
          // Retry with force logout
          final forceResult = await EnhancedAuthIntegration.login(
            username: username,
            password: password,
            forceLogout: true,
          );
          
          if (forceResult['success'] == true) {
            onSuccess?.call();
            return true;
          } else {
            onError?.call(forceResult['message'] ?? 'Login failed');
            return false;
          }
        }
        return false;
      }

      // Handle other errors
      onError?.call(result['message'] ?? 'Login failed');
      return false;
      
    } catch (e) {
      debugPrint('ENHANCED_LOGIN: Error during login: $e');
      onError?.call('An unexpected error occurred');
      return false;
    }
  }

  /// Show session conflict dialog
  static Future<bool> _showSessionConflictDialog(
    BuildContext context, 
    List<Map<String, dynamic>> activeSessions,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Already Logged In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You are already logged in on another device:'),
              const SizedBox(height: 12),
              ...activeSessions.map((session) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '• ${session['deviceName'] ?? 'Unknown Device'} (${session['loginTime'] ?? 'Unknown time'})',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
              const SizedBox(height: 12),
              const Text('Do you want to logout from other devices and continue?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Force Login'),
            ),
          ],
        );
      },
    ) ?? false;
  }
}
