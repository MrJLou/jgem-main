import 'package:flutter/material.dart';

class PasswordValidator {
  // Password validation with different strength levels
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter a password';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for password complexity
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (!hasUppercase) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!hasDigits) {
      return 'Password must contain at least one number';
    }

    if (!hasSpecialChars) {
      return 'Password must contain at least one special character';
    }

    return null; // Valid password
  }

  // Visual feedback for password strength
  static Widget buildPasswordStrengthIndicator(String password) {
    // Calculate strength
    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    // Colors for different strength levels
    Color strengthColor = Colors.red;
    String strengthText = 'Weak';

    if (strength == 4) {
      strengthColor = Colors.green;
      strengthText = 'Strong';
    } else if (strength == 3) {
      strengthColor = Colors.orange;
      strengthText = 'Good';
    } else if (strength == 2) {
      strengthColor = Colors.yellow;
      strengthText = 'Fair';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength / 4,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Password Strength: $strengthText',
          style: TextStyle(
            color: strengthColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
