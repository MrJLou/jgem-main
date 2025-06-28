import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'database_sync_client.dart';
import 'authentication_manager.dart'; // Use the new auth manager
import '../models/user.dart';

/// Enhanced AuthService - Integrates original functionality with new token system
/// 
/// This service provides:
/// - Original features: Password hashing, forgot password, security questions
/// - New features: Single device login, session tokens, real-time monitoring
/// - Backwards compatibility for existing code
class AuthService {
  static const bool isDevMode = false; // Set to false for production
  
  // Legacy keys for compatibility (but will use AuthenticationManager internally)
  static const _authTokenKey = 'auth_token';
  static const _tokenExpiryKey = 'token_expiry';
  static const _usernameKey = 'username';
  static const _accessLevelKey = 'access_level';
  static const _deviceIdKey = 'device_id';
  static const _isLoggedInKey = 'is_logged_in';
  
  // Debounce for login logging
  static String? _lastLoggedInUser;
  static DateTime? _lastLoginLogTime;
  static const Duration _loginLogDebounceDuration = Duration(seconds: 5);

  // Current user role for authorization
  static String? _currentUserRole;

  // Token expiration duration (in minutes) - legacy constant
  static const int _tokenValidityMinutes = 60; // 1 hour

  // Use secure storage for sensitive information (for forgot password, etc.)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Hash passwords using BCrypt with cost factor of 12
  static String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
  }

  // Hash security answer - similar to password for added protection
  static String hashSecurityAnswer(String answer) {
    return BCrypt.hashpw(
        answer.trim().toLowerCase(), BCrypt.gensalt(logRounds: 8));
  }

  // Verify security answer
  static bool verifySecurityAnswer(String providedAnswer, String hashedAnswer) {
    try {
      return BCrypt.checkpw(providedAnswer.trim().toLowerCase(), hashedAnswer);
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying security answer: $e');
      }
      return false;
    }
  }

  // Verify password against hashed password
  static bool verifyPassword(String password, String hashedPassword) {
    try {
      return BCrypt.checkpw(password, hashedPassword);
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying password: $e');
      }
      return false;
    }
  }

  // Generate a unique device ID if not exists
  static Future<String> getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);

    if (deviceId == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = DateTime.now().microsecond.toString();
      final bytes = utf8.encode(timestamp + random);
      final digest = sha256.convert(bytes);
      deviceId = digest.toString().substring(0, 16);

      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    }

    return deviceId;
  }

  /// Logout using the new authentication manager
  static Future<void> logout() async {
    try {
      debugPrint('AuthService: Initiating logout via AuthenticationManager');
      
      // Clear current user role
      _currentUserRole = null;
      
      // Use the new authentication manager for logout
      await AuthenticationManager.logout();
      
      // Also clear any legacy secure storage data for compatibility
      await _clearLegacyCredentials();
      
      debugPrint('AuthService: Logout completed successfully');
    } catch (e) {
      debugPrint('AuthService: Error during logout: $e');
      // Fallback: clear legacy credentials
      await _clearLegacyCredentials();
      rethrow;
    }
  }

  /// Clear legacy credentials from secure storage
  static Future<void> _clearLegacyCredentials() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      await _secureStorage.delete(key: _usernameKey);
      await _secureStorage.delete(key: _accessLevelKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_accessLevelKey);
      await prefs.setBool(_isLoggedInKey, false);
    } catch (e) {
      debugPrint('AuthService: Error clearing legacy credentials: $e');
    }
  }

  /// Check if user is logged in using the new authentication manager
  static Future<bool> isLoggedIn() async {
    if (isDevMode) return true;
    
    try {
      return await AuthenticationManager.isLoggedIn();
    } catch (e) {
      debugPrint('AuthService: Error checking login status: $e');
      return false;
    }
  }

  /// Get saved credentials using the new authentication manager
  static Future<Map<String, String>?> getSavedCredentials() async {
    if (isDevMode) {
      return {
        'token': 'dev_token',
        'username': 'developer',
        'accessLevel': 'admin',
      };
    }

    try {
      final isUserLoggedIn = await isLoggedIn();
      if (!isUserLoggedIn) return null;

      final username = await AuthenticationManager.getCurrentUsername();
      final accessLevel = await AuthenticationManager.getCurrentUserAccessLevel();

      if (username != null && accessLevel != null) {
        return {
          'token': 'new_token_system', // Legacy compatibility
          'username': username,
          'accessLevel': accessLevel,
        };
      }
      return null;
    } catch (e) {
      debugPrint('AuthService: Error getting saved credentials: $e');
      return null;
    }
  }

  /// Save login credentials using the new authentication manager (deprecated - handled internally)
  static Future<void> saveLoginCredentials({
    required String token,
    required String username,
    required String accessLevel,
  }) async {
    if (isDevMode) return;

    // Log that this method is deprecated
    debugPrint('AuthService: saveLoginCredentials is deprecated - credentials are managed by AuthenticationManager');
    
    // Update current user role for legacy compatibility
    _currentUserRole = accessLevel;

    // Log activity with debounce
    final now = DateTime.now();
    if (_lastLoggedInUser != username ||
        _lastLoginLogTime == null ||
        now.difference(_lastLoginLogTime!) > _loginLogDebounceDuration) {
      final db = DatabaseHelper();
      await db.logUserActivity(username, 'User logged in (legacy auth service call)');
      _lastLoggedInUser = username;
      _lastLoginLogTime = now;
    }
  }

  /// Clear saved credentials (deprecated - use logout() instead)
  static Future<void> clearCredentials() async {
    if (isDevMode) return;
    
    debugPrint('AuthService: clearCredentials is deprecated - use logout() instead');
    await logout();
  }

  /// Refresh token (handled by AuthenticationManager session monitoring)
  static Future<bool> refreshToken() async {
    if (isDevMode) return true;

    try {
      // Check if session is still valid (this will handle refresh internally)
      return await isLoggedIn();
    } catch (e) {
      debugPrint('AuthService: Error refreshing token: $e');
      return false;
    }
  }

  /// Verify if current user has specific role
  static Future<bool> hasRole(String requiredRole) async {
    try {
      return await AuthenticationManager.hasRole(requiredRole);
    } catch (e) {
      debugPrint('AuthService: Error checking role: $e');
      return false;
    }
  }

  /// Get remaining token validity time (legacy - returns default)
  static Future<int> getTokenRemainingTime() async {
    if (isDevMode) return _tokenValidityMinutes * 60;

    // Since new system handles expiration differently, return a default value
    final isValid = await isLoggedIn();
    return isValid ? (_tokenValidityMinutes * 60) : 0;
  }

  /// Get current logged-in username
  static Future<String?> getCurrentUsername() async {
    try {
      return await AuthenticationManager.getCurrentUsername();
    } catch (e) {
      debugPrint('AuthService: Error getting current username: $e');
      return null;
    }
  }

  /// Get current logged-in user's details from DB
  static Future<User?> getCurrentUser() async {
    try {
      return await AuthenticationManager.getCurrentUser();
    } catch (e) {
      debugPrint('AuthService: Error getting current user: $e');
      return null;
    }
  }

  /// Get current logged-in user's ID
  static Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?.id;
  }

  /// Get current user's access level
  static Future<String?> getCurrentUserAccessLevel() async {
    try {
      return await AuthenticationManager.getCurrentUserAccessLevel();
    } catch (e) {
      debugPrint('AuthService: Error getting access level: $e');
      return null;
    }
  }

  /// Get current user role (cached)
  static String? getCurrentUserRole() {
    return _currentUserRole;
  }

  /// Clear current user role
  static void clearCurrentUserRole() {
    _currentUserRole = null;
  }

  /// Enhanced login with session management using AuthenticationManager
  static Future<Map<String, dynamic>> loginWithSessionManagement(
      String username, String password,
      {bool forceLogoutExisting = false}) async {
    try {
      debugPrint('AuthService: Using AuthenticationManager for login with session management');
      
      // Use the new authentication manager
      final response = await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: forceLogoutExisting,
      );
      
      // Update current user role for legacy compatibility
      final user = response['user'];
      if (user != null) {
        _currentUserRole = user.role;
      }
      
      debugPrint('AuthService: Login successful via AuthenticationManager');
      return response;
    } catch (e) {
      debugPrint('AuthService: Login failed: $e');
      rethrow;
    }
  }

  /// Validate current session using AuthenticationManager
  static Future<bool> validateCurrentSession() async {
    try {
      return await AuthenticationManager.isLoggedIn();
    } catch (e) {
      debugPrint('AuthService: Error validating session: $e');
      return false;
    }
  }

  /// Force logout due to session invalidation from another device
  static Future<void> forceLogoutDueToSessionInvalidation() async {
    try {
      debugPrint('AuthService: Handling force logout due to session invalidation');
      
      // Clear current user role
      _currentUserRole = null;
      
      // Use AuthenticationManager to handle the logout
      await AuthenticationManager.handleSessionInvalidation();
      
      debugPrint('AuthService: Force logout completed');
    } catch (e) {
      debugPrint('AuthService: Error during force logout: $e');
    }
  }



  /// Handle session invalidation from another device
  static Future<void> handleSessionInvalidationFromOtherDevice(Map<String, dynamic> data) async {
    try {
      final deviceId = await getDeviceId();
      final targetDeviceId = data['deviceId'];
      
      if (targetDeviceId == deviceId) {
        debugPrint('AuthService: Session invalidated by another device, delegating to AuthenticationManager');
        await AuthenticationManager.handleSessionInvalidation();
      }
    } catch (e) {
      debugPrint('AuthService: Error handling session invalidation: $e');
    }
  }

  /// Initialize session monitoring using AuthenticationManager
  static void initializeSessionMonitoring() {
    try {
      debugPrint('AuthService: Initializing session monitoring via AuthenticationManager');
      
      // Initialize AuthenticationManager
      AuthenticationManager.initialize();
      
      // Listen for session invalidation events from the sync client
      DatabaseSyncClient.syncUpdates.listen((event) {
        if (event['type'] == 'session_invalidated') {
          final data = event['data'] as Map<String, dynamic>?;
          if (data != null) {
            handleSessionInvalidationFromOtherDevice(data);
          }
        }
      });
      
      debugPrint('AuthService: Session monitoring initialized');
    } catch (e) {
      debugPrint('AuthService: Error initializing session monitoring: $e');
    }
  }

  // ============== FORGOT PASSWORD & SECURITY QUESTIONS ==============
  // These methods remain unchanged as they're specific to AuthService

  /// Reset password using security questions
  static Future<Map<String, dynamic>> resetPasswordWithSecurityQuestions({
    required String username,
    required String securityAnswer1,
    required String securityAnswer2,
    required String newPassword,
  }) async {
    try {
      final db = DatabaseHelper();
      
      // Get user by username
      final user = await db.getUserByUsername(username);
      if (user == null) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }

      // Verify security answers
      if (user.securityAnswer1 == null || user.securityAnswer2 == null) {
        return {
          'success': false,
          'message': 'Security questions not set for this user',
        };
      }

      final answer1Valid = verifySecurityAnswer(securityAnswer1, user.securityAnswer1!);
      final answer2Valid = verifySecurityAnswer(securityAnswer2, user.securityAnswer2!);

      if (!answer1Valid || !answer2Valid) {
        return {
          'success': false,
          'message': 'Security answers do not match',
        };
      }

      // Hash new password
      final hashedPassword = hashPassword(newPassword);

      // Update password in database
      final userUpdateMap = {
        'id': user.id,
        'password': hashedPassword,
      };
      final updated = await db.updateUser(userUpdateMap);

      if (updated > 0) {
        // Log the password reset activity
        await db.logUserActivity(
          username,
          'Password reset via security questions',
        );

        return {
          'success': true,
          'message': 'Password reset successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update password',
        };
      }
    } catch (e) {
      debugPrint('AuthService: Error resetting password: $e');
      return {
        'success': false,
        'message': 'An error occurred while resetting password: ${e.toString()}',
      };
    }
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
    try {
      final db = DatabaseHelper();
      
      // Authenticate user with current password
      final auth = await db.authenticateUser(username, currentPassword);
      if (auth == null || auth['user'] == null) {
        return {
          'success': false,
          'message': 'Current password is incorrect',
        };
      }

      final user = auth['user'] as User;

      // Hash security answers
      final hashedAnswer1 = hashSecurityAnswer(securityAnswer1);
      final hashedAnswer2 = hashSecurityAnswer(securityAnswer2);

      // Update security questions in database
      final updated = await db.updateUserSecurityQuestions(
        user.id,
        securityQuestion1,
        hashedAnswer1,
        securityQuestion2,
        hashedAnswer2,
        '', // securityQuestion3 - empty for now
        '', // hashedAnswer3 - empty for now
      );

      if (updated > 0) {
        // Log the security questions update activity
        await db.logUserActivity(
          username,
          'Security questions updated',
        );

        return {
          'success': true,
          'message': 'Security questions updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update security questions',
        };
      }
    } catch (e) {
      debugPrint('AuthService: Error updating security questions: $e');
      return {
        'success': false,
        'message': 'An error occurred while updating security questions: ${e.toString()}',
      };
    }
  }

  /// Get security questions for a user (without answers)
  static Future<Map<String, dynamic>> getSecurityQuestions(String username) async {
    try {
      final db = DatabaseHelper();
      
      final user = await db.getUserByUsername(username);
      if (user == null) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }

      return {
        'success': true,
        'questions': {
          'question1': user.securityQuestion1,
          'question2': user.securityQuestion2,
        },
      };
    } catch (e) {
      debugPrint('AuthService: Error getting security questions: $e');
      return {
        'success': false,
        'message': 'An error occurred while retrieving security questions: ${e.toString()}',
      };
    }
  }

  /// Change password for logged in user
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final username = await getCurrentUsername();
      if (username == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      final db = DatabaseHelper();
      
      // Verify current password
      final auth = await db.authenticateUser(username, currentPassword);
      if (auth == null || auth['user'] == null) {
        return {
          'success': false,
          'message': 'Current password is incorrect',
        };
      }

      final user = auth['user'] as User;

      // Hash new password
      final hashedPassword = hashPassword(newPassword);

      // Update password in database
      final updated = await db.updateUserPassword(user.id, hashedPassword);

      if (updated > 0) {
        // Log the password change activity
        await db.logUserActivity(
          username,
          'Password changed',
        );

        return {
          'success': true,
          'message': 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update password',
        };
      }
    } catch (e) {
      debugPrint('AuthService: Error changing password: $e');
      return {
        'success': false,
        'message': 'An error occurred while changing password: ${e.toString()}',
      };
    }
  }
}
