import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/lan_session_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import '../models/user.dart'; // Import the User model

class AuthService {
  static const bool isDevMode = false; // Set to false for production
  static const _authTokenKey = 'auth_token';
  static const _tokenExpiryKey = 'token_expiry';
  static const _usernameKey = 'username';
  static const _accessLevelKey = 'access_level';
  static const _deviceIdKey = 'device_id';
  static const _isLoggedInKey = 'is_logged_in'; // Key for logged in state
  // --- Additions for debounce ----
  static String? _lastLoggedInUser;
  static DateTime? _lastLoginLogTime;
  static const Duration _loginLogDebounceDuration = Duration(seconds: 5);
  // --- End additions ----

  // Current user role for authorization
  static String? _currentUserRole;

  // Token expiration duration (in minutes)
  static const int _tokenValidityMinutes = 60; // 1 hour

  // Use secure storage for sensitive information
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Hash passwords using BCrypt with cost factor of 12
  static String hashPassword(String password) {
    // Generate a salt and hash the password
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
  }

  // Hash security answer - similar to password for added protection
  static String hashSecurityAnswer(String answer) {
    // Lower security requirements for security answers (cost factor 8)
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
      // Handle invalid hash format or other bcrypt errors
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
      // Generate a new device ID based on timestamp and random values
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = DateTime.now().microsecond.toString();
      final bytes = utf8.encode(timestamp + random);
      final digest = sha256.convert(bytes);
      deviceId = digest.toString().substring(0, 16);

      // Store the device ID
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    }

