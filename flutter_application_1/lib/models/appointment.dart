import 'package:flutter/material.dart'; // Add this import at the top

class Appointment {
  final String id;
  final String patientId;
  final DateTime date;
  final TimeOfDay time;
  final String doctorId;
  final String? serviceId;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final String? createdById;

  // Added new fields
  final String? consultationType;
  final int? durationMinutes;

  Appointment({
    required this.id,
    required this.patientId,
    required this.date,
    required this.time,
    required this.doctorId,
    this.serviceId,
    required this.status,
    this.notes,
    this.createdAt,
    this.createdById,
    // Added to constructor
    this.consultationType,
    this.durationMinutes,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');

    return Appointment(
      id: json['id'],
      patientId: json['patientId'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      doctorId: json['doctorId'] as String,
      serviceId: json['serviceId'] as String?,
      status: json['status'],
      notes: json['notes'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      createdById: json['createdById'] as String?,
      // Added for fromJson
      consultationType: json['consultationType'] as String?,
      durationMinutes: json['durationMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'date': date.toIso8601String(),
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', // Padded time
      'doctorId': doctorId,
      'serviceId': serviceId,
      'status': status,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'createdById': createdById,
      // Added for toJson
      'consultationType': consultationType,
      'durationMinutes': durationMinutes,
    };
  }

  Appointment copyWith({
    String? id,
    String? patientId,
    DateTime? date,
    TimeOfDay? time,
    String? doctorId,
    String? serviceId,
    String? status,
    String? notes,
    DateTime? createdAt,
    String? createdById,
    // Added for copyWith
    String? consultationType,
    int? durationMinutes,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      time: time ?? this.time,
      doctorId: doctorId ?? this.doctorId,
      serviceId: serviceId ?? this.serviceId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      // Added for copyWith
      consultationType: consultationType ?? this.consultationType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
