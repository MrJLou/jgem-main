import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  UserManagementScreenState createState() => UserManagementScreenState();
}

class UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAddingUser = false;
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();

  // Removed TextEditControllers for security questions
  final TextEditingController _securityAnswer1Controller =
      TextEditingController();
  final TextEditingController _securityAnswer2Controller =
      TextEditingController();
  final TextEditingController _securityAnswer3Controller =
      TextEditingController();

  String _selectedRole = 'medtech';
  String? _formErrorMessage;

  // Security Questions state and list
  final List<String> _securityQuestions = [
    'What was your first pet\'s name?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your first school?',
    'What is your favorite book?',
    'What was the model of your first car?'
  ];
  late String _selectedSecurityQuestion1;
  late String _selectedSecurityQuestion2;
  late String _selectedSecurityQuestion3;

  @override
  void initState() {
    super.initState();
    // Initialize with distinct default questions
    _selectedSecurityQuestion1 =
        _securityQuestions.isNotEmpty ? _securityQuestions[0] : '';
    _selectedSecurityQuestion2 =
        _securityQuestions.length > 1 ? _securityQuestions[1] : '';
    _selectedSecurityQuestion3 =
        _securityQuestions.length > 2 ? _securityQuestions[2] : '';
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final users = await _dbHelper.getUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearAddUserForm() {
    _usernameController.clear();
    _fullNameController.clear();
    _passwordController.clear();
    _emailController.clear();
    _contactNumberController.clear();
    _securityAnswer1Controller.clear();
    _securityAnswer2Controller.clear();
    _securityAnswer3Controller.clear();
    if (_securityQuestions.length >= 3) {
      _selectedSecurityQuestion1 = _securityQuestions[0];
      _selectedSecurityQuestion2 = _securityQuestions[1];
      _selectedSecurityQuestion3 = _securityQuestions[2];
    } else {
      _selectedSecurityQuestion1 =
          _securityQuestions.isNotEmpty ? _securityQuestions[0] : '';
      _selectedSecurityQuestion2 =
          _securityQuestions.length > 1 ? _securityQuestions[1] : '';
      _selectedSecurityQuestion3 =
          _securityQuestions.length > 2 ? _securityQuestions[2] : '';
    }
    _selectedRole = 'medtech';
    _formErrorMessage = null;
    if (mounted) {
      setState(() {}); // Refresh UI for dropdowns
    }
  }

  Future<void> _saveUser() async {
    if (!mounted) return;
    setState(() {
      _formErrorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      if (_selectedSecurityQuestion1 == _selectedSecurityQuestion2 ||
          _selectedSecurityQuestion1 == _selectedSecurityQuestion3 ||
          _selectedSecurityQuestion2 == _selectedSecurityQuestion3) {
        if (mounted) {
          setState(() {
            _formErrorMessage =
                'Please select three unique security questions.';
          });
        }
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
          username: _usernameController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          email: _emailController.text,
          contactNumber: _contactNumberController.text,
          role: _selectedRole,
          securityQuestion1: _selectedSecurityQuestion1,
          securityAnswer1: hashedSecurityAnswer1,
          securityQuestion2: _selectedSecurityQuestion2,
          securityAnswer2: hashedSecurityAnswer2,
          securityQuestion3: _selectedSecurityQuestion3,
          securityAnswer3: hashedSecurityAnswer3,
        );

        await _loadUsers();

        if (mounted) {
          setState(() {
            _isAddingUser = false;
            _clearAddUserForm();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create user: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
            'Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await ApiService.deleteUser(id);
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  InputDecoration _formFieldDecoration(
      {required String label, required IconData iconData}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.teal[700]),
      prefixIcon: Icon(iconData, color: Colors.teal[700]),
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
    );
  }

  Widget _buildSecurityQuestionDropdown({
    required String label,
    required String currentValue,
    required ValueChanged<String?> onChanged,
    required List<String> allQuestions,
  }) {
    String? displayValue =
        allQuestions.contains(currentValue) ? currentValue : null;
    if (currentValue.isEmpty && allQuestions.isNotEmpty) {
      // Ensure a valid initial selection if current value is empty
      displayValue = null;
    }

    return DropdownButtonFormField<String>(
      decoration:
          _formFieldDecoration(label: label, iconData: Icons.shield_outlined),
      value: displayValue,
      items: allQuestions.map((String question) {
        bool isSelectedElsewhere = false;
        if (label == 'Security Question 1') {
          isSelectedElsewhere = question == _selectedSecurityQuestion2 ||
              question == _selectedSecurityQuestion3;
        } else if (label == 'Security Question 2') {
          isSelectedElsewhere = question == _selectedSecurityQuestion1 ||
              question == _selectedSecurityQuestion3;
        } else if (label == 'Security Question 3') {
          isSelectedElsewhere = question == _selectedSecurityQuestion1 ||
              question == _selectedSecurityQuestion2;
        }

        return DropdownMenuItem<String>(
          value: question,
          enabled: !isSelectedElsewhere,
          child: Text(
            question,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelectedElsewhere ? Colors.grey[400] : Colors.grey[800],
              decoration:
                  isSelectedElsewhere ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      style: TextStyle(color: Colors.grey[800], fontSize: 16),
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.teal[700]),
      iconSize: 28,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a question';
        }
        return null;
      },
    );
  }

  Widget _buildUserForm() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title is now in AppBar
              const SizedBox(height: 10),
              if (_formErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _formErrorMessage!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextFormField(
                controller: _usernameController,
                decoration: _formFieldDecoration(
                    label: 'Username', iconData: Icons.person_outline_rounded),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter username';
                  }
                  if (value.length < 4) {
                    return 'Username must be at least 4 characters';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: _formFieldDecoration(
                    label: 'Full Name', iconData: Icons.badge_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  if (value.length < 3) {
                    return 'Full name must be at least 3 characters';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: _formFieldDecoration(
                    label: 'Email Address', iconData: Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null &&
                      !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactNumberController,
                decoration: _formFieldDecoration(
                    label: 'Contact Number', iconData: Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: _formFieldDecoration(
                        label: 'Password', iconData: Icons.lock_outline_rounded)
                    .copyWith(hintText: 'Min. 6 characters'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 20),
              Text("Security Questions & Answers",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.teal[800])),
              const SizedBox(height: 15),

              _buildSecurityQuestionDropdown(
                label: 'Security Question 1',
                currentValue: _selectedSecurityQuestion1,
                allQuestions: _securityQuestions,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSecurityQuestion1 = newValue;
                      // Ensure other selections are updated if they became invalid
                      if (_selectedSecurityQuestion1 ==
                          _selectedSecurityQuestion2) {
                        _selectedSecurityQuestion2 =
                            _securityQuestions.firstWhere(
                                (q) =>
                                    q != _selectedSecurityQuestion1 &&
                                    q != _selectedSecurityQuestion3,
                                orElse: () => '');
                      }
                      if (_selectedSecurityQuestion1 ==
                          _selectedSecurityQuestion3) {
                        _selectedSecurityQuestion3 =
                            _securityQuestions.firstWhere(
                                (q) =>
                                    q != _selectedSecurityQuestion1 &&
                                    q != _selectedSecurityQuestion2,
                                orElse: () => '');
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _securityAnswer1Controller,
                decoration: _formFieldDecoration(
                    label: 'Answer for Security Question 1',
                    iconData: Icons.question_answer_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the answer for question 1';
                  }
                  if (value.length < 2) {
                    return 'Answer must be at least 2 characters';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),

              _buildSecurityQuestionDropdown(
                label: 'Security Question 2',
                currentValue: _selectedSecurityQuestion2,
                allQuestions: _securityQuestions,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSecurityQuestion2 = newValue;
                      if (_selectedSecurityQuestion2 ==
                          _selectedSecurityQuestion1) {
                        _selectedSecurityQuestion1 =
                            _securityQuestions.firstWhere(
                                (q) =>
                                    q != _selectedSecurityQuestion2 &&
                                    q != _selectedSecurityQuestion3,
                                orElse: () => '');
                      }
                      if (_selectedSecurityQuestion2 ==
                          _selectedSecurityQuestion3) {
                        _selectedSecurityQuestion3 =
                            _securityQuestions.firstWhere(
                                (q) =>
                                    q != _selectedSecurityQuestion1 &&
                                    q != _selectedSecurityQuestion2,
                                orElse: () => '');
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _securityAnswer2Controller,
                decoration: _formFieldDecoration(
                    label: 'Answer for Security Question 2',
                    iconData: Icons.question_answer_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the answer for question 2';
                  }
                  if (value.length < 2) {
                    return 'Answer must be at least 2 characters';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),

              _buildSecurityQuestionDropdown(
                label: 'Security Question 3',
                currentValue: _selectedSecurityQuestion3,
                allQuestions: _securityQuestions,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSecurityQuestion3 = newValue;
                      if (_selectedSecurityQuestion3 ==
                          _selectedSecurityQuestion1) {
                        _selectedSecurityQuestion1 =
                            _securityQuestions.firstWhere(
                                (q) =>
                                    q != _selectedSecurityQuestion2 &&
                                    q != _selectedSecurityQuestion3,
                                orElse: () => '');
                      }
                      if (_selectedSecurityQuestion3 ==
                          _selectedSecurityQuestion2) {
                        _selectedSecurityQuestion2 =
                            _securityQuestions.firstWhere(
                                (q) =>
                                    q != _selectedSecurityQuestion1 &&
                                    q != _selectedSecurityQuestion3,
                                orElse: () => '');
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _securityAnswer3Controller,
                decoration: _formFieldDecoration(
                    label: 'Answer for Security Question 3',
                    iconData: Icons.question_answer_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the answer for question 3';
                  }
                  if (value.length < 2) {
                    return 'Answer must be at least 2 characters';
                  }
                  return null;
                },
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: _formFieldDecoration(
                    label: 'Role',
                    iconData: Icons.admin_panel_settings_outlined),
                items: ['doctor', 'medtech']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child:
                              Text(role[0].toUpperCase() + role.substring(1)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
                style: TextStyle(color: Colors.grey[800], fontSize: 16),
                dropdownColor: Colors.white,
                icon: Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.teal[700]),
                iconSize: 28,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isAddingUser = false;
                        _clearAddUserForm();
                      });
                    },
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveUser,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...')
                            ],
                          )
                        : const Text('Save User'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600], // Teal color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    IconData iconData;
    Theme.of(context);

    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.redAccent.shade400; // More vibrant red
        iconData = Icons.shield_outlined; // More appropriate for admin
        break;
      case 'doctor':
        badgeColor = Colors.blueAccent.shade400;
        iconData = Icons.medical_services_outlined;
        break;
      case 'medtech':
        badgeColor = Colors.purpleAccent.shade400;
        iconData = Icons.biotech_outlined; // More specific for medtech
        break;
      default:
        badgeColor = Colors.grey.shade600;
        iconData = Icons.person_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(31),
        borderRadius: BorderRadius.circular(20), // More rounded
        border: Border.all(color: badgeColor.withAlpha(128), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 10, // Slightly smaller for a neater look
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryTeal = Colors.teal[700]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAddingUser ? 'Add New User' : 'User Management',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: primaryTeal,
        leading: _isAddingUser
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isAddingUser = false;
                    _clearAddUserForm();
                  });
                },
                tooltip: 'Back to User List',
              )
            : null,
        actions: [
          if (!_isAddingUser)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _loadUsers,
              tooltip: 'Refresh Users',
            ),
        ],
        elevation: _isAddingUser
            ? 0
            : 4, // No shadow when form is open for a flatter look
      ),
      body: _isLoading && _users.isEmpty && !_isAddingUser
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom:
                        _isAddingUser ? 20 : 80), // Adjust padding based on FAB
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Important for SingleChildScrollView
                  children: [
                    if (_isAddingUser) _buildUserForm(),
                    if (!_isAddingUser)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'System Users',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: primaryTeal,
                                  ),
                            ),
                            Text('${_users.length} User(s)',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    if (!_isAddingUser)
                      _users.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 50.0, horizontal: 20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_alt_outlined,
                                        size: 80, color: Colors.grey[400]),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No users found in the system.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            primaryTeal, // Teal color
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                      ),
                                      onPressed: () => setState(() {
                                        _clearAddUserForm();
                                        _isAddingUser = true;
                                      }),
                                      icon: const Icon(
                                          Icons.person_add_alt_1_outlined),
                                      label: const Text('Add First User',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _users.length,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  elevation: 2.5,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          primaryTeal.withAlpha(31),
                                      child: Icon(Icons.account_circle_outlined,
                                          color: primaryTeal, size: 28),
                                    ),
                                    title: Text(
                                      user.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(user.username,
                                            style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 14)),
                                        const SizedBox(height: 6),
                                        _buildRoleBadge(user.role),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete_sweep_outlined,
                                          color: Colors.redAccent.shade200,
                                          size: 26),
                                      onPressed: () => _deleteUser(user.id),
                                      tooltip: 'Delete User',
                                    ),
                                  ),
                                );
                              },
                            ),
                  ],
                ),
              ),
            ),
      floatingActionButton: !_isAddingUser &&
              _users.isNotEmpty // Show FAB only if not adding and users exist
          ? FloatingActionButton.extended(
              onPressed: () => setState(() {
                _clearAddUserForm();
                _isAddingUser = true;
              }),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add User',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              tooltip: 'Add New User',
              backgroundColor: primaryTeal, // Teal color
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
