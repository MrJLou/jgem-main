import 'package:shared_preferences/shared_preferences.dart';

class LoginRateLimiter {
  static const String _failedAttemptsKey = 'failed_login_attempts';
  static const String _lastAttemptTimeKey = 'last_login_attempt_time';
  static const int _maxAttempts = 5;
  static const int _lockoutDurationMinutes = 15;

  // Check if login attempts are allowed
  static Future<bool> canAttemptLogin(String username) async {
    final prefs = await SharedPreferences.getInstance();

    // Get username-specific keys
    final String userAttemptsKey = '${_failedAttemptsKey}_$username';
    final String userTimeKey = '${_lastAttemptTimeKey}_$username';

    final int failedAttempts = prefs.getInt(userAttemptsKey) ?? 0;
    final int lastAttemptTime = prefs.getInt(userTimeKey) ?? 0;
    final int currentTime = DateTime.now().millisecondsSinceEpoch;

    // Check if the user is in lockout period
    if (failedAttempts >= _maxAttempts) {
      final int lockoutTime =
          lastAttemptTime + (_lockoutDurationMinutes * 60 * 1000);

      if (currentTime < lockoutTime) {
        // Still in lockout period
        final int remainingSeconds = (lockoutTime - currentTime) ~/ 1000;
        throw Exception(
            'Too many failed attempts. Try again in ${_formatLockoutTime(remainingSeconds)}');
      } else {
        // Lockout period expired, reset counters
        await _resetFailedAttempts(username);
        return true;
      }
    }

    return true;
  }

  // Record a failed login attempt
  static Future<void> recordFailedAttempt(String username) async {
    final prefs = await SharedPreferences.getInstance();

    final String userAttemptsKey = '${_failedAttemptsKey}_$username';
    final String userTimeKey = '${_lastAttemptTimeKey}_$username';

    final int failedAttempts = (prefs.getInt(userAttemptsKey) ?? 0) + 1;
    final int currentTime = DateTime.now().millisecondsSinceEpoch;

    await prefs.setInt(userAttemptsKey, failedAttempts);
    await prefs.setInt(userTimeKey, currentTime);
  }

  // Record a successful login
  static Future<void> recordSuccessfulLogin(String username) async {
    await _resetFailedAttempts(username);
  }

  // Reset failed attempts counter
  static Future<void> _resetFailedAttempts(String username) async {
    final prefs = await SharedPreferences.getInstance();

    final String userAttemptsKey = '${_failedAttemptsKey}_$username';
    await prefs.remove(userAttemptsKey);
  }

  // Format the lockout time for user-friendly display
  static String _formatLockoutTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return '$minutes minute${minutes > 1 ? 's' : ''} and $remainingSeconds second${remainingSeconds != 1 ? 's' : ''}';
    } else {
      return '$seconds second${seconds != 1 ? 's' : ''}';
    }
  }
}
