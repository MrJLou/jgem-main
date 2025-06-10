import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/login_rate_limiter.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int _selectedIndex = 0; // 0 for Sign In, 1 for Sign Up
  bool _isLoading = false;

  // Login form controllers
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _loginUsernameController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  bool _obscureLoginPassword = true;
  String? _loginErrorMessage;

  // Signup form controllers
  final _signupFormKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _signupUsernameController =
      TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _securityAnswer1Controller =
      TextEditingController();
  final TextEditingController _securityAnswer2Controller =
      TextEditingController();
  final TextEditingController _securityAnswer3Controller =
      TextEditingController();
  String _selectedSecurityQuestion1 = 'What was your first pet\'s name?';
  String _selectedSecurityQuestion2 = 'What city were you born in?';
  String _selectedSecurityQuestion3 = 'What is your mother\'s maiden name?';
  String _selectedRole = 'medtech';
  bool _obscureSignupPassword = true;
  bool _obscureConfirmPassword = true;
  String? _signupErrorMessage;

  // Password strength indicator
  double _passwordStrengthValue = 0.0;
  Color _passwordStrengthColor = Colors.grey.shade300;
  String _passwordStrengthText = "";

  final List<String> _securityQuestions = [
    'What was your first pet\'s name?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your first school?',
    'What is your favorite book?',
    'What was the model of your first car?'
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeInOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimationController.forward();
    _checkExistingSession();
    _signupPasswordController.addListener(_onPasswordChanged);
    _updatePasswordStrengthUi("");
  }

  void _onPasswordChanged() {
    _updatePasswordStrengthUi(_signupPasswordController.text);
  }

  void _updatePasswordStrengthUi(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrengthValue = 0.0;
        _passwordStrengthColor = Colors.grey.shade300;
        _passwordStrengthText = "";
      });
      return;
    }

    int score = 0;
    if (password.length >= 12) {
      score += 2;
    } else if (password.length >= 8) {
      score += 1;
    }
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) {
      setState(() {
        _passwordStrengthValue = 0.33;
        _passwordStrengthColor = Colors.red;
        _passwordStrengthText = "Weak";
      });
    } else if (score <= 4) {
      setState(() {
        _passwordStrengthValue = 0.66;
        _passwordStrengthColor = Colors.yellow.shade700;
        _passwordStrengthText = "Medium";
      });
    } else {
      setState(() {
        _passwordStrengthValue = 1.0;
        _passwordStrengthColor = Colors.green;
        _passwordStrengthText = "Strong";
      });
    }
  }

  Future<void> _checkExistingSession() async {
    setState(() => _isLoading = true);
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;

      if (isLoggedIn) {
        final credentials = await AuthService.getSavedCredentials();
        if (!mounted) return;

        if (credentials != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                accessLevel: credentials['accessLevel'] ?? 'user',
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

  void _switchToTab(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      _slideAnimationController.forward();
    } else {
      _slideAnimationController.reverse();
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
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

        final response =
            await ApiService.login(username, _loginPasswordController.text);
        
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
        await AuthService.saveLoginCredentials(
          token: response['token'],
          username: username,
          accessLevel: userRole,
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(accessLevel: userRole),
          ),
          (route) => false,
        );
      } catch (e) {
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

  Future<void> _handleSignUp() async {
    setState(() {
      _signupErrorMessage = null;
    });

    if (_signupFormKey.currentState!.validate()) {
      if (_selectedSecurityQuestion1 == _selectedSecurityQuestion2 ||
          _selectedSecurityQuestion1 == _selectedSecurityQuestion3 ||
          _selectedSecurityQuestion2 == _selectedSecurityQuestion3) {
        setState(() {
          _signupErrorMessage =
              'Please select three unique security questions.';
        });
        return;
      }

      if (_signupPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _signupErrorMessage = 'Passwords do not match';
        });
        return;
      }

      setState(() => _isLoading = true);
      try {
        final String hashedSecurityAnswer1 =
            AuthService.hashSecurityAnswer(_securityAnswer1Controller.text);
        final String hashedSecurityAnswer2 =
            AuthService.hashSecurityAnswer(_securityAnswer2Controller.text);
        final String hashedSecurityAnswer3 =
            AuthService.hashSecurityAnswer(_securityAnswer3Controller.text);
        await ApiService.register(
          fullName: _fullNameController.text,
          username: _signupUsernameController.text,
          password: _signupPasswordController.text,
          role: _selectedRole,
          securityQuestion1: _selectedSecurityQuestion1,
          securityAnswer1: hashedSecurityAnswer1,
          securityQuestion2: _selectedSecurityQuestion2,
          securityAnswer2: hashedSecurityAnswer2,
          securityQuestion3: _selectedSecurityQuestion3,
          securityAnswer3: hashedSecurityAnswer3,
        );
        await LoginRateLimiter.recordSuccessfulLogin(
            _signupUsernameController.text);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Signup successful! Please log in with your new credentials.'),
            backgroundColor: Colors.green,
          ),
        );
        _switchToTab(0);
      } catch (e) {
        if (_signupUsernameController.text.isNotEmpty) {
          await LoginRateLimiter.recordFailedAttempt(
              _signupUsernameController.text);
        }
        if (!mounted) return;
        setState(() {
          _signupErrorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _signupUsernameController.dispose();
    _signupPasswordController.dispose();
    _confirmPasswordController.dispose();
    _securityAnswer1Controller.dispose();
    _securityAnswer2Controller.dispose();
    _securityAnswer3Controller.dispose();
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
                  // Side Navigation with sliding indicator
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
                    child: Stack(
                      children: [
                        // Sliding indicator
                        AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: 200 + (_selectedIndex * 80.0),
                              left: 0,
                              child: Transform.translate(
                                offset: Offset(_slideAnimation.value.dx * 4, 0),
                                child: Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.teal[700],
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(2),
                                      bottomRight: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Column(
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
                              isSelected: _selectedIndex == 0,
                              onTap: () => _switchToTab(0),
                            ),

                            // Sign Up Button
                            _buildSideNavItem(
                              icon: Icons.person_add,
                              label: 'Sign Up',
                              isSelected: _selectedIndex == 1,
                              onTap: () => _switchToTab(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main Content with PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                        if (index == 1) {
                          _slideAnimationController.forward();
                        } else {
                          _slideAnimationController.reverse();
                        }
                      },
                      children: [
                        _buildLoginPage(),
                        _buildSignUpPage(),
                      ],
                    ),
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

  Widget _buildSignUpPage() {
    final List<String> availableRoles = ['doctor', 'medtech'];

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
                  tag: 'auth_illustration_signup',
                  child: Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [Colors.blue[200]!, Colors.blue[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      size: 120,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Join Our Team!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create your account to get started',
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

        // Right side with Signup Form
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(60),
            child: SingleChildScrollView(
              child: Form(
                key: _signupFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_signupErrorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          _signupErrorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),

                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _signupUsernameController,
                      label: 'Username',
                      icon: Icons.account_circle,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role selection
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.work, color: Colors.teal[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: availableRoles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildPasswordField(
                      controller: _signupPasswordController,
                      label: 'Password',
                      obscureText: _obscureSignupPassword,
                      toggleObscure: () {
                        setState(() {
                          _obscureSignupPassword = !_obscureSignupPassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildPasswordStrengthIndicator(),
                    const SizedBox(height: 16),

                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscureConfirmPassword,
                      toggleObscure: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _signupPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Security Questions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSecurityQuestionDropdown(
                      label: 'Security Question 1',
                      value: _selectedSecurityQuestion1,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSecurityQuestion1 = newValue!;
                        });
                      },
                      items: _securityQuestions,
                    ),
                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _securityAnswer1Controller,
                      label: 'Answer 1',
                      icon: Icons.lock,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an answer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSecurityQuestionDropdown(
                      label: 'Security Question 2',
                      value: _selectedSecurityQuestion2,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSecurityQuestion2 = newValue!;
                        });
                      },
                      items: _securityQuestions,
                    ),
                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _securityAnswer2Controller,
                      label: 'Answer 2',
                      icon: Icons.lock,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an answer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSecurityQuestionDropdown(
                      label: 'Security Question 3',
                      value: _selectedSecurityQuestion3,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSecurityQuestion3 = newValue!;
                        });
                      },
                      items: _securityQuestions,
                    ),
                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: _securityAnswer3Controller,
                      label: 'Answer 3',
                      icon: Icons.lock,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an answer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
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
                              'Create Account',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              _passwordStrengthText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _passwordStrengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: _passwordStrengthValue,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
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
      ),
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

  Widget _buildSecurityQuestionDropdown({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
    required List<String> items,
  }) {
    List<String> availableItems = items.where((item) {
      if (label == 'Security Question 1') {
        return item != _selectedSecurityQuestion2 &&
            item != _selectedSecurityQuestion3;
      } else if (label == 'Security Question 2') {
        return item != _selectedSecurityQuestion1 &&
            item != _selectedSecurityQuestion3;
      } else if (label == 'Security Question 3') {
        return item != _selectedSecurityQuestion1 &&
            item != _selectedSecurityQuestion2;
      }
      return true;
    }).toList();

    String? currentValueInDropdown =
        availableItems.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.help, color: Colors.teal[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      value: currentValueInDropdown,
      icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.teal[700]),
      items: availableItems.map<DropdownMenuItem<String>>((String question) {
        return DropdownMenuItem<String>(
          value: question,
          child: Text(question),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Please select a security question';
        }
        return null;
      },
    );
  }
}
