import 'package:flutter/material.dart';

class UserRegistrationScreen extends StatefulWidget {
  @override
  _UserRegistrationScreenState createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _securityAnswerController = TextEditingController();
  
  String _selectedSecurityQuestion = 'What was your first pet\'s name?';
  String _selectedAccessLevel = 'Staff';
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _securityQuestions = [
    'What was your first pet\'s name?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your first school?',
    'What was your childhood nickname?'
  ];

  final List<String> _accessLevels = [
    'Staff',
    'Doctor',
    'Administrator',
    'Super Admin'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('User Registration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First Name
              _buildInputField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Last Name
              _buildInputField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Mobile Number
              _buildInputField(
                controller: _mobileController,
                label: 'Mobile Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (!RegExp(r'^[0-9]{10,}$').hasMatch(value)) {
                    return 'Please enter a valid mobile number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Username
              _buildInputField(
                controller: _usernameController,
                label: 'Username',
                icon: Icons.account_circle,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter username';
                  }
                  if (value.length < 4) {
                    return 'Username must be at least 4 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Password
              _buildPasswordField(
                controller: _passwordController,
                label: 'Password',
                obscureText: _obscurePassword,
                onToggle: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Confirm Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                obscureText: _obscureConfirmPassword,
                onToggle: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Security Question
              _buildDropdownField(
                value: _selectedSecurityQuestion,
                items: _securityQuestions,
                label: 'Select Security Question',
                icon: Icons.security,
                onChanged: (value) {
                  setState(() {
                    _selectedSecurityQuestion = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Security Answer
              _buildInputField(
                controller: _securityAnswerController,
                label: 'Security Answer',
                icon: Icons.question_answer,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter security answer';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Level of Access
              _buildDropdownField(
                value: _selectedAccessLevel,
                items: _accessLevels,
                label: 'Level of Access',
                icon: Icons.lock,
                onChanged: (value) {
                  setState(() {
                    _selectedAccessLevel = value!;
                  });
                },
              ),
              SizedBox(height: 30),
              
              // Register Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: Size(double.infinity, 50),
                  elevation: 3,
                  shadowColor: Colors.teal.withOpacity(0.3),
                ),
                child: Text(
                  'Register User',
                  style: TextStyle(
                    fontSize: 16, 
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Colors.teal[800]),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[600]),
        prefixIcon: Icon(icon, color: Colors.teal[600]),
        filled: true,
        fillColor: Colors.teal[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: Colors.teal[800]),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[600]),
        prefixIcon: Icon(Icons.lock, color: Colors.teal[600]),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: Colors.teal[600],
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.teal[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.teal[50],
      style: TextStyle(color: Colors.teal[800]),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[600]),
        prefixIcon: Icon(icon, color: Colors.teal[600]),
        filled: true,
        fillColor: Colors.teal[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: TextStyle(color: Colors.teal[800])),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Here you would typically send the data to your backend
      final userData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'mobile': _mobileController.text,
        'username': _usernameController.text,
        'password': _passwordController.text,
        'securityQuestion': _selectedSecurityQuestion,
        'securityAnswer': _securityAnswerController.text,
        'accessLevel': _selectedAccessLevel,
      };

      print(userData); // For debugging

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User registered successfully!'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Clear the form after successful submission
      _formKey.currentState?.reset();
      setState(() {
        _selectedSecurityQuestion = 'What was your first pet\'s name?';
        _selectedAccessLevel = 'Staff';
        _obscurePassword = true;
        _obscureConfirmPassword = true;
      });
    }
  }
}