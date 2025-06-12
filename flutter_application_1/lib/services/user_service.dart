import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_service.dart';

class UserService {
  static Future<String> getUserFullName(String userId) async {
    try {
      final response = await ApiService.get('/users/$userId');
      if (response != null) {
        final user = User.fromJson(response);
        return user.fullName;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user name: $e');
      }
    }
    return 'Unknown Doctor';
  }

  static Future<List<User>> getDoctors() async {
    try {
      final response = await ApiService.get('/users/doctors');
      if (response != null && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => User.fromJson(json))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching doctors: $e');
      }
    }
    return [];
  }
} 