    return deviceId;
  }

  // Completely clear all credentials on logout
  static Future<void> logout() async {
    try {
      // Get username before clearing credentials
      final username = await _secureStorage.read(key: _usernameKey);

      // Clear secure storage data
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      await _secureStorage.delete(key: _usernameKey);
      await _secureStorage.delete(key: _accessLevelKey);

      // Also clear shared preferences data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(
          _accessLevelKey); // Make sure to explicitly set the logged in state to false
      await prefs.setBool(_isLoggedInKey, false);

      // Clear current user role
      _currentUserRole = null;

      // Log the logout activity if we have the username
      if (username != null) {
        final db = DatabaseHelper();
        await db.logUserActivity(
          username,
          'User logged out',
        );

        // Notify LAN session service about logout
        try {
          await _notifySessionLogout(username);
        } catch (e) {
          debugPrint('Failed to notify session service of logout: $e');
        }
      }

      if (kDebugMode) {
        print('Logout completed successfully - all credentials cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
      rethrow; // Propagate the error for handling in UI
    }
  }

  /// Force logout this device due to session invalidation from another device
  static Future<void> forceLogoutDueToSessionInvalidation() async {
    try {
      final username = await _secureStorage.read(key: _usernameKey);

      // Clear all credentials without notifying session service (since it was initiated by session service)
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      await _secureStorage.delete(key: _usernameKey);
      await _secureStorage.delete(key: _accessLevelKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_accessLevelKey);
      await prefs.setBool(_isLoggedInKey, false);

      _currentUserRole = null;

      if (username != null) {
        final db = DatabaseHelper();
        await db.logUserActivity(
          username,
          'Session invalidated - logged out from another device',
        );
      }

      debugPrint('Force logout completed due to session invalidation');
    } catch (e) {
      debugPrint('Error during force logout: $e');
    }
  }

  // Get saved credentials from secure storage
  static Future<Map<String, String>?> getSavedCredentials() async {
    if (isDevMode) {
      return {
        'token': 'dev_token',
        'username': 'developer',
        'accessLevel': 'admin',
      };
    }

    // First check if the user is logged in
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!loggedIn) {
      return null; // Return null if not logged in, regardless of token presence
    }

    // Production implementation using secure storage
    final token = await _secureStorage.read(key: _authTokenKey);
    final expiryTimeStr = await _secureStorage.read(key: _tokenExpiryKey);
    final username = await _secureStorage.read(key: _usernameKey);
    final accessLevel = await _secureStorage.read(key: _accessLevelKey);

    // Check if token has expired
    if (token != null && expiryTimeStr != null) {
      final expiryTime = int.parse(expiryTimeStr);
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (currentTime > expiryTime) {
        // Token has expired, clear it
        await clearCredentials();
        return null;
      }
    }

    if (token != null && username != null && accessLevel != null) {
      return {
        'token': token,
        'username': username,
        'accessLevel': accessLevel,
      };
    }
    return null;
  }

  // Save login credentials securely
  static Future<void> saveLoginCredentials({
    required String token,
    required String username,
    required String accessLevel,
  }) async {
    if (isDevMode) return; // Skip saving in dev mode

    // Calculate token expiry time
    final expiryTime = DateTime.now()
        .add(const Duration(minutes: _tokenValidityMinutes))
        .millisecondsSinceEpoch
        .toString();

    await _secureStorage.write(key: _authTokenKey, value: token);
    await _secureStorage.write(key: _tokenExpiryKey, value: expiryTime);
    await _secureStorage.write(key: _usernameKey, value: username);
    await _secureStorage.write(key: _accessLevelKey, value: accessLevel);

    // Also store non-sensitive login status in regular preferences for quick checks
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);

    // Log login activity with debounce
    final now = DateTime.now();
    if (_lastLoggedInUser != username ||
        _lastLoginLogTime == null ||
        now.difference(_lastLoginLogTime!) > _loginLogDebounceDuration) {
      final db = DatabaseHelper();
      await db.logUserActivity(username, 'User logged in');
      _lastLoggedInUser = username;
      _lastLoginLogTime = now;
    }
  }

  // Clear saved credentials
  static Future<void> clearCredentials() async {
    if (isDevMode) return; // Skip clearing in dev mode

    await _secureStorage.delete(key: _authTokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _accessLevelKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);

    // Clear current user role
    _currentUserRole = null;
  }

  // Check if user is logged in and token is valid
  static Future<bool> isLoggedIn() async {
    if (isDevMode) return true; // Always return true in dev mode

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) {
      return false; // Short circuit if explicitly logged out
    }

    if (isLoggedIn) {
      // Double-check with secure storage and validate token expiry
      final token = await _secureStorage.read(key: _authTokenKey);
      final expiryTimeStr = await _secureStorage.read(key: _tokenExpiryKey);

      if (token != null && expiryTimeStr != null) {
        final expiryTime = int.parse(expiryTimeStr);
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        if (currentTime < expiryTime) {
          return true; // Token is valid
        } else {
          // Token has expired, clean up
          await clearCredentials();
        }
      } else {
        // Missing token or expiry, ensure logged out state is consistent
        await clearCredentials();
      }
    }
    return false;
  }

  // Refresh token to extend session
  static Future<bool> refreshToken() async {
    if (isDevMode) return true;

    final credentials = await getSavedCredentials();
    if (credentials == null) return false;

    // Calculate new expiry time
    final newExpiryTime = DateTime.now()
        .add(const Duration(minutes: _tokenValidityMinutes))
        .millisecondsSinceEpoch
        .toString();

    await _secureStorage.write(key: _tokenExpiryKey, value: newExpiryTime);
    return true;
  }

  // Verify if current user has specific role
  static Future<bool> hasRole(String requiredRole) async {
    final credentials = await getSavedCredentials();
    if (credentials == null) return false;

    final userRole = credentials['accessLevel'];

    // Admin can do everything
    if (userRole == 'admin') return true;

    // Role-specific permissions hierarchy
    switch (requiredRole) {
      case 'doctor':
        return userRole == 'doctor';
      case 'medtech':
        return userRole == 'medtech';
      default:
        return userRole == requiredRole;
    }
  }

  // Get remaining token validity time in seconds
  static Future<int> getTokenRemainingTime() async {
    if (isDevMode) return _tokenValidityMinutes * 60;

    final expiryTimeStr = await _secureStorage.read(key: _tokenExpiryKey);
    if (expiryTimeStr == null) return 0;

    final expiryTime = int.parse(expiryTimeStr);
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final remainingMillis = expiryTime - currentTime;

    return remainingMillis > 0 ? (remainingMillis ~/ 1000) : 0;
  }

  // Get current logged-in username
  static Future<String?> getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    if (!loggedIn) return null;
    return await _secureStorage.read(key: _usernameKey);
  }

  // Method to get the current logged-in user's details from DB
  static Future<User?> getCurrentUser() async {
    final savedCreds = await getSavedCredentials();
    if (savedCreds != null && savedCreds['username'] != null) {
      final db = DatabaseHelper();
      try {
        return await db.getUserByUsername(savedCreds['username']!);
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching current user from DB: $e');
        }
        return null;
      }
    }
    return null;
  }

  // Method to get the current logged-in user's ID
  static Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?.id;
  }

  // Method to get the current user's access level
  static Future<String?> getCurrentUserAccessLevel() async {
    final savedCreds = await getSavedCredentials();
    if (savedCreds != null && savedCreds['accessLevel'] != null) {
      return savedCreds['accessLevel'];
    }
    return null;
  }

  // Get current user role (cached)
  static String? getCurrentUserRole() {
    return _currentUserRole;
  }

  // Clear current user role
  static void clearCurrentUserRole() {
    _currentUserRole = null;
  }

  // Enhanced login with session management
  static Future<Map<String, dynamic>> loginWithSessionManagement(
      String username, String password,
      {bool forceLogoutExisting = false}) async {
    try {
      // Check if user is already logged in elsewhere
      if (LanSessionService.isUserLoggedIn(username) && !forceLogoutExisting) {
        throw Exception(
            'User is already logged in on another device. Please logout from the other device first.');
      }

      // Proceed with normal authentication
      final auth = await DatabaseHelper().authenticateUser(username, password);
      if (auth != null && auth['user'] != null && auth['user'].role != null) {
        _currentUserRole = auth['user'].role;

        // Save to SharedPreferences
        await saveLoginCredentials(
          token: auth['token'],
          username: username,
          accessLevel: auth['user'].role,
        );

        // Register session if session service is running
        debugPrint(
            'AuthService: Checking if session service is running: ${LanSessionService.isServerRunning}');
        if (LanSessionService.isServerRunning) {
          try {
            final deviceId = await getDeviceId();
            final deviceName = await _getDeviceName();

            debugPrint(
                'AuthService: Registering session for $username on $deviceName (Device: $deviceId)');
            await LanSessionService.registerUserSession(
              username: username,
              deviceId: deviceId,
              deviceName: deviceName,
              accessLevel: auth['user'].role,
              forceLogoutExisting: forceLogoutExisting,
            );
            debugPrint('AuthService: Session registered successfully');
          } catch (e) {
            debugPrint('Failed to register session: $e');
            // Don't fail login if session registration fails
          }
        } else {
          debugPrint(
              'AuthService: Session service not running, skipping session registration');
        }

        return auth;
      } else {
        throw Exception('Invalid credentials or user data missing');
      }
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  /// Method to check if current session is still valid (called by real-time sync)
  static Future<bool> validateCurrentSession() async {
    try {
      if (!await isLoggedIn()) {
        return false;
      }

      final username = await getCurrentUsername();
      final deviceId = await getDeviceId();

      if (username == null) return false;

      // Check if our session is still valid in the session service
      if (LanSessionService.isServerRunning) {
        final session = LanSessionService.getSessionByDevice(deviceId);
        if (session == null || session.username != username) {
          // Our session is no longer valid, force logout
          await forceLogoutDueToSessionInvalidation();
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error validating session: $e');
      return false;
    }
  }

  // Get device name
  static Future<String> _getDeviceName() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('hostname', []);
        return result.stdout.toString().trim();
      } else if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('hostname', []);
        return result.stdout.toString().trim();
      }
    } catch (e) {
      debugPrint('Failed to get device name: $e');
    }
    return 'Unknown Device';
  }

  // Helper method to notify session service of logout
  static Future<void> _notifySessionLogout(String username) async {
    try {
      // Get current device ID
      final deviceId = await getDeviceId();

      // End the session for this user/device
      if (_getActiveSessionsStatic != null && _endSessionStatic != null) {
        final activeSessions = _getActiveSessionsStatic!();
        for (final session in activeSessions.values) {
          if (session.username == username && session.deviceId == deviceId) {
            await _endSessionStatic!(session.sessionId);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error notifying session logout: $e');
    }
  }

  // Static references to session service (to avoid circular imports)
  static Map<String, dynamic> Function()? _getActiveSessionsStatic;
  static Future<void> Function(String sessionId)? _endSessionStatic;

  // Method to register session service callbacks
  static void registerSessionCallbacks({
    required Map<String, dynamic> Function() getActiveSessions,
    required Future<void> Function(String sessionId) endSession,
  }) {
    _getActiveSessionsStatic = getActiveSessions;
    _endSessionStatic = endSession;
    debugPrint('Session callbacks registered with AuthService');
  }
}
