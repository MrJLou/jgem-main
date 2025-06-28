# Enhanced Token-Based Authentication System

This documentation explains how to implement and use the new token-based authentication system that prevents multiple concurrent logins for the same user account.

## Overview

The enhanced authentication system consists of three main components:

1. **EnhancedUserTokenService** - Core token management and session handling
2. **AuthenticationManager** - High-level authentication operations
3. **EnhancedLoginIntegration** - Integration helpers for UI components

## Key Features

- ✅ **Single Device Login**: Only one device can be logged in per user account
- ✅ **Secure Token Generation**: Cryptographically secure session tokens
- ✅ **Automatic Session Expiration**: Sessions expire after 8 hours by default
- ✅ **Force Logout Capability**: Users can force logout other devices
- ✅ **Real-time Session Monitoring**: Automatic session validation every 5 minutes
- ✅ **Session Conflict Detection**: Prevents concurrent logins automatically
- ✅ **Device Tracking**: Track which devices are logged in
- ✅ **Activity Logging**: Full audit trail of authentication events

## Quick Implementation Guide

### Step 1: Replace Your Login Logic

Replace your existing login method with the enhanced version:

```dart
// OLD LOGIN CODE (Remove this)
// final response = await AuthService.loginWithSessionManagement(username, password);

// NEW LOGIN CODE (Use this instead)
await EnhancedLoginIntegration.performLogin(
  context: context,
  username: _usernameController.text,
  password: _passwordController.text,
);
```

### Step 2: Update App Initialization

In your `main.dart`, replace the authentication check:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App',
      home: FutureBuilder<Widget>(
        future: EnhancedLoginIntegration.checkAuthenticationStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data ?? const LoginScreen();
        },
      ),
    );
  }
}
```

### Step 3: Update Logout Logic

Replace your logout implementation:

```dart
// OLD LOGOUT CODE (Remove this)
// await AuthService.logout();

// NEW LOGOUT CODE (Use this instead)
await EnhancedLoginIntegration.performLogout(context);
```

### Step 4: Update Authentication Checks

For checking if user is logged in:

```dart
// OLD CODE (Remove this)
// final isLoggedIn = await AuthService.isLoggedIn();

// NEW CODE (Use this instead)
final isLoggedIn = await AuthenticationManager.isLoggedIn();
```

For getting current user:

```dart
// OLD CODE (Remove this)
// final user = await AuthService.getCurrentUser();

// NEW CODE (Use this instead)
final user = await AuthenticationManager.getCurrentUser();
```

For role checking:

```dart
// OLD CODE (Remove this)
// final hasRole = await AuthService.hasRole('admin');

// NEW CODE (Use this instead)
final hasRole = await AuthenticationManager.hasRole('admin');
```

## Advanced Usage

### Manual Session Management

If you need more control over session management:

```dart
// Check if user has active sessions elsewhere
final hasOtherSessions = await AuthenticationManager.isUserLoggedInElsewhere(username);

// Force logout a specific user (admin function)
await AuthenticationManager.forceLogoutUser(username);

// Get session statistics (for monitoring)
final stats = await AuthenticationManager.getSessionStatistics();
print('Active sessions: ${stats['activeSessions']}');
print('Active users: ${stats['activeUsers']}');
```

### Extending Session Duration

To customize session duration, modify the `_defaultSessionDuration` in `EnhancedUserTokenService`:

```dart
static const Duration _defaultSessionDuration = Duration(hours: 8); // Change this
```

### Custom Session Monitoring

The system monitors sessions every 5 minutes by default. To change this:

```dart
// In AuthenticationManager.startSessionMonitoring()
_sessionMonitorTimer = Timer.periodic(
  const Duration(minutes: 5), // Change this interval
  (timer) async {
    // ... session validation logic
  },
);
```

## Database Changes

The enhanced system uses the existing `user_sessions` table with these key fields:

- `sessionToken` - Unique token for each session
- `username` - User identifier
- `deviceId` - Unique device identifier
- `isActive` - Whether session is active
- `expiresAt` - Session expiration timestamp
- `invalidated_at` - When session was invalidated

## Error Handling

The system throws specific exceptions for different scenarios:

### UserSessionConflictException

Thrown when a user tries to login but is already logged in elsewhere:

```dart
try {
  await AuthenticationManager.login(
    username: username,
    password: password,
  );
} on UserSessionConflictException catch (e) {
  // Show dialog asking if user wants to force logout other devices
  print('Active sessions: ${e.activeSessions.length}');
}
```

### Standard Exceptions

```dart
try {
  await AuthenticationManager.login(username: username, password: password);
} catch (e) {
  if (e.toString().contains('Invalid username or password')) {
    // Handle invalid credentials
  } else {
    // Handle other errors
  }
}
```

## Security Considerations

1. **Token Security**: Tokens are generated using cryptographically secure random generators
2. **Session Expiration**: All sessions automatically expire after the configured duration
3. **Device Tracking**: Each device gets a unique identifier for tracking
4. **Audit Trail**: All authentication events are logged for security monitoring
5. **Automatic Cleanup**: Expired sessions are automatically cleaned up

## Migration from Old System

To migrate from the old authentication system:

1. **Backup your database** before making changes
2. Replace all `AuthService` calls with `AuthenticationManager` calls
3. Update your login UI to use `EnhancedLoginIntegration`
4. Test the session conflict dialog flow
5. Verify session monitoring is working
6. Check that logout properly cleans up sessions

## Testing the System

### Test Session Conflicts

1. Login on Device A
2. Try to login with same account on Device B
3. Verify conflict dialog appears
4. Test force logout functionality
5. Verify Device A gets logged out automatically

### Test Session Expiration

1. Login and note the session expiry time
2. Manually modify the database to set an expired time
3. Verify user gets logged out automatically
4. Check that expired sessions are cleaned up

### Test Session Monitoring

1. Login successfully
2. Manually invalidate the session in database
3. Wait for monitoring cycle (5 minutes)
4. Verify user gets logged out automatically

## Troubleshooting

### Sessions Not Being Invalidated

Check that:
- Database has the correct `user_sessions` table structure
- `sessionToken` field is properly populated
- `isActive` and `expiresAt` fields are correctly set

### Session Conflicts Not Detected

Verify:
- `EnhancedUserTokenService.hasActiveSession()` is working
- Database queries are using correct table/field names
- Device IDs are being generated consistently

### Users Not Getting Logged Out

Ensure:
- Session monitoring is started (`AuthenticationManager.startSessionMonitoring()`)
- Timer intervals are appropriate for your use case
- Session validation logic is working correctly

## Performance Considerations

- Session monitoring runs every 5 minutes by default
- Database cleanup should be run periodically
- Consider indexing the `user_sessions` table for better performance:

```sql
CREATE INDEX IF NOT EXISTS idx_sessions_username ON user_sessions (username);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON user_sessions (isActive);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON user_sessions (expiresAt);
```

## Support

If you encounter issues with the enhanced authentication system:

1. Check the debug logs (search for `AUTH_MANAGER:` and `ENHANCED_TOKEN_SERVICE:`)
2. Verify database table structure matches expectations
3. Test each component individually
4. Ensure all imports are correct
5. Check that session monitoring is started properly

The enhanced authentication system provides robust security while maintaining a smooth user experience. Users will be clearly notified when session conflicts occur and can choose to force logout other devices if needed.
