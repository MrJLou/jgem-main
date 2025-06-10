import 'package:flutter/material.dart'; // Add this import at the top
import 'dart:convert'; // Required for jsonEncode and jsonDecode

class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime date;
  final TimeOfDay time;
  final String status;
  final String consultationType;
  final List<Map<String, dynamic>> selectedServices;
  final double totalPrice;
  final int? durationMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? notes;
  final bool? isWalkIn;
  final DateTime? consultationStartedAt;
  final DateTime? servedAt;
  final String? paymentStatus;
  final String? originalAppointmentId;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.time,
    required this.status,
    required this.consultationType,
    required this.selectedServices,
    required this.totalPrice,
    this.durationMinutes,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.notes,
    this.isWalkIn,
    this.consultationStartedAt,
    this.servedAt,
    this.paymentStatus,
    this.originalAppointmentId,
  });

  Appointment copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? date,
    TimeOfDay? time,
    String? status,
    String? consultationType,
    List<Map<String, dynamic>>? selectedServices,
    double? totalPrice,
    int? durationMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? notes,
    bool? isWalkIn,
    DateTime? consultationStartedAt,
    DateTime? servedAt,
    String? paymentStatus,
    String? originalAppointmentId,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      consultationType: consultationType ?? this.consultationType,
      selectedServices: selectedServices ?? this.selectedServices,
      totalPrice: totalPrice ?? this.totalPrice,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      notes: notes ?? this.notes,
      isWalkIn: isWalkIn ?? this.isWalkIn,
      consultationStartedAt: consultationStartedAt ?? this.consultationStartedAt,
      servedAt: servedAt ?? this.servedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      originalAppointmentId: originalAppointmentId ?? this.originalAppointmentId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'date': date.toIso8601String(),
      'time': '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
      'status': status,
      'consultationType': consultationType,
      'selectedServices': jsonEncode(selectedServices),
      'totalPrice': totalPrice,
      'durationMinutes': durationMinutes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'notes': notes,
      'isWalkIn': isWalkIn == true ? 1 : 0,
      'consultationStartedAt': consultationStartedAt?.toIso8601String(),
      'servedAt': servedAt?.toIso8601String(),
      'paymentStatus': paymentStatus,
      'originalAppointmentId': originalAppointmentId,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? services;
    if (map['selectedServices'] != null) {
      final decoded = jsonDecode(map['selectedServices']);
      if (decoded is List) {
        services = decoded.cast<Map<String, dynamic>>();
      }
    }

    return Appointment(
      id: map['id'].toString(),
      patientId: map['patientId'],
      doctorId: map['doctorId'],
      date: DateTime.parse(map['date']),
      time: TimeOfDay(
        hour: int.parse(map['time'].split(':')[0]),
        minute: int.parse(map['time'].split(':')[1]),
      ),
      status: map['status'],
      consultationType: map['consultationType'],
      selectedServices: services ?? [],
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: map['durationMinutes'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      cancelledAt: map['cancelledAt'] != null ? DateTime.parse(map['cancelledAt']) : null,
      cancellationReason: map['cancellationReason'],
      notes: map['notes'],
      isWalkIn: map['isWalkIn'] == 1,
      consultationStartedAt: map['consultationStartedAt'] != null ? DateTime.parse(map['consultationStartedAt']) : null,
      servedAt: map['servedAt'] != null ? DateTime.parse(map['servedAt']) : null,
      paymentStatus: map['paymentStatus'],
      originalAppointmentId: map['originalAppointmentId'],
    );
  }

  @override
  String toString() {
    return 'Appointment{id: $id, patientId: $patientId, date: $date, time: $time, doctorId: $doctorId, consultationType: $consultationType, durationMinutes: $durationMinutes, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, notes: $notes, isWalkIn: $isWalkIn, consultationStartedAt: $consultationStartedAt, servedAt: $servedAt, selectedServices: $selectedServices, totalPrice: $totalPrice, paymentStatus: $paymentStatus}';
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
