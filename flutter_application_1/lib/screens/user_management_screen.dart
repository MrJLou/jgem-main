import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAddingUser = false;
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _securityQuestionController =
      TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  String _selectedRole = 'medtech';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _dbHelper.getUsers();
      setState(() => _users = users);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Register new user through the API service
        await ApiService.register(
          username: _usernameController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          role: _selectedRole,
          securityQuestion: _securityQuestionController.text,
          securityAnswer: _securityAnswerController.text,
          birthDate: DateTime.now().toIso8601String(), // Default value
        );

        // Refresh the user list
        await _loadUsers();

        setState(() {
          _isAddingUser = false;
          _usernameController.clear();
          _fullNameController.clear();
          _passwordController.clear();
          _securityQuestionController.clear();
          _securityAnswerController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ApiService.deleteUser(id);
        await _loadUsers();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildUserForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add New User',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _securityQuestionController,
                decoration: const InputDecoration(
                    labelText: 'Security Question',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                    hintText: 'e.g., What was your first pet\'s name?'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a security question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _securityAnswerController,
                decoration: const InputDecoration(
                  labelText: 'Security Answer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.question_answer),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the security answer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                items: ['admin', 'doctor', 'medtech']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child:
                              Text(role[0].toUpperCase() + role.substring(1)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedRole = value!),
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
                    onPressed: () => setState(() => _isAddingUser = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveUser,
                    icon: const Icon(Icons.save),
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

    switch (role) {
      case 'admin':
        badgeColor = Colors.red;
        iconData = Icons.admin_panel_settings;
        break;
      case 'doctor':
        badgeColor = Colors.blue;
        iconData = Icons.medical_services;
        break;
      case 'nurse':
        badgeColor = Colors.green;
        iconData = Icons.healing;
        break;
      case 'medtech':
        badgeColor = Colors.purple;
        iconData = Icons.science;
        break;
      case 'receptionist':
        badgeColor = Colors.orange;
        iconData = Icons.record_voice_over;
        break;
      default:
        badgeColor = Colors.grey;
        iconData = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users',
          ),
        ],
      ),
      body: _isLoading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isAddingUser) _buildUserForm(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'System Users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No users found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _isAddingUser = true),
                                icon: const Icon(Icons.add),
                                label: const Text('Add your first user'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.2),
                                  child: Icon(Icons.person,
                                      color: Theme.of(context).primaryColor),
                                ),
                                title: Text(
                                  user.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.username),
                                    const SizedBox(height: 4),
                                    _buildRoleBadge(user.role),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteUser(user.id),
                                  tooltip: 'Delete User',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: !_isAddingUser
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _isAddingUser = true),
              icon: const Icon(Icons.add),
              label: const Text('Add User'),
              tooltip: 'Add new user',
            )
          : null,
    );
  }
}
