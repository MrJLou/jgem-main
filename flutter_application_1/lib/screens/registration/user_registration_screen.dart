import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/doctor_schedule.dart'; // This has workingDays
import '../../services/doctor_schedule_service.dart';

// Days of week enum for the registration form
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get displayName {
    switch (this) {
      case DayOfWeek.monday: return 'Monday';
      case DayOfWeek.tuesday: return 'Tuesday';
      case DayOfWeek.wednesday: return 'Wednesday';
      case DayOfWeek.thursday: return 'Thursday';
      case DayOfWeek.friday: return 'Friday';
      case DayOfWeek.saturday: return 'Saturday';
      case DayOfWeek.sunday: return 'Sunday';
    }
  }
}

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  UserRegistrationScreenState createState() => UserRegistrationScreenState();
}

class UserRegistrationScreenState extends State<UserRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
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
  String? _errorMessage;

  // Doctor working days selection (simplified with strings)
  final Map<String, bool> _selectedDays = {
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': true,
    'sunday': false,
  };

  // Doctor service hours (when they arrive and leave the clinic)
  TimeOfDay _arrivalTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _departureTime = const TimeOfDay(hour: 16, minute: 30);

  // Simple configuration for doctor schedules
  bool _enableTimeSlotAllocation = false; // Disable complex time slots
  int _slotDurationMinutes = 30; // Keep for UI compatibility
  final List<int> _availableSlotDurations = [15, 30, 45, 60]; // Keep for UI compatibility

  // Days of week for the UI
  final List<String> _allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  // For password strength indicator
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
    _passwordController.addListener(_onPasswordChanged);
    _updatePasswordStrengthUi(
        ""); // Initial call to set default state for indicator
  }

  void _onPasswordChanged() {
    _updatePasswordStrengthUi(_passwordController.text);
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
    // Criterion 1: Length
    if (password.length >= 12) {
      score += 2;
    } else if (password.length >= 8) {
      score += 1;
    }

    // Criterion 2: Uppercase
    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    // Criterion 3: Lowercase
    if (RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    // Criterion 4: Number
    if (RegExp(r'[0-9]').hasMatch(password)) {
      score++;
    }
    // Criterion 5: Special Character
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      // Escaped '''
      score++;
    }

    // Max score could be 6 (e.g. length > 12 counts as 2, plus 4 other criteria)
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

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
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

    // Validate doctor working days if role is doctor
    if (_selectedRole == 'doctor') {
      if (_selectedDays.values.every((selected) => !selected)) {
        setState(() {
          _errorMessage = 'Please select at least one working day for the doctor.';
        });
        return;
      }
    }

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
          email: _emailController.text,
          contactNumber: _contactNumberController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          role: _selectedRole,
          securityQuestion1: _selectedSecurityQuestion1,
          securityAnswer1: hashedSecurityAnswer1,
          securityQuestion2: _selectedSecurityQuestion2,
          securityAnswer2: hashedSecurityAnswer2,
          securityQuestion3: _selectedSecurityQuestion3,
          securityAnswer3: hashedSecurityAnswer3,
        );

        // If this is a doctor, create their availability schedule and time slots
        if (_selectedRole == 'doctor' && mounted) {
          try {
            await _createDoctorAvailability();
          } catch (e) {
            // Log error but don't fail registration
            debugPrint('Warning: Could not create doctor availability: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Registration successful! User created'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context);
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

  Future<void> _createDoctorAvailability() async {
    try {
      // Validate that required fields are not empty
      if (_selectedDays.values.every((selected) => !selected)) {
        throw Exception('At least one available day is required for doctor registration');
      }

      // Get the newly created user to get their ID
      final users = await ApiService.getUsers();
      final newUser = users.firstWhere(
        (user) => user.username == _usernameController.text,
        orElse: () => throw Exception('Could not find newly created user'),
      );

      // Create simple work schedule with selected days
      final workingDaysMap = Map<String, bool>.from(_selectedDays);
      
      final newSchedule = DoctorSchedule(
        id: 'schedule_${newUser.id}_${DateTime.now().millisecondsSinceEpoch}',
        doctorId: newUser.id,
        doctorName: newUser.fullName,
        workingDays: workingDaysMap,
        arrivalTime: _arrivalTime,
        departureTime: _departureTime,
        isActive: true,
        notes: 'Created during registration',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await DoctorScheduleService.saveDoctorSchedule(newSchedule);
      debugPrint('Simple work schedule created successfully for doctor: ${newUser.fullName}');
    } catch (e) {
      debugPrint('Error creating doctor availability: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    final List<String> availableRoles = ['doctor', 'medtech'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        elevation: 0,
        title: const Text(
          'User Registration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal[50]!, Colors.white, Colors.teal[50]!],
          ),
        ),
        child: Row(
          children: [
            // Left side - Logo and branding (40% width)
            Expanded(
              flex: 40,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.teal[700]!, Colors.teal[500]!],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo placeholder
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.local_hospital,
                            size: 60,
                            color: Colors.teal[700],
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Company name
                        const Text(
                          'JGEM',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Subtitle
                        Text(
                          'Healthcare Management System',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withAlpha(10),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        
                        // Feature highlights
                        _buildFeatureItem(Icons.security, 'Secure Registration'),
                        const SizedBox(height: 15),
                        _buildFeatureItem(Icons.group, 'User Management'),
                        const SizedBox(height: 15),
                        _buildFeatureItem(Icons.shield, 'Data Protection'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Right side - Registration form (60% width)
            Expanded(
              flex: 60,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Text(
                                'Create New User',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Register a new system user with secure credentials',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Error Message
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red[700]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(color: Colors.red[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Personal Information Section
                              _buildSectionHeader('Personal Information', Icons.person),
                              const SizedBox(height: 16),

                              // Full Name Field
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Email and Contact Number Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _emailController,
                                      label: 'Email Address',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter email';
                                        }
                                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                          return 'Enter valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _contactNumberController,
                                      label: 'Contact Number',
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter contact number';
                                        }
                                        if (value.length < 10) {
                                          return 'Enter valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Account Information Section
                              _buildSectionHeader('Account Information', Icons.account_circle),
                              const SizedBox(height: 16),

                              // Username and Role Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      icon: Icons.account_circle_outlined,
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
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedRole,
                                      decoration: InputDecoration(
                                        labelText: 'Role',
                                        labelStyle: TextStyle(color: Colors.teal[700]),
                                        prefixIcon: Icon(Icons.work_outline, color: Colors.teal[700]),
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
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                                      ),
                                      items: availableRoles.map((role) {
                                        return DropdownMenuItem(
                                          value: role,
                                          child: Text(role.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedRole = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Doctor Availability Section (only shown for doctors)
                              if (_selectedRole == 'doctor') ...[
                                _buildDoctorAvailabilitySection(),
                                const SizedBox(height: 16),
                              ],

                              // Password Field
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

                              // Password Strength Indicator
                              _buildPasswordStrengthIndicator(),
                              const SizedBox(height: 16),

                              // Confirm Password Field
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
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Security Questions Section
                              _buildSectionHeader('Security Questions', Icons.security),
                              const SizedBox(height: 16),

                              // Security Question 1
                              _buildSecurityQuestionDropdown(
                                label: 'Security Question 1',
                                value: _selectedSecurityQuestion1,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSecurityQuestion1 = value!;
                                  });
                                },
                                items: _securityQuestions,
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _securityAnswer1Controller,
                                label: 'Answer 1',
                                icon: Icons.question_answer_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an answer';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Security Question 2
                              _buildSecurityQuestionDropdown(
                                label: 'Security Question 2',
                                value: _selectedSecurityQuestion2,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSecurityQuestion2 = value!;
                                  });
                                },
                                items: _securityQuestions,
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _securityAnswer2Controller,
                                label: 'Answer 2',
                                icon: Icons.question_answer_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an answer';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Security Question 3
                              _buildSecurityQuestionDropdown(
                                label: 'Security Question 3',
                                value: _selectedSecurityQuestion3,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSecurityQuestion3 = value!;
                                  });
                                },
                                items: _securityQuestions,
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _securityAnswer3Controller,
                                label: 'Answer 3',
                                icon: Icons.question_answer_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an answer';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),

                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.person_add, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Create User Account',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withAlpha(10),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.teal[700],
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[300]!, Colors.transparent],
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
        if (_passwordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 0.0, bottom: 4.0),
            child: Text(
              "Password Strength: $_passwordStrengthText",
              style: TextStyle(
                color: _passwordStrengthColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        LinearProgressIndicator(
          value: _passwordStrengthValue,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
          minHeight: 6,
        ),
      ],
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
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
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
            color: Colors.teal[700]?.withAlpha(179),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      obscureText: obscureText,
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
            bool hasLowercase = value.contains(RegExp(r'[a-z]'));
            bool hasDigits = value.contains(RegExp(r'[0-9]'));
            bool hasSpecialCharacters = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            if (!hasUppercase) {
              return 'Password must contain an uppercase letter';
            }
            if (!hasLowercase) {
              return 'Password must contain a lowercase letter';
            }
            if (!hasDigits) return 'Password must contain a number';
            if (!hasSpecialCharacters) {
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
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        ),
        value: currentValueInDropdown,
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.teal[700]),
        iconSize: 28,
        elevation: 16,
        style: TextStyle(color: Colors.grey[800], fontSize: 16),
        dropdownColor: Colors.white,
        onChanged: onChanged,
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
                      ? Colors.grey[400]
                      : Colors.grey[800],
                  decoration:
                      isSelectedElsewhere ? TextDecoration.lineThrough : null,
                )),
          );
        }).toList(),
        validator: (val) {
          if (val == null || val.isEmpty) return 'Please select a question';
          return null;
        });
  }

  Widget _buildDoctorAvailabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Doctor Availability', Icons.schedule),
        const SizedBox(height: 16),

        // Available Days Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.teal[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Available Days',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Select the days when this doctor will be available:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allDays.map((day) {
                  final isSelected = _selectedDays[day] ?? false;
                  return FilterChip(
                    label: Text(_getDayDisplayName(day)),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedDays[day] = selected;
                      });
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal.shade700,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.teal.shade700 : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.teal.shade400 : Colors.grey.shade300,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_selectedDays.values.every((selected) => !selected))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please select at least one available day',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              
              // Service Hours Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.teal.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Service Hours',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set when you arrive at and leave the clinic:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Time Pickers Row
                    Row(
                      children: [
                        // Arrival Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arrival Time',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectArrivalTime(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.teal.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule, color: Colors.teal.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimeOfDay(_arrivalTime),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Departure Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Departure Time',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectDepartureTime(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.teal.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule_send, color: Colors.teal.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimeOfDay(_departureTime),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Time Slot Configuration
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.teal[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Time Slot Configuration',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Enable Time Slot Allocation Toggle
              Row(
                children: [
                  Switch(
                    value: _enableTimeSlotAllocation,
                    onChanged: (bool value) {
                      setState(() {
                        _enableTimeSlotAllocation = value;
                      });
                    },
                    activeColor: Colors.teal[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enable Time Slot-Based Appointments',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (_enableTimeSlotAllocation) ...[
                const SizedBox(height: 16),
                
                // Slot Duration Selection
                Text(
                  'Appointment Slot Duration:',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  children: _availableSlotDurations.map((duration) {
                    final isSelected = _slotDurationMinutes == duration;
                    return FilterChip(
                      label: Text('$duration min'),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _slotDurationMinutes = duration;
                          });
                        }
                      },
                      selectedColor: Colors.teal.shade100,
                      checkmarkColor: Colors.teal.shade700,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.teal.shade700 : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? Colors.teal.shade400 : Colors.grey.shade300,
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Time slots will be automatically generated based on doctor availability and selected duration. This enables precise appointment scheduling and queue management.',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (!_enableTimeSlotAllocation) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Traditional appointment scheduling will be used without predefined time slots. Appointments can be scheduled at any time within working hours.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],),
          ),
      ]);
  }

  String _getDayDisplayName(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Monday';
      case 'tuesday':
        return 'Tuesday';
      case 'wednesday':
        return 'Wednesday';
      case 'thursday':
        return 'Thursday';
      case 'friday':
        return 'Friday';
      case 'saturday':
        return 'Saturday';
      case 'sunday':
        return 'Sunday';
      default:
        return day;
    }
  }

  // Time picker methods for doctor service hours
  Future<void> _selectArrivalTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _arrivalTime) {
      setState(() {
        _arrivalTime = picked;
        // Ensure departure time is after arrival time
        if (_departureTime.hour < _arrivalTime.hour || 
            (_departureTime.hour == _arrivalTime.hour && _departureTime.minute <= _arrivalTime.minute)) {
          _departureTime = TimeOfDay(
            hour: _arrivalTime.hour + 1, 
            minute: _arrivalTime.minute,
          );
          // Handle case where hour goes past 23
          if (_departureTime.hour > 23) {
            _departureTime = const TimeOfDay(hour: 23, minute: 59);
          }
        }
      });
    }
  }

  Future<void> _selectDepartureTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _departureTime) {
      setState(() {
        // Ensure departure time is after arrival time
        if (picked.hour > _arrivalTime.hour || 
            (picked.hour == _arrivalTime.hour && picked.minute > _arrivalTime.minute)) {
          _departureTime = picked;
        } else {
          // Show error if trying to set departure before arrival
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Departure time must be after arrival time'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
}