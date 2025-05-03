import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/appointment.dart';
import '../models/user.dart';

class ApiService {
  static const String _baseUrl = 'https://your-api-endpoint.com/api';
  static String? _authToken;

  // Authentication Methods (keep your existing ones)
  static Future<Map<String, dynamic>> login(
      String username, String password, String accessLevel) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'accessLevel': accessLevel,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _authToken = data['token'];
      return data;
    } else {
      throw Exception('Failed to login: ${response.statusCode}');
    }
  }

  static Future<void> register({
    required String fullName,
    required String username,
    required String password,
    required String birthDate,
    required String role,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'username': username,
        'password': password,
        'birthDate': birthDate,
        'role': role,
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  static Future<bool> resetPassword(
      String username,
      String securityQuestion,
      String securityAnswer,
      String newPassword) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to reset password: ${response.statusCode}');
    }
  }

  // Enhanced Appointment Methods
  static Future<List<Appointment>> getAppointments(DateTime date) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/appointments?date=${date.toIso8601String()}'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Appointment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load appointments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  static Future<Appointment> saveAppointment(Appointment appointment) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/appointments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode(appointment.toJson()),
      );

      if (response.statusCode == 201) {
        return Appointment.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to save appointment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  static Future<void> updateAppointmentStatus(String id, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/appointments/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  static Future<bool> deleteAppointment(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/appointments/$id'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete appointment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  // User Management Methods (keep your existing ones)
  static Future<List<User>> getUsers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users'),
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<User> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
      body: jsonEncode(userData),
    );

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create user');
    }
  }

  static Future<bool> deleteUser(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$id'),
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to delete user');
    }
  }

  // Helper method to clear auth token (for logout)
  static void clearAuthToken() {
    _authToken = null;
  }
}