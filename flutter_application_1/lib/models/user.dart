import 'dart:math';
import 'package:flutter/material.dart';

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
  
  // Doctor-specific fields for work schedule
  final Map<String, bool>? workingDays; // Which days doctor works (monday: true, etc.)
  final TimeOfDay? arrivalTime;  // When doctor arrives at clinic
  final TimeOfDay? departureTime; // When doctor leaves clinic

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
    this.workingDays,
    this.arrivalTime,
    this.departureTime,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse working days if available
    Map<String, bool>? workingDays;
    if (json['workingDays'] != null) {
      if (json['workingDays'] is String) {
        // Parse from JSON string
        final workingDaysStr = json['workingDays'] as String;
        workingDays = <String, bool>{};
        final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        final daysList = workingDaysStr.split(',');
        for (final day in days) {
          workingDays[day] = daysList.contains(day);
        }
      } else if (json['workingDays'] is Map) {
        workingDays = Map<String, bool>.from(json['workingDays']);
      }
    }

    // Parse arrival and departure times
    TimeOfDay? arrivalTime;
    TimeOfDay? departureTime;
    
    if (json['arrivalTime'] != null) {
      final arrivalParts = json['arrivalTime'].toString().split(':');
      if (arrivalParts.length >= 2) {
        arrivalTime = TimeOfDay(
          hour: int.parse(arrivalParts[0]),
          minute: int.parse(arrivalParts[1]),
        );
      }
    }
    
    if (json['departureTime'] != null) {
      final departureParts = json['departureTime'].toString().split(':');
      if (departureParts.length >= 2) {
        departureTime = TimeOfDay(
          hour: int.parse(departureParts[0]),
          minute: int.parse(departureParts[1]),
        );
      }
    }

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
      workingDays: workingDays,
      arrivalTime: arrivalTime,
      departureTime: departureTime,
    );
  }

  Map<String, dynamic> toJson() {
    // Convert working days to comma-separated string
    String? workingDaysStr;
    if (workingDays != null) {
      final workingList = workingDays!.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      workingDaysStr = workingList.join(',');
    }

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
      if (workingDaysStr != null) 'workingDays': workingDaysStr,
      if (arrivalTime != null) 'arrivalTime': '${arrivalTime!.hour.toString().padLeft(2, '0')}:${arrivalTime!.minute.toString().padLeft(2, '0')}',
      if (departureTime != null) 'departureTime': '${departureTime!.hour.toString().padLeft(2, '0')}:${departureTime!.minute.toString().padLeft(2, '0')}',
    };
  }

  // Generate a 6-digit ID
  static String generateId() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // Generates number between 100000-999999
  }

  // Format an existing ID to ensure it's 6 digits
  static String formatId(String id) {
    // Remove any non-numeric characters
    final numericId = id.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If the ID is longer than 6 digits, take the last 6
    if (numericId.length > 6) {
      return numericId.substring(numericId.length - 6);
    }
    
    // If the ID is shorter than 6 digits, pad with zeros
    return numericId.padLeft(6, '0');
  }

  // Helper methods for doctor schedule functionality
  
  /// Check if doctor works on a specific day
  bool worksOnDay(String day) {
    if (workingDays == null) return false;
    return workingDays![day.toLowerCase()] ?? false;
  }

  /// Check if doctor is currently working
  bool isCurrentlyWorking() {
    if (arrivalTime == null || departureTime == null) return false;
    
    final now = TimeOfDay.now();
    return isTimeWithinWorkHours(now);
  }

  /// Check if a specific time is within work hours
  bool isTimeWithinWorkHours(TimeOfDay time) {
    if (arrivalTime == null || departureTime == null) return false;
    
    final timeMinutes = time.hour * 60 + time.minute;
    final arrivalMinutes = arrivalTime!.hour * 60 + arrivalTime!.minute;
    final departureMinutes = departureTime!.hour * 60 + departureTime!.minute;
    
    return timeMinutes >= arrivalMinutes && timeMinutes <= departureMinutes;
  }

  /// Get formatted time range for display
  String getFormattedTimeRange() {
    if (arrivalTime == null || departureTime == null) return 'Not set';
    return '${_formatTime(arrivalTime!)} - ${_formatTime(departureTime!)}';
  }

  String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  /// Get list of working days
  List<String> getWorkingDaysList() {
    if (workingDays == null) return [];
    return workingDays!.entries
        .where((entry) => entry.value)
        .map((entry) => _capitalizeFirst(entry.key))
        .toList();
  }

  String _capitalizeFirst(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Get duration in hours
  double getDurationInHours() {
    if (arrivalTime == null || departureTime == null) return 0.0;
    
    final startMinutes = arrivalTime!.hour * 60 + arrivalTime!.minute;
    final endMinutes = departureTime!.hour * 60 + departureTime!.minute;
    return (endMinutes - startMinutes) / 60.0;
  }
}
