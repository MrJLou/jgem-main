import 'package:flutter/material.dart';

/// Simple doctor work schedule with arrival/departure times and working days
class DoctorSchedule {
  final String id;
  final String doctorId;
  final String doctorName;
  final Map<String, bool> workingDays; // Which days doctor works (monday: true, etc.)
  final TimeOfDay arrivalTime;  // When doctor arrives at clinic
  final TimeOfDay departureTime; // When doctor leaves clinic
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoctorSchedule({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.workingDays,
    required this.arrivalTime,
    required this.departureTime,
    required this.isActive,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get formatted time range for display
  String getFormattedTimeRange() {
    return '${_formatTime(arrivalTime)} - ${_formatTime(departureTime)}';
  }

  String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  /// Get duration in hours
  double getDurationInHours() {
    final startMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    final endMinutes = departureTime.hour * 60 + departureTime.minute;
    return (endMinutes - startMinutes) / 60.0;
  }

  /// Get list of working days
  List<String> getWorkingDaysList() {
    return workingDays.entries
        .where((entry) => entry.value)
        .map((entry) => _capitalizeFirst(entry.key))
        .toList();
  }

  String _capitalizeFirst(String str) {
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Check if a specific time is within work hours
  bool isTimeWithinWorkHours(TimeOfDay time) {
    final timeMinutes = time.hour * 60 + time.minute;
    final arrivalMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    final departureMinutes = departureTime.hour * 60 + departureTime.minute;
    
    return timeMinutes >= arrivalMinutes && timeMinutes <= departureMinutes;
  }

  /// Check if doctor is currently working
  bool isCurrentlyWorking() {
    final now = TimeOfDay.now();
    return isTimeWithinWorkHours(now);
  }

  /// Check if doctor works on a specific day
  bool worksOnDay(String day) {
    return workingDays[day.toLowerCase()] ?? false;
  }

  /// Create a copy with updated fields
  DoctorSchedule copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    Map<String, bool>? workingDays,
    TimeOfDay? arrivalTime,
    TimeOfDay? departureTime,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorSchedule(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      workingDays: workingDays ?? this.workingDays,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'working_days': workingDays.entries.map((e) => '${e.key}:${e.value ? 1 : 0}').join(','),
      'arrival_time': '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}',
      'departure_time': '${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}',
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory DoctorSchedule.fromJson(Map<String, dynamic> json) {
    final arrivalTimeParts = json['arrival_time'].split(':');
    final departureTimeParts = json['departure_time'].split(':');
    
    final workingDaysMap = <String, bool>{};
    if (json['working_days'] is String) {
      // Parse format like "monday:1,tuesday:0,wednesday:1"
      final dayPairs = (json['working_days'] as String).split(',');
      for (final pair in dayPairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          workingDaysMap[parts[0]] = parts[1] == '1';
        }
      }
    }
    
    return DoctorSchedule(
      id: json['id'],
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'],
      workingDays: workingDaysMap,
      arrivalTime: TimeOfDay(
        hour: int.parse(arrivalTimeParts[0]),
        minute: int.parse(arrivalTimeParts[1]),
      ),
      departureTime: TimeOfDay(
        hour: int.parse(departureTimeParts[0]),
        minute: int.parse(departureTimeParts[1]),
      ),
      isActive: json['is_active'] == 1,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Create default schedule (Monday-Saturday, 7:30 AM - 4:30 PM)
  static DoctorSchedule createDefault({
    required String doctorId,
    required String doctorName,
  }) {
    return DoctorSchedule(
      id: 'schedule_${doctorId}_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      doctorName: doctorName,
      workingDays: {
        'monday': true,
        'tuesday': true,
        'wednesday': true,
        'thursday': true,
        'friday': true,
        'saturday': true,
        'sunday': false,
      },
      arrivalTime: const TimeOfDay(hour: 7, minute: 30),
      departureTime: const TimeOfDay(hour: 16, minute: 30),
      isActive: true,
      notes: 'Default schedule',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DoctorSchedule(id: $id, doctor: $doctorName, days: ${getWorkingDaysList()}, time: ${getFormattedTimeRange()})';
  }
}
