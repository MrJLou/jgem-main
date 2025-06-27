import 'package:flutter/material.dart';
import '../services/api_service.dart';
// import '../services/auth_service.dart'; // AuthService.hashSecurityAnswer is no longer called here
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedQuestionKey; // e.g., "securityQuestion1"
  Map<String, String> _userQuestionMap =
      {}; // Populated from _userSecurityDetails

  bool _isLoading = false;
  bool _isLoadingQuestions = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _usernameController.dispose();
    _securityAnswerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserSecurityQuestions() async {
    if (_usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username first.';
        _userQuestionMap = {};
        _selectedQuestionKey = null;
      });
      return;
    }
    setState(() {
      _isLoadingQuestions = true;
      _errorMessage = null;
      _userQuestionMap = {};
      _selectedQuestionKey = null;
    });
    try {
      final userDetails =
          await ApiService.getUserSecurityDetails(_usernameController.text);
      if (!mounted) return;
      if (userDetails != null) {
        setState(() {
          _userQuestionMap = {};
          if (userDetails.securityQuestion1 != null &&
              userDetails.securityQuestion1!.isNotEmpty) {
            _userQuestionMap['securityQuestion1'] =
                userDetails.securityQuestion1!;
          }
          if (userDetails.securityQuestion2 != null &&
              userDetails.securityQuestion2!.isNotEmpty) {
            _userQuestionMap['securityQuestion2'] =
                userDetails.securityQuestion2!;
          }
          if (userDetails.securityQuestion3 != null &&
              userDetails.securityQuestion3!.isNotEmpty) {
            _userQuestionMap['securityQuestion3'] =
                userDetails.securityQuestion3!;
          }
          if (_userQuestionMap.isNotEmpty) {
            _selectedQuestionKey = _userQuestionMap
                .keys.first; // Default to first available question
          } else {
            _errorMessage = 'No security questions found for this user.';
          }
        });
      } else {
        setState(() {
          _errorMessage = 'User not found or no security questions configured.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to fetch security questions: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }
      if (_selectedQuestionKey == null || _userQuestionMap.isEmpty) {
        setState(() {
          _errorMessage = 'Please select a security question.';
        });
        return;
      }

      setState(() => _isLoading = true);
      try {
        final success = await ApiService.resetPassword(
          _usernameController.text,
          _selectedQuestionKey!, // Use the key of the selected question
          _securityAnswerController.text, // Pass raw answer
          _newPasswordController.text,
        );

        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset successfully! Please login'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          setState(() {
            _errorMessage =
                'Password reset failed. Please check your information.';
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
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
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: Colors.teal[600],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            "Recover Your Account",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            "Reset your password using your security question.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withAlpha(230),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 60),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const SizedBox(
                            height: 250,
                            width: 250,
                            child: Icon(
                              Icons.lock_reset,
                              size: 120,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text("Remember your password?"),
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
                              const SizedBox(height: 30),
                              Text(
                                'Reset Password',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[800]),
                              ),
                              const SizedBox(height: 20),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: Colors.teal[700]),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _isLoadingQuestions
                                    ? null
                                    : _fetchUserSecurityQuestions,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[600],
                                    foregroundColor: Colors.white),
                                child: _isLoadingQuestions
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white)))
                                    : const Text('Fetch Security Questions'),
                              ),
                              const SizedBox(height: 12),
                              if (_userQuestionMap.isNotEmpty) ...[
                                DropdownButtonFormField<String>(
                                  value: _selectedQuestionKey,
                                  items: _userQuestionMap.entries
                                      .map((entry) => DropdownMenuItem(
                                            value: entry.key,
                                            child: Text(entry.value,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedQuestionKey = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Select Security Question',
                                    prefixIcon: Icon(Icons.shield_outlined,
                                        color: Colors.teal[700]),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  validator: (value) => value == null
                                      ? 'Please select a question'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _securityAnswerController,
                                  decoration: InputDecoration(
                                    labelText: 'Security Answer',
                                    prefixIcon: Icon(Icons.vpn_key_outlined,
                                        color: Colors.teal[700]),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your security answer';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _newPasswordController,
                                  decoration: InputDecoration(
                                    labelText: 'New Password',
                                    prefixIcon: Icon(Icons.lock_outline,
                                        color: Colors.teal[700]),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                          _obscureNewPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.teal[700]),
                                      onPressed: () {
                                        setState(() => _obscureNewPassword =
                                            !_obscureNewPassword);
                                      },
                                    ),
                                  ),
                                  obscureText: _obscureNewPassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a new password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm New Password',
                                    prefixIcon: Icon(Icons.lock_clock_outlined,
                                        color:
                                            Colors.teal[700]), // Corrected Icon
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.teal[700]),
                                      onPressed: () {
                                        setState(() => _obscureConfirmPassword =
                                            !_obscureConfirmPassword);
                                      },
                                    ),
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your new password';
                                    }
                                    if (value != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleResetPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white)))
                                        : const Text('RESET PASSWORD',
                                            style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ],
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
}
