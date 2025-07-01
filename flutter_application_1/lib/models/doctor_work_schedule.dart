import 'package:flutter/material.dart';

/// Simple doctor work schedule with arrival and departure times
class DoctorSchedule {
  final String id;
  final String doctorId;
  final String doctorName;
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
    required this.arrivalTime,
    required this.departureTime,
    required this.isActive,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get formatted time range for display (Arrival - Departure)
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
    final arrivalMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    final departureMinutes = departureTime.hour * 60 + departureTime.minute;
    return (departureMinutes - arrivalMinutes) / 60.0;
  }

  /// Check if current time is within doctor's work hours
  bool isCurrentlyWorking() {
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final arrivalMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    final departureMinutes = departureTime.hour * 60 + departureTime.minute;
    
    return currentMinutes >= arrivalMinutes && currentMinutes <= departureMinutes;
  }

  /// Check if a specific time is within work hours
  bool isTimeWithinWorkHours(TimeOfDay time) {
    final timeMinutes = time.hour * 60 + time.minute;
    final arrivalMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    final departureMinutes = departureTime.hour * 60 + departureTime.minute;
    
    return timeMinutes >= arrivalMinutes && timeMinutes <= departureMinutes;
  }

  /// Create a copy with updated fields
  DoctorSchedule copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
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
    
    return DoctorSchedule(
      id: json['id'],
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'],
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

  /// Create default schedule (7:30 AM arrival - 4:30 PM departure)
  static DoctorSchedule createDefault({
    required String doctorId,
    required String doctorName,
  }) {
    return DoctorSchedule(
      id: 'schedule_${doctorId}_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      doctorName: doctorName,
      arrivalTime: const TimeOfDay(hour: 7, minute: 30),  // 7:30 AM
      departureTime: const TimeOfDay(hour: 16, minute: 30), // 4:30 PM
      isActive: true,
      notes: 'Default work schedule',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DoctorSchedule(id: $id, doctor: $doctorName, time: ${getFormattedTimeRange()}, active: $isActive)';
  }
}
