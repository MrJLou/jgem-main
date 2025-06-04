import 'package:flutter/material.dart'; // Add this import at the top
import 'dart:convert'; // Required for jsonEncode and jsonDecode

class Appointment {
  final String id;
  final String patientId;
  final DateTime date;
  final TimeOfDay time;
  final String doctorId;
  final String? consultationType; // Made optional as services will cover purpose
  final int? durationMinutes;      // Made optional
  String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? originalAppointmentId; // For queue items originating from appointments

  // Fields for syncing from ActivePatientQueueItem
  final DateTime? consultationStartedAt;
  final DateTime? servedAt;
  final List<Map<String, dynamic>>? selectedServices; // CHANGED: from String? to List<Map<String, dynamic>>?
  final double? totalPrice;
  final String? paymentStatus; // e.g., 'Pending', 'Paid', 'Waived'

  Appointment({
    required this.id,
    required this.patientId,
    required this.date,
    required this.time,
    required this.doctorId,
    this.consultationType,
    this.durationMinutes,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.originalAppointmentId,
    // Fields for syncing
    this.consultationStartedAt,
    this.servedAt,
    this.selectedServices,
    this.totalPrice,
    this.paymentStatus,
  });

  Appointment copyWith({
    String? id,
    String? patientId,
    DateTime? date,
    TimeOfDay? time,
    String? doctorId,
    String? consultationType,
    int? durationMinutes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? originalAppointmentId, // Potentially nullable
    DateTime? consultationStartedAt,
    DateTime? servedAt,
    List<Map<String, dynamic>>? selectedServices,
    double? totalPrice,
    String? paymentStatus,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      time: time ?? this.time,
      doctorId: doctorId ?? this.doctorId,
      consultationType: consultationType ?? this.consultationType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalAppointmentId: originalAppointmentId ?? this.originalAppointmentId,
      consultationStartedAt: consultationStartedAt ?? this.consultationStartedAt,
      servedAt: servedAt ?? this.servedAt,
      selectedServices: selectedServices ?? this.selectedServices,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'date': date.toIso8601String(),
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'doctorId': doctorId,
      'consultationType': consultationType,
      'durationMinutes': durationMinutes,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'originalAppointmentId': originalAppointmentId,
      'consultationStartedAt': consultationStartedAt?.toIso8601String(),
      'servedAt': servedAt?.toIso8601String(),
      'selectedServices': selectedServices != null ? jsonEncode(selectedServices) : null, // Encode list to JSON string
      'totalPrice': totalPrice,
      'paymentStatus': paymentStatus,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? services;
    if (json['selectedServices'] is String) {
      try {
        var decoded = jsonDecode(json['selectedServices']);
        if (decoded is List) {
          services = decoded.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        print("Error decoding selectedServices from JSON: $e");
        services = null; // or handle error appropriately
      }
    } else if (json['selectedServices'] is List) { // Handle if it's already a list (e.g. from direct object creation)
        services = (json['selectedServices'] as List).cast<Map<String, dynamic>>();
    }


    return Appointment(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      date: DateTime.parse(json['date'] as String),
      time: TimeOfDay(
        hour: int.parse((json['time'] as String).split(':')[0]),
        minute: int.parse((json['time'] as String).split(':')[1]),
      ),
      doctorId: json['doctorId'] as String,
      consultationType: json['consultationType'] as String?,
      durationMinutes: json['durationMinutes'] as int?,
      status: json['status'] as String,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      originalAppointmentId: json['originalAppointmentId'] as String?,
      consultationStartedAt: json['consultationStartedAt'] != null ? DateTime.parse(json['consultationStartedAt'] as String) : null,
      servedAt: json['servedAt'] != null ? DateTime.parse(json['servedAt'] as String) : null,
      selectedServices: services,
      totalPrice: (json['totalPrice'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String?,
    );
  }

  @override
  String toString() {
    return 'Appointment{id: $id, patientId: $patientId, date: $date, time: $time, doctorId: $doctorId, consultationType: $consultationType, durationMinutes: $durationMinutes, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, originalAppointmentId: $originalAppointmentId, consultationStartedAt: $consultationStartedAt, servedAt: $servedAt, selectedServices: $selectedServices, totalPrice: $totalPrice, paymentStatus: $paymentStatus}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Appointment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
