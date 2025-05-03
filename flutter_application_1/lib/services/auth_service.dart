import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const bool isDevMode = true; // Set to false for production
  static const _authTokenKey = 'auth_token';
  static const _usernameKey = 'username';
  static const _accessLevelKey = 'access_level';

  // For development only - bypass authentication
  static Future<Map<String, String>?> getSavedCredentials() async {
    if (isDevMode) {
      return {
        'token': 'dev_token',
        'username': 'developer',
        'accessLevel': 'admin', // Change to 'doctor' or 'medtech' as needed
      };
    }

    // Production implementation
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    final username = prefs.getString(_usernameKey);
    final accessLevel = prefs.getString(_accessLevelKey);

    if (token != null && username != null && accessLevel != null) {
      return {
        'token': token,
        'username': username,
        'accessLevel': accessLevel,
      };
    }
    return null;
  }

  static Future<void> saveLoginCredentials({
    required String token,
    required String username,
    required String accessLevel,
  }) async {
    if (isDevMode) return; // Skip saving in dev mode
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_accessLevelKey, accessLevel);
  }

  static Future<void> clearCredentials() async {
    if (isDevMode) return; // Skip clearing in dev mode
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_accessLevelKey);
  }

  static Future<bool> isLoggedIn() async {
    if (isDevMode) return true; // Always return true in dev mode
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey) != null;
  }
}

// If production mode
/* import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _authTokenKey = 'auth_token';
  static const _usernameKey = 'username';
  static const _accessLevelKey = 'access_level';

  static Future<void> saveLoginCredentials({
    required String token,
    required String username,
    required String accessLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_accessLevelKey, accessLevel);
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    final username = prefs.getString(_usernameKey);
    final accessLevel = prefs.getString(_accessLevelKey);

    if (token != null && username != null && accessLevel != null) {
      return {
        'token': token,
        'username': username,
        'accessLevel': accessLevel,
      };
    }
    return null;
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_accessLevelKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey) != null;
  }
} */
