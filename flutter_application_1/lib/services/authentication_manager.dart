import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import 'database_helper.dart';
import 'enhanced_user_token_service.dart';
import 'session_notification_service.dart';
import '../models/user.dart';

/// Comprehensive Authentication Manager
/// 
/// This service manages the complete authentication flow with token-based
/// session management to prevent multiple concurrent logins.
/// 
/// Features:
/// - Single device login enforcement
/// - Automatic session expiration
/// - Force logout capability
/// - Real-time session monitoring
/// - Secure token management
class AuthenticationManager {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _usernameKey = 'auth_username';
  static const String _accessLevelKey = 'auth_access_level';
  static const String _lastActivityKey = 'last_activity';
  
  static Timer? _sessionMonitorTimer;
  static bool _isMonitoring = false;
  
  /// Login with session management
  /// 
  /// [username] - User's username
  /// [password] - User's password
  /// [forceLogout] - Whether to force logout existing sessions
  /// 
  /// Returns authentication response with user data and token
  /// Throws [UserSessionConflictException] if user is already logged in elsewhere
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    bool forceLogout = false,
  }) async {
    try {
      debugPrint('AUTH_MANAGER: Starting login for user: $username, forceLogout: $forceLogout');
      
      // First authenticate credentials
      final db = DatabaseHelper();
      final auth = await db.authenticateUser(username, password);
      
      if (auth == null || auth['user'] == null) {
        throw Exception('Invalid username or password');
      }
      
      final user = auth['user'] as User;
      debugPrint('AUTH_MANAGER: Credentials validated for user: $username');
      
      // Check for existing sessions only if not forcing logout
      if (!forceLogout) {
        final hasActiveSession = await EnhancedUserTokenService.hasActiveSession(username);
        debugPrint('AUTH_MANAGER: Has active session: $hasActiveSession');
        
        if (hasActiveSession) {
          final activeSessions = await EnhancedUserTokenService.getActiveUserSessions(username);
          debugPrint('AUTH_MANAGER: Throwing UserSessionConflictException - ${activeSessions.length} active sessions found');
          throw UserSessionConflictException(
            'User is already logged in on another device',
            activeSessions,
          );
        }
      }
      
      // Create new session (this will invalidate existing ones if forceLogout is true)
      debugPrint('AUTH_MANAGER: Creating new session with forceLogout: $forceLogout');
      final sessionToken = await EnhancedUserTokenService.createUserSession(
        username: username,
        forceLogout: forceLogout,
      );
      
      // Save authentication state
      await _saveAuthenticationState(
        username: username,
        accessLevel: user.role,
        sessionToken: sessionToken,
      );
      
      // Start session monitoring
      startSessionMonitoring();
      
      // Log successful login
      await db.logUserActivity(
        username,
        'User logged in successfully',
        details: 'Force logout: $forceLogout',
      );
      
      debugPrint('AUTH_MANAGER: Login successful for user: $username');
      
      return {
        'token': sessionToken,
        'user': user,
        'success': true,
      };
    } catch (e) {
      debugPrint('AUTH_MANAGER: Login failed for user: $username - $e');
      rethrow;
    }
  }

  /// Check if user is currently logged in and session is valid
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (!isLoggedIn) {
        return false;
      }
      
      // Verify session is still valid
      final username = prefs.getString(_usernameKey);
      if (username == null) {
        await logout();
        return false;
      }
      
      final isSessionValid = await EnhancedUserTokenService.isCurrentSessionValid();
      if (!isSessionValid) {
        await logout();
        return false;
      }
      
      // Update last activity
      await _updateLastActivity();
      
      return true;
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error checking login status: $e');
      await logout(); // Clean up on error
      return false;
    }
  }

  /// Get current logged-in username
  static Future<String?> getCurrentUsername() async {
    try {
      if (!await isLoggedIn()) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_usernameKey);
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error getting current username: $e');
      return null;
    }
  }

  /// Get current user details
  static Future<User?> getCurrentUser() async {
    try {
      final username = await getCurrentUsername();
      if (username == null) {
        return null;
      }
      
      final db = DatabaseHelper();
      return await db.getUserByUsername(username);
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error getting current user: $e');
      return null;
    }
  }

  /// Get current user's access level/role
  static Future<String?> getCurrentUserAccessLevel() async {
    try {
      if (!await isLoggedIn()) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessLevelKey);
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error getting access level: $e');
      return null;
    }
  }

  /// Check if current user has specific role or higher
  static Future<bool> hasRole(String requiredRole) async {
    try {
      final accessLevel = await getCurrentUserAccessLevel();
      if (accessLevel == null) {
        return false;
      }
      
      // Admin can do everything
      if (accessLevel == 'admin') {
        return true;
      }
      
      // Check specific role
      return accessLevel == requiredRole;
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error checking role: $e');
      return false;
    }
  }

  /// Logout current user
  static Future<void> logout() async {
    try {
      debugPrint('AUTH_MANAGER: Starting logout process');
      
      final username = await getCurrentUsername();
      
      // Get current session token before clearing everything
      final currentSessionToken = await EnhancedUserTokenService.getCurrentSessionToken();
      
      // Invalidate ONLY the current session, not all user sessions
      if (currentSessionToken != null) {
        await EnhancedUserTokenService.invalidateSession(currentSessionToken);
        debugPrint('AUTH_MANAGER: Invalidated current session token');
      }
      
      // Clean up any stale sessions for this user
      if (username != null) {
        await EnhancedUserTokenService.cleanupUserSessions(username);
      }
      
      // Clear current session info from SharedPreferences
      await EnhancedUserTokenService.clearCurrentSessionInfo();
      
      // Clear local authentication state
      await _clearAuthenticationState();
      
      // Stop session monitoring
      stopSessionMonitoring();
      
      // Log logout activity
      if (username != null) {
        final db = DatabaseHelper();
        await db.logUserActivity(
          username,
          'User logged out - session cleared',
        );
      }
      
      debugPrint('AUTH_MANAGER: Logout completed successfully');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error during logout: $e');
      // Still clear local state even if other operations fail
      await _clearAuthenticationState();
      // Force clear session info as fallback
      try {
        await EnhancedUserTokenService.clearCurrentSessionInfo();
      } catch (clearError) {
        debugPrint('AUTH_MANAGER: Error clearing session info: $clearError');
      }
    }
  }

  /// Force logout from another device
  /// 
  /// [username] - Username to force logout
  static Future<void> forceLogoutUser(String username) async {
    try {
      debugPrint('AUTH_MANAGER: Force logout requested for user: $username');
      
      // Invalidate all sessions for the user
      await EnhancedUserTokenService.invalidateAllUserSessions(username);
      
      // Log the force logout activity
      final db = DatabaseHelper();
      await db.logUserActivity(
        username,
        'User force logged out from another device',
      );
      
      debugPrint('AUTH_MANAGER: Force logout completed for user: $username');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error during force logout: $e');
      rethrow;
    }
  }

  /// Handle session invalidation from another device
  static Future<void> handleSessionInvalidation() async {
    try {
      debugPrint('AUTH_MANAGER: Handling session invalidation from another device');
      
      final username = await getCurrentUsername();
      
      // Clear local authentication state
      await _clearAuthenticationState();
      
      // Stop session monitoring
      stopSessionMonitoring();
      
      // Show notification to user
      SessionNotificationService.showSessionInvalidatedNotification();
      
      // Navigate to login screen after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _navigateToLogin();
      });
      
      // Log the invalidation
      if (username != null) {
        final db = DatabaseHelper();
        await db.logUserActivity(
          username,
          'Session invalidated - logged out from another device',
        );
      }
      
      debugPrint('AUTH_MANAGER: Session invalidation handling completed');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error handling session invalidation: $e');
    }
  }

  /// Start monitoring session validity
  static void startSessionMonitoring() {
    if (_isMonitoring) {
      return; // Already monitoring
    }
    
    _isMonitoring = true;
    _sessionMonitorTimer = Timer.periodic(
      const Duration(minutes: 10), // Reduced frequency from 5 to 10 minutes to prevent overload
      (timer) async {
        try {
          if (!_isMonitoring) {
            timer.cancel();
            return;
          }
          final isValid = await EnhancedUserTokenService.isCurrentSessionValid();
          if (!isValid) {
            debugPrint('AUTH_MANAGER: Session validation failed during monitoring');
            await handleSessionInvalidation();
          }
        } catch (e) {
          debugPrint('AUTH_MANAGER: Error during session monitoring: $e');
          // Don't crash the app if session monitoring fails
        }
      },
    );
    
    debugPrint('AUTH_MANAGER: Session monitoring started (10 min intervals)');
  }

  /// Stop session monitoring
  static void stopSessionMonitoring() {
    _sessionMonitorTimer?.cancel();
    _sessionMonitorTimer = null;
    _isMonitoring = false;
    debugPrint('AUTH_MANAGER: Session monitoring stopped');
  }

  /// Clean up expired sessions
  static Future<void> cleanupExpiredSessions() async {
    try {
      await EnhancedUserTokenService.cleanupExpiredSessions();
      debugPrint('AUTH_MANAGER: Expired sessions cleaned up');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error cleaning up expired sessions: $e');
    }
  }

  /// Get session statistics for admin monitoring
  static Future<Map<String, dynamic>> getSessionStatistics() async {
    try {
      return await EnhancedUserTokenService.getSessionStatistics();
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error getting session statistics: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Check if another device is logged in for the user
  /// 
  /// [username] - Username to check
  static Future<bool> isUserLoggedInElsewhere(String username) async {
    try {
      final sessions = await EnhancedUserTokenService.getActiveUserSessions(
        username,
        excludeCurrentDevice: true,
      );
      return sessions.isNotEmpty;
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error checking if user logged in elsewhere: $e');
      return false;
    }
  }

  /// Save authentication state locally
  static Future<void> _saveAuthenticationState({
    required String username,
    required String accessLevel,
    required String sessionToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_accessLevelKey, accessLevel);
      await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
      
      debugPrint('AUTH_MANAGER: Authentication state saved');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error saving authentication state: $e');
      rethrow;
    }
  }

  /// Clear local authentication state
  static Future<void> _clearAuthenticationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_accessLevelKey);
      await prefs.remove(_lastActivityKey);
      
      debugPrint('AUTH_MANAGER: Authentication state cleared');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error clearing authentication state: $e');
    }
  }

  /// Update last activity timestamp
  static Future<void> _updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error updating last activity: $e');
    }
  }

  /// Navigate to login screen
  static void _navigateToLogin() {
    try {
      final context = SessionNotificationService.getCurrentContext();
      if (context != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error navigating to login: $e');
    }
  }

  /// Initialize authentication manager
  static Future<void> initialize() async {
    try {
      debugPrint('AUTH_MANAGER: Initializing authentication manager');
      
      // Clean up expired sessions on startup with timeout
      await cleanupExpiredSessions().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('AUTH_MANAGER: Session cleanup timed out, continuing...');
        },
      );
      
      // Check if user is logged in and start monitoring if needed
      final isUserLoggedIn = await isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('AUTH_MANAGER: Login check timed out, assuming not logged in');
          return false;
        },
      );
      
      if (isUserLoggedIn) {
        startSessionMonitoring();
      }
      
      debugPrint('AUTH_MANAGER: Authentication manager initialized');
    } catch (e) {
      debugPrint('AUTH_MANAGER: Error initializing authentication manager: $e');
      // Don't rethrow - allow app to continue even if auth init fails
    }
  }

  /// Dispose authentication manager
  static void dispose() {
    stopSessionMonitoring();
    debugPrint('AUTH_MANAGER: Authentication manager disposed');
  }
}
