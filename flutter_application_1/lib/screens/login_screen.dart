import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/login_rate_limiter.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 0; // 0 for Sign In, 1 for Sign Up

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  Future<void> _checkExistingSession() async {
    setState(() => _isLoading = true);
    try {
      final isLoggedIn = await AuthService.isLoggedIn();

      if (isLoggedIn && mounted) {
        final credentials = await AuthService.getSavedCredentials();
        if (credentials != null) {
          // Only navigate to dashboard if actually logged in
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  accessLevel: credentials['accessLevel'] ?? 'user',
                ),
              ),
              (route) =>
                  false, // This removes all previous routes from the stack
            );
          }
        }
      }
    } catch (e) {
      // Handle any errors during session check
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final username = _usernameController.text;

        // Check rate limiting before attempting login
        await LoginRateLimiter.canAttemptLogin(username);

        final response =
            await ApiService.login(username, _passwordController.text);

        // Validate that the user has a role (access level) from the response
        final userRole = response['user']?['role'];
        if (userRole == null) {
          setState(() {
            _errorMessage = 'Login failed: User role not found in response.';
          });
          await LoginRateLimiter.recordFailedAttempt(username);
          return;
        }

        // Record successful login for rate limiting
        await LoginRateLimiter.recordSuccessfulLogin(username);

        // Save credentials after successful login
        await AuthService.saveLoginCredentials(
          token: response['token'],
          username: username,
          accessLevel: userRole,
        );

        // Navigate to dashboard and remove all previous routes
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                accessLevel: userRole,
              ),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        // Record failed attempt for rate limiting if username was provided
        if (_usernameController.text.isNotEmpty) {
          await LoginRateLimiter.recordFailedAttempt(_usernameController.text);
        }

        setState(() {
          _errorMessage = e.toString();
          if (e.toString().contains('Too many attempts')) {
            _errorMessage =
                'Login failed: Too many attempts. Please try again later.';
          } else if (e.toString().contains('Invalid credentials') ||
              e.toString().contains('User not found')) {
            _errorMessage = 'Login failed: Invalid username or password.';
          } else {
            _errorMessage =
                'Login failed: An unexpected error occurred. ${e.toString()}';
          }
        });
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Side Navigation
                Container(
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
                          color: Colors.teal[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Sign In Button
                      _buildSideNavItem(
                        icon: Icons.login,
                        label: 'Sign In',
                        isSelected: _selectedIndex == 0,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 0;
                          });
                        },
                      ),

                      // Sign Up Button
                      _buildSideNavItem(
                        icon: Icons.person_add,
                        label: 'Sign Up',
                        isSelected: _selectedIndex == 1,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignUpScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Row(
                    children: [
                      // Left side with Illustration
                      Expanded(
                        flex: 5,
                        child: Container(
                          color: Colors.teal[700],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: const Text(
                                  "J-Gem Medical and Diagnostic Clinic",
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: Text(
                                  "Manage patient records securely.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 60),
                              // Here we would add an illustration like in the image
                              // Using a placeholder in this case
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  height: 250,
                                  width: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.medical_services_outlined,
                                    size: 120,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right side with Login Form
                      Expanded(
                        flex: 5,
                        child: Container(
                          color: Colors.white,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 50.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 80),

                                    // Don't have an account text
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Text("Don't have an account?"),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const SignUpScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 40),

                                    // Sign In Title
                                    const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 40),

                                    // Display error message if there is one
                                    if (_errorMessage != null)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.red[300]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: Colors.red[700]),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: TextStyle(
                                                    color: Colors.red[700]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Username Field
                                    _buildTextField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    const SizedBox(height: 24),

                                    // Password field
                                    const Text(
                                      "Password",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        hintText: '••••••••••••••',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                      enabled: !_isLoading,
                                    ),
                                    const SizedBox(height: 24),

                                    // Login button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.teal[700],
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed:
                                            _isLoading ? null : _handleLogin,
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                'SIGN IN',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Terms text
                                    Center(
                                      child: Text(
                                        'By clicking Sign In, you agree to our Terms of Service and Privacy Policy.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Forgot password link
                                    Center(
                                      child: TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ForgotPasswordScreen(),
                                                  ),
                                                );
                                              },
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                              color: theme.primaryColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSideNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: Colors.teal[700]!,
                        width: 4,
                      ),
                    )
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.teal[700] : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.teal[700] : Colors.grey[600],
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Enter your $label',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
      enabled: !_isLoading,
    );
  }
}
