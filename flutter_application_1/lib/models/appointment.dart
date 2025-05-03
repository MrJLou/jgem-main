import 'package:flutter/material.dart';  // Add this import at the top

class Appointment {
  final String id;
  final String patientName;
  final String patientId;
  final DateTime date;
  final TimeOfDay time;
  final String doctor;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  Appointment({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.date,
    required this.time,
    required this.doctor,
    required this.status,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    
    return Appointment(
      id: json['id'],
      patientName: json['patientName'],
      patientId: json['patientId'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      doctor: json['doctor'],
      status: json['status'],
      notes: json['notes'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      createdBy: json['createdBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'patientId': patientId,
      'date': date.toIso8601String(),
      'time': '${time.hour}:${time.minute}',
      'doctor': doctor,
      'status': status,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  Appointment copyWith({
    String? id,
    String? patientName,
    String? patientId,
    DateTime? date,
    TimeOfDay? time,
    String? doctor,
    String? status,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      time: time ?? this.time,
      doctor: doctor ?? this.doctor,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}