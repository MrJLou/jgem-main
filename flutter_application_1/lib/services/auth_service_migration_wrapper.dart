import 'package:flutter/material.dart';
import '../services/authentication_manager.dart';
import '../services/enhanced_user_token_service.dart';
import '../screens/login_screen.dart';

/// Migration helper to gradually replace AuthService calls with AuthenticationManager
/// 
/// This wrapper provides backward compatibility while migrating to the new system.
/// You can replace AuthService calls one by one without breaking existing functionality.
class AuthServiceMigrationWrapper {
  
  /// Wrapper for login that uses the new enhanced system
  static Future<Map<String, dynamic>> loginWithSessionManagement(
    String username, 
    String password, {
    bool forceLogoutExisting = false,
  }) async {
    try {
      return await AuthenticationManager.login(
        username: username,
        password: password,
        forceLogout: forceLogoutExisting,
      );
    } on UserSessionConflictException {
      // Convert to the old exception format for backward compatibility
      throw Exception('SessionConflictException: User is already logged in on another device');
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  /// Wrapper for isLoggedIn
  static Future<bool> isLoggedIn() async {
    return await AuthenticationManager.isLoggedIn();
  }

  /// Wrapper for getCurrentUsername
  static Future<String?> getCurrentUsername() async {
    return await AuthenticationManager.getCurrentUsername();
  }

  /// Wrapper for getCurrentUser
  static Future<dynamic> getCurrentUser() async {
    return await AuthenticationManager.getCurrentUser();
  }

  /// Wrapper for getCurrentUserAccessLevel
  static Future<String?> getCurrentUserAccessLevel() async {
    return await AuthenticationManager.getCurrentUserAccessLevel();
  }

  /// Wrapper for hasRole
  static Future<bool> hasRole(String requiredRole) async {
    return await AuthenticationManager.hasRole(requiredRole);
  }

  /// Wrapper for logout
  static Future<void> logout() async {
    await AuthenticationManager.logout();
  }

  /// Check if user has active session (new functionality)
  static Future<bool> hasActiveSession(String username) async {
    return await AuthenticationManager.isUserLoggedInElsewhere(username);
  }

  /// Force logout user (new functionality)
  static Future<void> forceLogoutUser(String username) async {
    await AuthenticationManager.forceLogoutUser(username);
  }

  /// Get session statistics (new functionality)
  static Future<Map<String, dynamic>> getSessionStatistics() async {
    return await AuthenticationManager.getSessionStatistics();
  }

  /// Initialize the authentication system (call this in main.dart)
  static Future<void> initialize() async {
    await AuthenticationManager.initialize();
  }

  /// Handle session invalidation from another device
  static Future<void> handleSessionInvalidationFromOtherDevice(Map<String, dynamic> data) async {
    await AuthenticationManager.handleSessionInvalidation();
  }

  /// Navigate to login screen (helper method)
  static void navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}

/// Step-by-step migration guide for replacing AuthService
/// 
/// Follow these steps to migrate your existing code:

/* 
STEP 1: Initialize the new system in main.dart
----------------------------------------
In your main.dart file, add this to the beginning of your main() function:

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the enhanced authentication system
  await AuthServiceMigrationWrapper.initialize();
  
  runApp(MyApp());
}

STEP 2: Replace login calls
---------------------------
OLD CODE:
final response = await AuthService.loginWithSessionManagement(username, password);

NEW CODE:
final response = await AuthServiceMigrationWrapper.loginWithSessionManagement(
  username, 
  password,
  forceLogoutExisting: false,
);

STEP 3: Replace authentication checks
-------------------------------------
OLD CODE:
final isLoggedIn = await AuthService.isLoggedIn();

NEW CODE:
final isLoggedIn = await AuthServiceMigrationWrapper.isLoggedIn();

STEP 4: Replace user info calls
-------------------------------
OLD CODE:
final username = await AuthService.getCurrentUsername();
final user = await AuthService.getCurrentUser();
final accessLevel = await AuthService.getCurrentUserAccessLevel();

NEW CODE:
final username = await AuthServiceMigrationWrapper.getCurrentUsername();
final user = await AuthServiceMigrationWrapper.getCurrentUser();
final accessLevel = await AuthServiceMigrationWrapper.getCurrentUserAccessLevel();

STEP 5: Replace logout calls
----------------------------
OLD CODE:
await AuthService.logout();

NEW CODE:
await AuthServiceMigrationWrapper.logout();

STEP 6: Replace role checking
-----------------------------
OLD CODE:
final hasRole = await AuthService.hasRole('admin');

NEW CODE:
final hasRole = await AuthServiceMigrationWrapper.hasRole('admin');

STEP 7: Handle session conflicts in login screen
------------------------------------------------
In your login screen, replace the try-catch block:

OLD CODE:
try {
  final response = await AuthService.loginWithSessionManagement(username, password);
  // Handle success
} catch (e) {
  if (e.toString().contains('SessionConflictException')) {
    await _handleSessionConflict(username, password);
    return;
  }
  // Handle other errors
}

NEW CODE:
try {
  final response = await AuthServiceMigrationWrapper.loginWithSessionManagement(username, password);
  // Handle success
} catch (e) {
  if (e.toString().contains('SessionConflictException')) {
    // Show force login dialog
    final shouldForceLogin = await _showForceLoginDialog(context);
    if (shouldForceLogin) {
      final response = await AuthServiceMigrationWrapper.loginWithSessionManagement(
        username, 
        password,
        forceLogoutExisting: true,
      );
      // Handle success
    }
    return;
  }
  // Handle other errors
}

STEP 8: Update session invalidation handling
--------------------------------------------
OLD CODE:
AuthService.handleSessionInvalidationFromOtherDevice(data);

NEW CODE:
AuthServiceMigrationWrapper.handleSessionInvalidationFromOtherDevice(data);

STEP 9: Add new features (optional)
-----------------------------------
You can now use new features that weren't available before:

// Check if user is logged in elsewhere
final hasOtherSessions = await AuthServiceMigrationWrapper.hasActiveSession(username);

// Force logout a specific user (admin function)
await AuthServiceMigrationWrapper.forceLogoutUser(username);

// Get session statistics
final stats = await AuthServiceMigrationWrapper.getSessionStatistics();

STEP 10: Test the migration
---------------------------
1. Test normal login/logout flow
2. Test session conflict scenarios
3. Test session expiration
4. Test force logout functionality
5. Verify all existing features still work

STEP 11: Gradual transition to direct AuthenticationManager calls
----------------------------------------------------------------
Once you've verified everything works with the wrapper, you can gradually
replace AuthServiceMigrationWrapper calls with direct AuthenticationManager calls:

AuthServiceMigrationWrapper.isLoggedIn() → AuthenticationManager.isLoggedIn()
AuthServiceMigrationWrapper.getCurrentUser() → AuthenticationManager.getCurrentUser()
etc.

STEP 12: Use EnhancedLoginIntegration for new UI components
----------------------------------------------------------
For new login screens or components, use EnhancedLoginIntegration directly:

await EnhancedLoginIntegration.performLogin(
  context: context,
  username: username,
  password: password,
);
*/
