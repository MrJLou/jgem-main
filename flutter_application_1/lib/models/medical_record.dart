import 'dart:convert';

import 'package:flutter/foundation.dart';

class MedicalRecord {
  final String id;
  final String patientId;
  final String? appointmentId;
  final List<Map<String, dynamic>>? selectedServices;
  final String recordType;
  final DateTime recordDate;
  final String? diagnosis;
  final String? treatment;
  final String? prescription;
  final String? labResults;
  final String? notes;
  final String doctorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalRecord({
    required this.id,
    required this.patientId,
    this.appointmentId,
    this.selectedServices,
    required this.recordType,
    required this.recordDate,
    this.diagnosis,
    this.treatment,
    this.prescription,
    this.labResults,
    this.notes,
    required this.doctorId,
    required this.createdAt,
    required this.updatedAt,
  });
  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? services;
    if (json['selectedServices'] != null) {
      if (json['selectedServices'] is String && (json['selectedServices'] as String).isNotEmpty) {
        try {
          var decoded = jsonDecode(json['selectedServices'] as String);
          if (decoded is List) {
            services = List<Map<String, dynamic>>.from(
                decoded.map((item) => Map<String, dynamic>.from(item as Map)));
          }
        } catch (e) {
          // Handle case where it might not be a valid JSON string
          if (kDebugMode) {
            print('Error parsing selectedServices JSON: $e');
          }
          services = null;
        }
      } else if (json['selectedServices'] is List) {
        // If it's already a List from direct map creation
        try {
          services = List<Map<String, dynamic>>.from(
              (json['selectedServices'] as List)
                  .map((item) => Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing selectedServices List: $e');
          }
          services = null;
        }
      }
    }
    
    try {
      return MedicalRecord(
        id: json['id']?.toString() ?? '',
        patientId: json['patientId']?.toString() ?? '',
        appointmentId: json['appointmentId']?.toString(),
        selectedServices: services,
        recordType: json['recordType']?.toString() ?? '',
        recordDate: json['recordDate'] != null 
            ? DateTime.parse(json['recordDate'].toString())
            : DateTime.now(),
        diagnosis: json['diagnosis']?.toString(),
        treatment: json['treatment']?.toString(),
        prescription: json['prescription']?.toString(),
        labResults: json['labResults']?.toString(),
        notes: json['notes']?.toString(),
        doctorId: json['doctorId']?.toString() ?? '',
        createdAt: json['createdAt'] != null 
            ? DateTime.parse(json['createdAt'].toString())
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null 
            ? DateTime.parse(json['updatedAt'].toString())
            : DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error creating MedicalRecord from JSON: $e');
      }
      if (kDebugMode) {
        print('JSON data: $json');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'appointmentId': appointmentId,
      'selectedServices': selectedServices != null ? jsonEncode(selectedServices) : null,
      'recordType': recordType,
      'recordDate': recordDate.toIso8601String(),
      'diagnosis': diagnosis,
      'treatment': treatment,
      'prescription': prescription,
      'labResults': labResults,
      'notes': notes,
      'doctorId': doctorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MedicalRecord copyWith({
    String? id,
    String? patientId,
    String? appointmentId,
    List<Map<String, dynamic>>? selectedServices,
    String? recordType,
    DateTime? recordDate,
    String? diagnosis,
    String? treatment,
    String? prescription,
    String? labResults,
    String? notes,
    String? doctorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      appointmentId: appointmentId ?? this.appointmentId,
      selectedServices: selectedServices ?? this.selectedServices,
      recordType: recordType ?? this.recordType,
      recordDate: recordDate ?? this.recordDate,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      prescription: prescription ?? this.prescription,
      labResults: labResults ?? this.labResults,
      notes: notes ?? this.notes,
      doctorId: doctorId ?? this.doctorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
