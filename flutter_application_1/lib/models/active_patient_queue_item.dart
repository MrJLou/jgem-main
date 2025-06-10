import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'package:flutter/foundation.dart';

@immutable
class ActivePatientQueueItem {
  final String queueEntryId; // Primary key, unique for each queue entry
  final String?
      patientId; // Foreign key to patients table (optional, if patient is registered)
  final String patientName; // Name as entered, even if not a registered patient
  final DateTime arrivalTime; // Actual time of arrival / addition to queue
  final int queueNumber; // Sequential number for the day (e.g., 1, 2, 3...)
  final String? gender;
  final int? age;
  final String? conditionOrPurpose; // Summary string from AddToQueueScreen
  final List<Map<String, dynamic>>?
      selectedServices; // New: To store structured service data
  final double? totalPrice; // New: To store calculated total price
  final String status; // e.g., 'waiting', 'ongoing', 'done', 'removed'
  final String paymentStatus; // Added: e.g., 'Pending', 'Paid', 'Waived'
  final DateTime createdAt; // Timestamp when this queue entry was created
  final String? addedByUserId; // User ID of staff who added the patient
  final DateTime? servedAt; // Timestamp when patient status changes to 'served'
  final DateTime?
      removedAt; // Timestamp when patient status changes to 'removed'
  final DateTime?
      consultationStartedAt; // Timestamp when patient status changes to 'in_consultation'
  final String? originalAppointmentId; // ADDED: To link back to the original appointment if applicable
  final String? doctorId; // ADDED: To assign a doctor to the queue entry
  final String? doctorName; // ADDED: To display doctor's name easily
  const ActivePatientQueueItem({
    required this.queueEntryId,
    this.patientId,
    required this.patientName,
    required this.arrivalTime,
    required this.queueNumber,
    this.gender,
    this.age,
    this.conditionOrPurpose,
    this.selectedServices, // Added
    this.totalPrice, // Added
    required this.status,
    this.paymentStatus = 'Pending', // Added with default value
    required this.createdAt,
    this.addedByUserId,
    this.servedAt,
    this.removedAt,
    this.consultationStartedAt,
    this.originalAppointmentId, // ADDED
    this.doctorId, // ADDED
    this.doctorName, // ADDED
  });
  factory ActivePatientQueueItem.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? services;
    if (json['selectedServices'] != null) {
      if (json['selectedServices'] is String) {
        try {
          var decoded = jsonDecode(json['selectedServices'] as String);
          if (decoded is List) {
            services = List<Map<String, dynamic>>.from(
                decoded.map((item) => Map<String, dynamic>.from(item as Map)));
          }
        } catch (e) {
          if (kDebugMode) {
            print("Error decoding selectedServices from JSON string: $e");
          }
          services = null;
        }
      } else if (json['selectedServices'] is List) {
        // If it's already a List (e.g. from direct map creation not from DB)
        try {
          services = List<Map<String, dynamic>>.from(
              (json['selectedServices'] as List)
                  .map((item) => Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          if (kDebugMode) {
            print("Error casting selectedServices from List: $e");
          }
          services = null;
        }
      }
    }

    return ActivePatientQueueItem(
      queueEntryId: json['queueEntryId'] as String,
      patientId: json['patientId'] as String?,
      patientName: json['patientName'] as String,
      arrivalTime: DateTime.parse(json['arrivalTime'] as String),
      queueNumber: json['queueNumber'] as int? ?? 0,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      conditionOrPurpose: json['conditionOrPurpose'] as String?,
      selectedServices: services, // Updated
      totalPrice: (json['totalPrice'] as num?)?.toDouble(), // Updated
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String? ?? 'Pending', // Added
      createdAt: DateTime.parse(json['createdAt'] as String),
      addedByUserId: json['addedByUserId'] as String?,
      servedAt: json['servedAt'] != null
          ? DateTime.parse(json['servedAt'] as String)
          : null,
      removedAt: json['removedAt'] != null
          ? DateTime.parse(json['removedAt'] as String)
          : null,
      consultationStartedAt: json['consultationStartedAt'] != null
          ? DateTime.parse(json['consultationStartedAt'] as String)
          : null,
      originalAppointmentId: json['originalAppointmentId'] as String?, // ADDED
      doctorId: json['doctorId'] as String?, // ADDED
      doctorName: json['doctorName'] as String?, // ADDED
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'queueEntryId': queueEntryId,
      'patientId': patientId,
      'patientName': patientName,
      'arrivalTime': arrivalTime.toIso8601String(),
      'queueNumber': queueNumber,
      'gender': gender,
      'age': age,
      'conditionOrPurpose': conditionOrPurpose,
      'selectedServices': selectedServices != null
          ? jsonEncode(selectedServices)
          : null, // Encode to JSON string
      'totalPrice': totalPrice,
      'status': status,
      'paymentStatus': paymentStatus, // Added
      'createdAt': createdAt.toIso8601String(),
      'addedByUserId': addedByUserId,
      'servedAt': servedAt?.toIso8601String(),
      'removedAt': removedAt?.toIso8601String(),
      'consultationStartedAt': consultationStartedAt?.toIso8601String(),
      'originalAppointmentId': originalAppointmentId, // ADDED
      'doctorId': doctorId, // ADDED
      'doctorName': doctorName, // ADDED
    };
  }

  ActivePatientQueueItem copyWith({
    String? queueEntryId,
    String? patientId,
    String? patientName,
    DateTime? arrivalTime,
    int? queueNumber,
    String? gender,
    int? age,
    String? conditionOrPurpose,
    List<Map<String, dynamic>>? selectedServices, // Added
    double? totalPrice, // Added
    String? status,
    String? paymentStatus, // Added
    DateTime? createdAt,
    String? addedByUserId,
    DateTime? servedAt,
    DateTime? removedAt,
    DateTime? consultationStartedAt,
    String? originalAppointmentId, // ADDED
    String? doctorId, // ADDED
    String? doctorName, // ADDED
  }) {
    return ActivePatientQueueItem(
      queueEntryId: queueEntryId ?? this.queueEntryId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      queueNumber: queueNumber ?? this.queueNumber,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      conditionOrPurpose: conditionOrPurpose ?? this.conditionOrPurpose,
      selectedServices: selectedServices ?? this.selectedServices, // Updated
      totalPrice: totalPrice ?? this.totalPrice, // Updated
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus, // Added
      createdAt: createdAt ?? this.createdAt,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      servedAt: servedAt ?? this.servedAt,
      removedAt: removedAt ?? this.removedAt,
      consultationStartedAt:
          consultationStartedAt ?? this.consultationStartedAt,
      originalAppointmentId: originalAppointmentId ?? this.originalAppointmentId, // ADDED
      doctorId: doctorId ?? this.doctorId, // ADDED
      doctorName: doctorName ?? this.doctorName, // ADDED
    );
  }
}
