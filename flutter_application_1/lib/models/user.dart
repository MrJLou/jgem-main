class User {
  final String id;
  final String username;
  final String? password;
  final String fullName;
  final String role;
  final String? email;
  final String? contactNumber;
  final String? securityQuestion1;
  final String? securityAnswer1;
  final String? securityQuestion2;
  final String? securityAnswer2;
  final String? securityQuestion3;
  final String? securityAnswer3;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    this.password,
    required this.fullName,
    required this.role,
    this.email,
    this.contactNumber,
    this.securityQuestion1,
    this.securityAnswer1,
    this.securityQuestion2,
    this.securityAnswer2,
    this.securityQuestion3,
    this.securityAnswer3,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? 'unknown_id',
      username: json['username'] as String? ?? 'unknown_username',
      password: json['password'] as String?,
      fullName: json['fullName'] as String? ?? 'Unknown FullName',
      role: json['role'] as String? ?? 'unknown_role',
      email: json['email'] as String?,
      contactNumber: json['contactNumber'] as String?,
      securityQuestion1: json['securityQuestion1'] as String?,
      securityAnswer1: json['securityAnswer1'] as String?,
      securityQuestion2: json['securityQuestion2'] as String?,
      securityAnswer2: json['securityAnswer2'] as String?,
      securityQuestion3: json['securityQuestion3'] as String?,
      securityAnswer3: json['securityAnswer3'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (password != null) 'password': password,
      'fullName': fullName,
      'role': role,
      'email': email,
      'contactNumber': contactNumber,
      if (securityQuestion1 != null) 'securityQuestion1': securityQuestion1,
      if (securityAnswer1 != null) 'securityAnswer1': securityAnswer1,
      if (securityQuestion2 != null) 'securityQuestion2': securityQuestion2,
      if (securityAnswer2 != null) 'securityAnswer2': securityAnswer2,
      if (securityQuestion3 != null) 'securityQuestion3': securityQuestion3,
      if (securityAnswer3 != null) 'securityAnswer3': securityAnswer3,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
