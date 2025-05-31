import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isAddingUser = false;
  
  // Dummy data for demonstration - in real app, this would come from a database
  List<Map<String, dynamic>> _users = [
    {
      'name': 'Dr. John Smith',
      'role': 'Doctor',
      'status': 'Active',
      'email': 'john.smith@clinic.com',
      'username': 'dr.smith',
    },
    {
      'name': 'Nurse Sarah',
      'role': 'Nurse',
      'status': 'Active',
      'email': 'sarah@clinic.com',
      'username': 'nurse.sarah',
    },
    {
      'name': 'Admin Mike',
      'role': 'Administrator',
      'status': 'Inactive',
      'email': 'mike@clinic.com',
      'username': 'admin.mike',
    },
  ];

  List<String> _roles = [
    'Doctor',
    'Nurse',
    'Administrator',
    'Receptionist',
    'Lab Technician'
  ];

  Map<String, Map<String, bool>> _rolePermissions = {
    'Doctor': {
      'View Patient Records': true,
      'Edit Patient Records': true,
      'Schedule Appointments': true,
      'Access Lab Results': true,
      'Prescribe Medication': true,
    },
    'Nurse': {
      'View Patient Records': true,
      'Edit Patient Records': true,
      'Schedule Appointments': true,
      'Access Lab Results': true,
      'Prescribe Medication': false,
    },
    'Administrator': {
      'View Patient Records': true,
      'Edit Patient Records': true,
      'Schedule Appointments': true,
      'Access Lab Results': true,
      'Manage Users': true,
    },
    'Receptionist': {
      'View Patient Records': true,
      'Edit Patient Records': false,
      'Schedule Appointments': true,
      'Access Lab Results': false,
      'Manage Billing': true,
    },
    'Lab Technician': {
      'View Patient Records': true,
      'Edit Patient Records': false,
      'Schedule Appointments': false,
      'Access Lab Results': true,
      'Manage Lab Tests': true,
    },
  };

  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _filteredUsers = List.from(_users);
    _searchController.addListener(_filterUsers);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes to show/hide search bar
    });
  }

  void _filterUsers() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          return user['name']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                 user['role']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                 user['email']!.toLowerCase().contains(_searchController.text.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        elevation: 0,
        title: Text(
          'User Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Users'),
            Tab(text: 'Roles'),
            Tab(text: 'Permissions'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 45,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(fontSize: 14),
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _filterUsers();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersList(),
                _buildRolesTab(),
                _buildPermissionsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isAddingUser = true;
                });
                _showAddUserDialog();
              },
              backgroundColor: Colors.teal[700],
              child: Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal[50],
              child: Text(
                user['name']!.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.teal[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user['name']!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal[900],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['email']!,
                  style: TextStyle(
                    color: Colors.grey[800],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.badge,
                      size: 16,
                      color: Colors.teal[700],
                    ),
                    SizedBox(width: 4),
                    Text(
                      user['role']!,
                      style: TextStyle(
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: user['status'] == 'Active'
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: user['status'] == 'Active'
                          ? Colors.green[300]!
                          : Colors.red[300]!,
                    ),
                  ),
                  child: Text(
                    user['status']!,
                    style: TextStyle(
                      color: user['status'] == 'Active'
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[700],
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditUserDialog(user);
                        break;
                      case 'delete':
                        _showDeleteUserDialog(user);
                        break;
                      case 'toggle_status':
                        _toggleUserStatus(user);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(
                          Icons.edit,
                          color: Colors.teal[700],
                        ),
                        title: Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.teal[900],
                          ),
                        ),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: ListTile(
                        leading: Icon(
                          user['status'] == 'Active'
                              ? Icons.block
                              : Icons.check_circle,
                          color: user['status'] == 'Active'
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                        title: Text(
                          user['status'] == 'Active'
                              ? 'Deactivate'
                              : 'Activate',
                          style: TextStyle(
                            color: user['status'] == 'Active'
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete,
                          color: Colors.red[700],
                        ),
                        title: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red[700],
                          ),
                        ),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () => _showUserDetailsDialog(user),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', user['name']!),
            _buildDetailRow('Username', user['username']!),
            _buildDetailRow('Email', user['email']!),
            _buildDetailRow('Role', user['role']!),
            _buildDetailRow('Status', user['status']!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
            ),
            child: Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal[900],
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String username = '';
    String email = '';
    String role = _roles.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New User'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onSaved: (value) => name = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                  onSaved: (value) => username = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onSaved: (value) => email = value!,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  value: role,
                  items: _roles.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r),
                  )).toList(),
                  onChanged: (value) => role = value!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isAddingUser = false;
              });
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                setState(() {
                  _users.add({
                    'name': name,
                    'username': username,
                    'email': email,
                    'role': role,
                    'status': 'Active',
                  });
                  _filterUsers();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
            ),
            child: Text('Add User'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    String name = user['name'];
    String username = user['username'];
    String email = user['email'];
    String role = user['role'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onSaved: (value) => name = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  initialValue: username,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                  onSaved: (value) => username = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  initialValue: email,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onSaved: (value) => email = value!,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  value: role,
                  items: _roles.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r),
                  )).toList(),
                  onChanged: (value) => role = value!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                setState(() {
                  user['name'] = name;
                  user['username'] = username;
                  user['email'] = email;
                  user['role'] = role;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _users.remove(user);
                _filterUsers();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User deleted successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(Map<String, dynamic> user) {
    setState(() {
      user['status'] = user['status'] == 'Active' ? 'Inactive' : 'Active';
    });
  }

  Widget _buildRolesTab() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.teal[700]),
                SizedBox(width: 12),
                Text(
                  'Manage User Roles',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 24),
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final permissions = _rolePermissions[role]!;
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      leading: Icon(
                        Icons.badge,
                        color: Colors.teal[700],
                      ),
                      title: Text(
                        role,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[200]!,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Permissions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showEditRoleDialog(role),
                                    icon: Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.teal[700],
                                    ),
                                    label: Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Colors.teal[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: permissions.entries.map((entry) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: entry.value
                                          ? Colors.teal[50]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: entry.value
                                            ? Colors.teal[300]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          entry.value
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 16,
                                          color: entry.value
                                              ? Colors.teal[700]
                                              : Colors.grey[500],
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: entry.value
                                                ? Colors.teal[700]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton.icon(
              onPressed: _showAddRoleDialog,
              icon: Icon(Icons.add),
              label: Text('Add New Role'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, color: Colors.teal[700]),
                SizedBox(width: 12),
                Text(
                  'Permission Matrix',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(24),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dataTableTheme: DataTableThemeData(
                            headingTextStyle: TextStyle(
                              color: Colors.teal[900],
                              fontWeight: FontWeight.bold,
                            ),
                            dataTextStyle: TextStyle(
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                          columns: [
                            DataColumn(
                              label: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('Permission'),
                              ),
                            ),
                            ..._roles.map((role) => DataColumn(
                              label: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(role),
                              ),
                            )).toList(),
                          ],
                          rows: _getAllPermissions().map((permission) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    width: 200,
                                    child: Text(
                                      permission,
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ),
                                ..._roles.map((role) {
                                  bool hasPermission = _rolePermissions[role]?[permission] ?? false;
                                  return DataCell(
                                    Center(
                                      child: Switch(
                                        value: hasPermission,
                                        onChanged: (value) {
                                          setState(() {
                                            _rolePermissions[role]![permission] = value;
                                          });
                                        },
                                        activeColor: Colors.teal[700],
                                        activeTrackColor: Colors.teal[100],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          }).toList(),
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
    );
  }

  Set<String> _getAllPermissions() {
    Set<String> allPermissions = {};
    for (var rolePermissions in _rolePermissions.values) {
      allPermissions.addAll(rolePermissions.keys);
    }
    return allPermissions;
  }

  void _showAddRoleDialog() {
    final formKey = GlobalKey<FormState>();
    String roleName = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Role'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Role Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a role name';
                  }
                  if (_roles.contains(value)) {
                    return 'This role already exists';
                  }
                  return null;
                },
                onSaved: (value) => roleName = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                setState(() {
                  _roles.add(roleName);
                  _rolePermissions[roleName] = Map.fromIterable(
                    _getAllPermissions(),
                    value: (_) => false,
                  );
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Role added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
            ),
            child: Text('Add Role'),
          ),
        ],
      ),
    );
  }

  void _showEditRoleDialog(String role) {
    final permissions = _rolePermissions[role]!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Role: $role'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[900],
                ),
              ),
              SizedBox(height: 16),
              ...permissions.entries.map((entry) => CheckboxListTile(
                title: Text(entry.key),
                value: entry.value,
                onChanged: (value) {
                  setState(() {
                    permissions[entry.key] = value!;
                  });
                },
                activeColor: Colors.teal,
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Role permissions updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
} 