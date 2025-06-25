import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/dashboard_screen_refactored.dart';
import 'dart:math' as math; // Added for rotation
// import 'dart:async'; // REMOVED for Timer
import 'dart:ui' show lerpDouble; // Added for snap-back animation
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // State for interactive image rotation
  double _interactiveRotationAngle =
      0.0; // Renamed from _rotationAngle and initialized
  double _interactiveRotationAngleStartSnap = 0.0; // For snap-back logic
  AnimationController? _imageRotationController; // Make nullable
  // late Animation<double> _imageRotationAnimation; // REMOVED - replaced by direct controller listener

  // New animations for floating logo and continuous rotation
  late AnimationController _logoFloatController;
  late Animation<double> _logoFloatAnimation;
  late AnimationController _continuousRotationController;
  late Animation<double> _continuousRotationAnimation;

  // Login attempt tracking
  final Map<String, int> _loginAttempts = {};
  final int _maxLoginAttempts = 3;

  @override
  void initState() {
    super.initState();

    // Initialize controllers first
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _imageRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _interactiveRotationAngle = lerpDouble(
                _interactiveRotationAngleStartSnap,
                0.0,
                _imageRotationController!.value)!;
          });
        }
      });
    _logoFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _continuousRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Slower rotation
    );

    // Then initialize animations that depend on these controllers
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _logoFloatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _logoFloatController, curve: Curves.easeInOut),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _continuousRotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_continuousRotationController)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    // Now call methods that might trigger rebuilds or use controllers
    _checkExistingSession();

    // Finally, start animations
    _animationController.forward();
    _logoFloatController.repeat(reverse: true);
    _continuousRotationController.repeat();
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
    _imageRotationController?.dispose(); // Use ?. for nullable controller
    _logoFloatController.dispose(); // Dispose new controller
    _continuousRotationController.dispose(); // Dispose new controller
    // _pageController?.dispose(); // REMOVED Dispose PageController
    // _timer?.cancel(); // REMOVED Cancel Timer
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final username = _usernameController.text; // Store username locally

      try {
        // final username = _usernameController.text; // Already defined above        // Check rate limiting before attempting login
        // await LoginRateLimiter.canAttemptLogin(username); // COMMENTED OUT

        // Use enhanced session management login
        final response = await AuthService.loginWithSessionManagement(
            username, _passwordController.text);

        // Validate that the user has a role (access level) from the response
        final userRole = response['user']?.role;
        if (userRole == null) {
          setState(() {
            _errorMessage = 'Login failed: User role not found in response.';
          });
          _recordFailedLoginAttempt(username); // Record failed attempt
          // await LoginRateLimiter.recordFailedAttempt(username); // COMMENTED OUT
          return;
        }

        // Record successful login for rate limiting
        // await LoginRateLimiter.recordSuccessfulLogin(username); // COMMENTED OUT

        // Reset login attempts for this user on successful login
        _loginAttempts.remove(username);

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
        // if (_usernameController.text.isNotEmpty) { // COMMENTED OUT
        //   await LoginRateLimiter.recordFailedAttempt(_usernameController.text); // COMMENTED OUT
        // }
        _recordFailedLoginAttempt(username); // Record failed attempt

        setState(() {
          _errorMessage = e.toString();
          // if (e.toString().contains('Too many attempts')) { // COMMENTED OUT
          //   _errorMessage = // COMMENTED OUT
          //       'Login failed: Too many attempts. Please try again later.'; // COMMENTED OUT
          // } else
          if (e.toString().contains('Invalid credentials') ||
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

  void _recordFailedLoginAttempt(String username) {
    if (username.isEmpty) return;

    final attempts = (_loginAttempts[username] ?? 0) + 1;
    _loginAttempts[username] = attempts;

    if (attempts >= _maxLoginAttempts) {
      // Show alert dialog
      if (mounted) {
        // Ensure widget is still in the tree
        showDialog(
          context: context,
          barrierDismissible: false, // User must tap button!
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Too Many Login Attempts'),
              content: const Text(
                  'You have exceeded the maximum number of login attempts. Would you like to reset your password?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Dismiss dialog
                  },
                ),
                TextButton(
                  child: const Text('Reset Password'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Dismiss dialog
                    // Reset attempts for this user as they are being navigated to reset password
                    _loginAttempts.remove(username);
                    Navigator.push(
                      context, // Use the original context for navigation
                      MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

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
                        color: Colors.black.withAlpha(50),
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
                          borderRadius: BorderRadius.circular(30),
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
                        isSelected: true,
                        onTap: () {
                          // No action needed as this is the only option
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
                                    color: Colors.white.withAlpha(230),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 50), // Adjusted spacing

                              // Static image with circular white background, now with FadeTransition
                              FadeTransition(
                                opacity:
                                    _fadeAnimation, // Using the existing fade animation
                                child: _imageRotationController ==
                                        null // Guard condition
                                    ? const SizedBox(
                                        width: 220,
                                        height:
                                            220) // Placeholder if not initialized
                                    : AnimatedBuilder(
                                        animation: _logoFloatController,
                                        builder: (BuildContext context,
                                            Widget? staticRotatingChild) {
                                          double floatValue =
                                              _logoFloatAnimation.value;
                                          double normalizedFloatAbs = floatValue
                                                  .abs() /
                                              10.0; // 0 at center, 1 at extremes

                                          double shadowOpacity = 0.15 +
                                              (0.1 * (1 - normalizedFloatAbs));
                                          double shadowBlur =
                                              8 + (12 * normalizedFloatAbs);
                                          double shadowSpread =
                                              1 + (4 * normalizedFloatAbs);
                                          double shadowWidth =
                                              180 - (30 * normalizedFloatAbs);
                                          double shadowHeight =
                                              15 - (7 * normalizedFloatAbs);

                                          return Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Shadow Element
                                              if (_logoFloatController
                                                  .isAnimating)
                                                Transform.translate(
                                                  offset: const Offset(0,
                                                      125.0), // Changed: Fixed Y offset for shadow to be at the bottom
                                                  child: Container(
                                                    width: shadowWidth,
                                                    height: shadowHeight,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.rectangle,
                                                      borderRadius:
                                                          BorderRadius.all(
                                                              Radius.elliptical(
                                                                  shadowWidth /
                                                                      2,
                                                                  shadowHeight /
                                                                      2)),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withAlpha((255 *
                                                                      shadowOpacity)
                                                                  .round()),
                                                          blurRadius:
                                                              shadowBlur,
                                                          spreadRadius:
                                                              shadowSpread,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                              // Floating and Rotating Logo
                                              Transform.translate(
                                                offset: Offset(0, floatValue),
                                                child: staticRotatingChild,
                                              ),
                                            ],
                                          );
                                        },
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            if (mounted) {
                                              // Add mounted check
                                              setState(() {
                                                _interactiveRotationAngle +=
                                                    details.delta.dx * 0.01;
                                              });
                                            }
                                          },
                                          onPanEnd: (details) {
                                            if (mounted &&
                                                _imageRotationController !=
                                                    null &&
                                                !_imageRotationController!
                                                    .isAnimating) {
                                              // Add mounted & null checks
                                              _interactiveRotationAngleStartSnap =
                                                  _interactiveRotationAngle;
                                              _imageRotationController!
                                                  .forward(from: 0.0);
                                            }
                                          },
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..setEntry(3, 2, 0.001)
                                              ..rotateY(
                                                  _continuousRotationAnimation
                                                          .value +
                                                      _interactiveRotationAngle),
                                            child: Container(
                                              width:
                                                  200, // Slightly smaller to give shadow space
                                              height: 200,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    Colors.white.withAlpha(242),
                                              ),
                                              child: ClipOval(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Image.asset(
                                                    'assets/images/slide1.png',
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (BuildContext context,
                                                            Object exception,
                                                            StackTrace?
                                                                stackTrace) {
                                                      return Center(
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color:
                                                              Colors.teal[700],
                                                          size:
                                                              50, // Adjusted size
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(
                                  height: 40), // Spacing after the image
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

                                    // Forgot password link - REMOVED
                                    // Center(
                                    //   child: TextButton(
                                    //     onPressed: _isLoading
                                    //         ? null
                                    //         : () {
                                    //             Navigator.push(
                                    //               context,
                                    //               MaterialPageRoute(
                                    //                 builder: (context) =>
                                    //                     const ForgotPasswordScreen(),
                                    //               ),
                                    //             );
                                    //           },
                                    //     child: Text(
                                    //       'Forgot Password?',
                                    //       style: TextStyle(
                                    //           color: theme.primaryColor),
                                    //     ),
                                    //   ),
                                    // ),
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
