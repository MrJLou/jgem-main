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
  final TextEditingController _securityAnswer1Controller =
      TextEditingController();
  final TextEditingController _securityAnswer2Controller =
      TextEditingController();
  final TextEditingController _securityAnswer3Controller =
      TextEditingController();
  String _selectedSecurityQuestion1 = 'What was your first pet\'s name?';
  String _selectedSecurityQuestion2 = 'What city were you born in?';
  String _selectedSecurityQuestion3 = 'What is your mother\'s maiden name?';
  String _selectedRole = 'medtech'; // Default role, will be selectable
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
    'What was the name of your first school?',
    'What is your favorite book?',
    'What was the model of your first car?'
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
    _securityAnswer1Controller.dispose();
    _securityAnswer2Controller.dispose();
    _securityAnswer3Controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      // Check for unique security questions first
      if (_selectedSecurityQuestion1 == _selectedSecurityQuestion2 ||
          _selectedSecurityQuestion1 == _selectedSecurityQuestion3 ||
          _selectedSecurityQuestion2 == _selectedSecurityQuestion3) {
        setState(() {
          _errorMessage = 'Please select three unique security questions.';
        });
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
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

        // Ensure ApiService.register is updated on the backend to accept these fields
        await ApiService.register(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          role: _selectedRole,
          securityQuestion1: _selectedSecurityQuestion1,
          securityAnswer1: hashedSecurityAnswer1,
          securityQuestion2: _selectedSecurityQuestion2,
          securityAnswer2: hashedSecurityAnswer2,
          securityQuestion3: _selectedSecurityQuestion3,
          securityAnswer3: hashedSecurityAnswer3,
          // birthDate: _birthDateController.text, // Removed
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Registration successful! Please login')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Registration failed: ${e.toString()}';
            // More specific error for API issues if possible
            if (e.toString().contains('NoSuchMethodError') ||
                e.toString().contains('Invalid argument')) {
              _errorMessage =
                  'Registration failed due to API incompatibility. Please contact support. (Details: $e)';
            }
          });
        }
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

    final List<String> availableRoles = ['doctor', 'medtech'];

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
                    Navigator.pushReplacement(
                      // Use pushReplacement to avoid stacking screens
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
                    // Already on Sign Up, do nothing or refresh state if needed
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
                            textAlign: TextAlign.center,
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
                            "Create an account to manage patient records efficiently and securely.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/images/medical_illustration_2.png', // Ensure this asset exists
                          height: size.height * 0.30,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image_not_supported_outlined,
                                color: Colors.white70, size: size.height * 0.2);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Right side with Form
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.04,
                          vertical: 30), // Adjusted padding
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                "Create Account",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  // Adjusted style
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800],
                                ),
                              ),
                              const SizedBox(height: 25), // Adjusted spacing
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 15.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 14), // Enhanced error style
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              // Full Name
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Username
                              _buildTextField(
                                controller: _usernameController,
                                label: 'Username',
                                icon: Icons.account_circle_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  if (value.length < 4) {
                                    return 'Username must be at least 4 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Role Selection Dropdown
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.verified_user_outlined,
                                      color: theme.primaryColorDark),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: availableRoles.map((String role) {
                                  return DropdownMenuItem<String>(
                                    value: role,
                                    child: Text(role[0].toUpperCase() +
                                        role.substring(
                                            1)), // Capitalize first letter
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedRole = newValue!;
                                  });
                                },
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Please select a role'
                                        : null,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildPasswordField(
                                controller: _passwordController,
                                label: 'Password',
                                obscureText: _obscurePassword,
                                toggleObscure: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(height: 16),

                              // Confirm Password
                              _buildPasswordField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                obscureText: _obscureConfirmPassword,
                                toggleObscure: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20), // Adjusted spacing

                              // Security Question 1
                              _buildSecurityQuestionDropdown(
                                label: 'Security Question 1',
                                value: _selectedSecurityQuestion1,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    if (newValue == null) return;
                                    if (newValue ==
                                            _selectedSecurityQuestion2 ||
                                        newValue ==
                                            _selectedSecurityQuestion3) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              duration: Duration(seconds: 2),
                                              content: Text(
                                                  "Please select a unique security question.")));
                                    } else {
                                      _selectedSecurityQuestion1 = newValue;
                                    }
                                  });
                                },
                                items: _securityQuestions,
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                controller: _securityAnswer1Controller,
                                label: 'Answer for Security Question 1',
                                icon: Icons.security_update_good_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please answer security question 1';
                                  }
                                  if (value.length < 2) {
                                    return 'Answer must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Security Question 2
                              _buildSecurityQuestionDropdown(
                                label: 'Security Question 2',
                                value: _selectedSecurityQuestion2,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    if (newValue == null) return;
                                    if (newValue ==
                                            _selectedSecurityQuestion1 ||
                                        newValue ==
                                            _selectedSecurityQuestion3) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              duration: Duration(seconds: 2),
                                              content: Text(
                                                  "Please select a unique security question.")));
                                    } else {
                                      _selectedSecurityQuestion2 = newValue;
                                    }
                                  });
                                },
                                items: _securityQuestions,
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                controller: _securityAnswer2Controller,
                                label: 'Answer for Security Question 2',
                                icon: Icons.security_update_good_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please answer security question 2';
                                  }
                                  if (value.length < 2) {
                                    return 'Answer must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Security Question 3
                              _buildSecurityQuestionDropdown(
                                label: 'Security Question 3',
                                value: _selectedSecurityQuestion3,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    if (newValue == null) return;
                                    if (newValue ==
                                            _selectedSecurityQuestion1 ||
                                        newValue ==
                                            _selectedSecurityQuestion2) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              duration: Duration(seconds: 2),
                                              content: Text(
                                                  "Please select a unique security question.")));
                                    } else {
                                      _selectedSecurityQuestion3 = newValue;
                                    }
                                  });
                                },
                                items: _securityQuestions,
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                controller: _securityAnswer3Controller,
                                label: 'Answer for Security Question 3',
                                icon: Icons.security_update_good_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please answer security question 3';
                                  }
                                  if (value.length < 2) {
                                    return 'Answer must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 25), // Adjusted spacing

                              // Sign Up Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[700],
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                ),
                                onPressed: _isLoading ? null : _signUp,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                            fontSize: 16, color: Colors.white),
                                      ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account?",
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        // Use pushReplacement
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: Colors.teal[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.teal.withOpacity(0.1),
        highlightColor: Colors.teal.withOpacity(0.05),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.teal.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.teal[700] : Colors.grey[600],
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.teal[800] : Colors.grey[700],
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[700]),
        prefixIcon: Icon(icon, color: Colors.teal[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade300, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2.0),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      obscureText: obscureText,
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
        labelStyle: TextStyle(color: Colors.teal[700]),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.teal[700]),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.teal[700]?.withOpacity(0.7),
          ),
          onPressed: toggleObscure,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade300, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2.0),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      obscureText: obscureText,
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            // Password strength check (example)
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            if (!value.contains(RegExp(r'[A-Z]'))) {
              return 'Password must contain an uppercase letter';
            }
            if (!value.contains(RegExp(r'[a-z]'))) {
              return 'Password must contain a lowercase letter';
            }
            if (!value.contains(RegExp(r'[0-9]'))) {
              return 'Password must contain a number';
            }
            if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]' ''))) {
              // Escaped '''
              return 'Password must contain a special character';
            }
            return null;
          },
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  Widget _buildSecurityQuestionDropdown({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
    required List<String> items,
  }) {
    // Filter out already selected questions from other dropdowns to ensure uniqueness
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

    String? currentValueInDropdown = items.contains(value) ? value : null;
    if (currentValueInDropdown == null &&
        availableItems.isNotEmpty &&
        !availableItems.contains(value)) {
      // If current value is invalid due to other selections, try to pick first from all items
      // if it doesn't create a new conflict. This is tricky, _signUp is main guard.
      // Forcing a valid display or null (prompting selection) is safer here.
      currentValueInDropdown = null;
    }

    return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal[700]),
          prefixIcon: Icon(Icons.shield_outlined, color: Colors.teal[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal.shade700, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        ),
        value: currentValueInDropdown,
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.teal[700]),
        iconSize: 28,
        elevation: 16,
        style: TextStyle(color: Colors.grey[800], fontSize: 16),
        dropdownColor: Colors.white,
        onChanged:
            onChanged, // Let parent handle state update and main validation
        items: items.map<DropdownMenuItem<String>>((String question) {
          bool isSelectedElsewhere = (label != 'Security Question 1' &&
                  question == _selectedSecurityQuestion1) ||
              (label != 'Security Question 2' &&
                  question == _selectedSecurityQuestion2) ||
              (label != 'Security Question 3' &&
                  question == _selectedSecurityQuestion3);
          return DropdownMenuItem<String>(
            value: question,
            enabled: !isSelectedElsewhere,
            child: Text(question,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelectedElsewhere
                      ? Colors.grey[400] // Grey out if selected elsewhere
                      : Colors.grey[800],
                  decoration:
                      isSelectedElsewhere ? TextDecoration.lineThrough : null,
                )),
          );
        }).toList(),
        validator: (val) {
          if (val == null || val.isEmpty) return 'Please select a question';
          // More robust validation is in _signUp to check uniqueness across all three
          return null;
        });
  }
}
