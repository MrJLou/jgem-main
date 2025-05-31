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
  final String? conditionOrPurpose;
  final String status; // e.g., 'waiting', 'ongoing', 'done', 'removed'
  final DateTime createdAt; // Timestamp when this queue entry was created
  final String? addedByUserId; // User ID of staff who added the patient
  final DateTime? servedAt; // Timestamp when patient status changes to 'served'
  final DateTime?
      removedAt; // Timestamp when patient status changes to 'removed'
  final DateTime?
      consultationStartedAt; // Timestamp when patient status changes to 'in_consultation'
  const ActivePatientQueueItem({
    required this.queueEntryId,
    this.patientId,
    required this.patientName,
    required this.arrivalTime,
    required this.queueNumber,
    this.gender,
    this.age,
    this.conditionOrPurpose,
    required this.status,
    required this.createdAt,
    this.addedByUserId,
    this.servedAt,
    this.removedAt,
    this.consultationStartedAt,
  });
  factory ActivePatientQueueItem.fromJson(Map<String, dynamic> json) {
    return ActivePatientQueueItem(
      queueEntryId: json['queueEntryId'] as String,
      patientId: json['patientId'] as String?,
      patientName: json['patientName'] as String,
      arrivalTime: DateTime.parse(json['arrivalTime'] as String),
      queueNumber: json['queueNumber'] as int? ?? 0,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      conditionOrPurpose: json['conditionOrPurpose'] as String?,
      status: json['status'] as String,
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
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'addedByUserId': addedByUserId,
      'servedAt': servedAt?.toIso8601String(),
      'removedAt': removedAt?.toIso8601String(),
      'consultationStartedAt': consultationStartedAt?.toIso8601String(),
    };
  }

  ActivePatientQueueItem copyWith({
    String? queueEntryId,
    ValueGetter<String?>? patientId,
    String? patientName,
    DateTime? arrivalTime,
    int? queueNumber,
    ValueGetter<String?>? gender,
    ValueGetter<int?>? age,
    ValueGetter<String?>? conditionOrPurpose,
    String? status,
    DateTime? createdAt,
    ValueGetter<String?>? addedByUserId,
    ValueGetter<DateTime?>? servedAt,
    ValueGetter<DateTime?>? removedAt,
    ValueGetter<DateTime?>? consultationStartedAt,
  }) {
    return ActivePatientQueueItem(
      queueEntryId: queueEntryId ?? this.queueEntryId,
      patientId: patientId != null ? patientId() : this.patientId,
      patientName: patientName ?? this.patientName,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      queueNumber: queueNumber ?? this.queueNumber,
      gender: gender != null ? gender() : this.gender,
      age: age != null ? age() : this.age,
      conditionOrPurpose: conditionOrPurpose != null
          ? conditionOrPurpose()
          : this.conditionOrPurpose,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      addedByUserId:
          addedByUserId != null ? addedByUserId() : this.addedByUserId,
      servedAt: servedAt != null ? servedAt() : this.servedAt,
      removedAt: removedAt != null ? removedAt() : this.removedAt,
      consultationStartedAt: consultationStartedAt != null
          ? consultationStartedAt()
          : this.consultationStartedAt,
    );
  }
}
