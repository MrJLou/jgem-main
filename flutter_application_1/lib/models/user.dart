class User {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      fullName: json['fullName'],
      role: json['role'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}