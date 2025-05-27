import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/password_validator.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  String _selectedSecurityQuestion = 'What was your first pet\'s name?';
  final String _selectedRole = 'patient'; // Default role for new signups
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 1; // 0 for Sign In, 1 for Sign Up
  String? _errorMessage;

  final List<String> _securityQuestions = [
    'What was your first pet\'s name?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your first school?'
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _securityAnswerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now()
              .subtract(const Duration(days: 6570)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Hash the security answer when registering
        final String hashedSecurityAnswer =
            AuthService.hashSecurityAnswer(_securityAnswerController.text);

        // Call your API service for registration
        await ApiService.register(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          birthDate: _birthDateController.text,
          role: _selectedRole,
          securityQuestion: _selectedSecurityQuestion,
          securityAnswer: hashedSecurityAnswer,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registration successful! Please login')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Registration failed: $e';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                ),

                // Sign Up Button
                _buildSideNavItem(
                  icon: Icons.person_add,
                  label: 'Sign Up',
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
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
                            "Create an account to manage records.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Illustration matching the provided image
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const SizedBox(
                            height: 250,
                            width: 250,
                            child: Icon(
                              Icons.how_to_reg,
                              size: 120,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right side with Sign up Form
                Expanded(
                  flex: 5,
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50.0, vertical: 30.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Already have an account text
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text("Already have an account?"),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Sign Up Title
                              const Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Display error message if there is one
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red[700]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style:
                                              TextStyle(color: Colors.red[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Full Name field
                              const Text(
                                "Full Name",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your full name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  if (value.trim().split(' ').length < 2) {
                                    return 'Please enter both first and last name';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 16),

                              // Username field
                              const Text(
                                "Username",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  hintText: 'Choose a unique username',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.alternate_email),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  if (value.length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  if (value.contains(' ')) {
                                    return 'Username cannot contain spaces';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 16),

                              // Birth Date field
                              const Text(
                                "Birth Date",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _birthDateController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  hintText: 'Select your birth date',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                onTap: () => _selectDate(context),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your birth date';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

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
                                  hintText: 'Create a strong password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  if (!RegExp(
                                          r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)')
                                      .hasMatch(value)) {
                                    return 'Password must contain uppercase, lowercase, and number';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password field
                              const Text(
                                "Confirm Password",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  hintText: 'Re-enter your password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 16),

                              // Security Question dropdown
                              const Text(
                                "Security Question",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedSecurityQuestion,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: _securityQuestions
                                    .map((question) => DropdownMenuItem(
                                          value: question,
                                          child: Text(question),
                                        ))
                                    .toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedSecurityQuestion = value!;
                                        });
                                      },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a security question';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Security Answer field
                              const Text(
                                "Security Answer",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _securityAnswerController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your answer',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.question_answer),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter the security answer';
                                  }
                                  if (value.length < 2) {
                                    return 'Answer must be at least 2 characters';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 24),

                              // Register button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.teal[700],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _isLoading ? null : _signUp,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'SIGN UP',
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
                                  'By clicking Sign Up, you agree to our Terms of Service and Privacy Policy.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 20),
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
}
