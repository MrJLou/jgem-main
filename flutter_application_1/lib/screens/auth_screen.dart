import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/dashboard_screen_refactored.dart';
import '../services/authentication_manager.dart';
import '../services/enhanced_user_token_service.dart';
import '../widgets/login_rate_limiter.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;

  // Login form controllers
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _loginUsernameController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  bool _obscureLoginPassword = true;
  String? _loginErrorMessage;

  @override
  void initState() {
    super.initState();

    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimationController.forward();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    setState(() => _isLoading = true);
    try {
      final isLoggedIn = await AuthenticationManager.isLoggedIn();
      if (!mounted) return;

      if (isLoggedIn) {
        final accessLevel = await AuthenticationManager.getCurrentUserAccessLevel();
        if (!mounted) return;

        if (accessLevel != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                accessLevel: accessLevel,
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session check failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _loginErrorMessage = null;
    });

    if (_loginFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final username = _loginUsernameController.text;
        await LoginRateLimiter.canAttemptLogin(username);

        // Use enhanced session management login
        final response = await AuthenticationManager.login(
          username: username,
          password: _loginPasswordController.text,
          forceLogout: false,
        );

        if (!mounted) return;

        final userRole = response['user']?.role;

        if (userRole == null) {
          setState(() {
            _loginErrorMessage =
                'Login failed: User role not found in response.';
          });
          await LoginRateLimiter.recordFailedAttempt(username);
          return;
        }

        await LoginRateLimiter.recordSuccessfulLogin(username);
        // Note: Credentials are already saved by AuthenticationManager.login()
        // No need to call AuthService.saveLoginCredentials() as it conflicts with the new system

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(accessLevel: userRole),
          ),
          (route) => false,
        );
      } catch (e) {
        // Check for session conflict (user already logged in on another device)
        if (e is UserSessionConflictException || 
            e.toString().contains('UserSessionConflictException') ||
            e.toString().contains('already logged in on another device')) {
          // Show dialog asking if user wants to force logout other devices
          final shouldForceLogout = await _showForceLoginDialog();
          if (shouldForceLogout == true) {
            try {
              final response = await AuthenticationManager.login(
                username: _loginUsernameController.text,
                password: _loginPasswordController.text,
                forceLogout: true,
              );
              
              final userRole = response['user']?.role;
              if (userRole != null && mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardScreen(accessLevel: userRole),
                  ),
                  (route) => false,
                );
              }
            } catch (forceLoginError) {
              if (mounted) {
                setState(() {
                  _loginErrorMessage = 'Force login failed: ${forceLoginError.toString()}';
                });
              }
            }
          }
          return;
        }

        if (_loginUsernameController.text.isNotEmpty) {
          await LoginRateLimiter.recordFailedAttempt(
              _loginUsernameController.text);
        }
        if (!mounted) return;
        setState(() {
          _loginErrorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool?> _showForceLoginDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Account Already Active'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This account is already logged in on another device.'),
              SizedBox(height: 8),
              Text('Would you like to force logout the other device and continue?'),
              SizedBox(height: 8),
              Text(
                '⚠️ The other device will be automatically logged out.',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Force Login'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                children: [
                  // Side Navigation
                  Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 80),
                        // App Logo
                        Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal[400]!,
                                Colors.teal[700]!
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Sign In Button
                        _buildSideNavItem(
                          icon: Icons.login,
                          label: 'Sign In',
                          isSelected: true, // Always selected
                          onTap: () {}, // No action needed
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: _buildLoginPage(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoginPage() {
    return Row(
      children: [
        // Left side with Illustration
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'auth_illustration',
                  child: Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(35.0),
                        child: Image.asset(
                          'assets/images/slide1.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.local_hospital_outlined,
                            size: 100,
                            color: Colors.teal[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to access your patient records',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Right side with Login Form
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(60),
            child: Form(
              key: _loginFormKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_loginErrorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _loginErrorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  _buildTextField(
                    controller: _loginUsernameController,
                    label: 'Username',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: _loginPasswordController,
                    label: 'Password',
                    obscureText: _obscureLoginPassword,
                    toggleObscure: () {
                      setState(() {
                        _obscureLoginPassword = !_obscureLoginPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.teal[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal[50] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.teal[700] : Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.teal[700] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.teal[700]!),
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      onTap: onTap,
      readOnly: readOnly,
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock, color: Colors.teal[700]),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: Colors.teal[700],
          ),
          onPressed: toggleObscure,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.teal[700]!),
        ),
      ),
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: Colors.grey[800]),
    );
  }
}
