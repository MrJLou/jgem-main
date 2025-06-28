import 'package:flutter/material.dart';
import '../services/enhanced_auth_integration.dart';

/// Example Login Screen using Enhanced Authentication Integration
/// 
/// This demonstrates how to migrate your existing login screen to use
/// the new enhanced authentication system.
class EnhancedLoginScreen extends StatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  State<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends State<EnhancedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handle login with the enhanced authentication system
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the enhanced login integration for automatic session conflict handling
      await EnhancedLoginIntegration.performLogin(
        context: context,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        onSuccess: () {
          // Login successful - navigate to dashboard
          Navigator.of(context).pushReplacementNamed('/dashboard');
        },
        onError: (error) {
          // Show error message
          setState(() {
            _errorMessage = error;
          });
        },
        // Optional: Custom session conflict handling
        onSessionConflict: (activeSessions) {
          _showCustomSessionConflictDialog(activeSessions);
        },
      );

      // If using manual login instead of EnhancedLoginIntegration:
      /*
      final result = await EnhancedAuthIntegration.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        forceLogout: false,
      );

      if (result['success'] == true) {
        // Login successful
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else if (result['error'] == 'session_conflict') {
        // Handle session conflict
        await _handleSessionConflict(result['activeSessions']);
      } else {
        // Show error
        setState(() {
          _errorMessage = result['message'] ?? 'Login failed';
        });
      }
      */

    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Custom session conflict dialog (optional)
  Future<void> _showCustomSessionConflictDialog(List<Map<String, dynamic>> activeSessions) async {
    final shouldForceLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Multiple Sessions Detected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You are currently logged in on:'),
              const SizedBox(height: 12),
              ...activeSessions.map((session) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['deviceName'] ?? 'Unknown Device',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Login: ${session['loginTime'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              const Text(
                'Continuing will log you out from all other devices. Do you want to proceed?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Force Login'),
            ),
          ],
        );
      },
    );

    if (shouldForceLogin == true) {
      // Retry login with force logout
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await EnhancedAuthIntegration.login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          forceLogout: true,
        );

        if (result['success'] == true) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/dashboard');
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = result['message'] ?? 'Force login failed';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Force login failed: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Navigate to forgot password screen
  void _navigateToForgotPassword() {
    Navigator.of(context).pushNamed('/forgot-password');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or title
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 32),

                // Username field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 8),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _navigateToForgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 16),

                // Error message
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 32),

                // Admin info panel (for testing)
                if (Theme.of(context).brightness == Brightness.light)
                  _buildAdminInfoPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Admin info panel for debugging (remove in production)
  Widget _buildAdminInfoPanel() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enhanced Authentication Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Single device login enforcement'),
            const Text('• Automatic session conflict detection'),
            const Text('• Force logout from other devices'),
            const Text('• Forgot password with security questions'),
            const Text('• Secure session management'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final stats = await EnhancedAuthIntegration.getSessionStatistics();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Active Sessions: ${stats['activeSessions']}')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Session Stats'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await EnhancedAuthIntegration.cleanupExpiredSessions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expired sessions cleaned up')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Cleanup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
