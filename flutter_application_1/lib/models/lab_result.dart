import 'dart:convert';
import 'package:flutter/foundation.dart';

class LabResult {
  final String id;
  final String patientId;
  final String? appointmentId;
  final String? queueEntryId;  // Added field to store the queue entry ID
  final String? serviceId;
  final List<Map<String, dynamic>>? selectedServices;
  final String category;
  final String testName;
  final Map<String, dynamic> results;
  final String status;
  final String recordType;
  final DateTime recordDate;
  final String? diagnosis;
  final String? treatment;
  final String? prescription;
  final String? notes;
  final String doctorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  LabResult({
    required this.id,
    required this.patientId,
    this.appointmentId,
    this.queueEntryId,  // Added field
    this.serviceId,
    this.selectedServices,
    required this.category,
    required this.testName,
    required this.results,
    required this.status,
    required this.recordType,
    required this.recordDate,
    this.diagnosis,
    this.treatment,
    this.prescription,
    this.notes,
    required this.doctorId,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory LabResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? services;
    Map<String, dynamic> resultsMap = {};
    String category = 'Laboratory';
    String testName = 'Laboratory Test';
    String status = 'Completed';
    
    // Parse the lab results JSON if it exists
    if (json['labResults'] != null && json['labResults'].isNotEmpty) {
      try {
        final labData = json['labResults'] is String 
            ? jsonDecode(json['labResults'] as String) 
            : json['labResults'];
        
        if (labData is Map) {
          if (labData.containsKey('results')) {
            resultsMap = labData['results'] as Map<String, dynamic>? ?? {};
            testName = labData['testName'] as String? ?? 'Laboratory Test';
            category = labData['category'] as String? ?? 'Laboratory';
            status = labData['status'] as String? ?? 'Completed';
          } else if (labData.containsKey('testName') || labData.containsKey('category')) {
            testName = labData['testName'] as String? ?? 'Laboratory Test';
            category = labData['category'] as String? ?? 'Laboratory';
            status = labData['status'] as String? ?? 'Completed';
            
            // Extract results data from labData
            for (final key in labData.keys) {
              if (key != 'testName' && key != 'category' && 
                  key != 'status' && key != 'date' && key != 'queueId') {
                if (labData[key] is Map) {
                  resultsMap.addAll(labData[key] as Map<String, dynamic>);
                } else if (labData[key] is String || labData[key] is num) {
                  resultsMap[key] = labData[key].toString();
                }
              }
            }
          } else {
            // Assume the entire map contains results
            resultsMap = Map<String, dynamic>.from(labData);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing lab results JSON: $e');
        }
        resultsMap = {'Error': 'Could not parse lab results properly'};
      }
    }
    
    // Parse selected services if available
    if (json['selectedServices'] != null) {
      if (json['selectedServices'] is String && (json['selectedServices'] as String).isNotEmpty) {
        try {
          var decoded = jsonDecode(json['selectedServices'] as String);
          if (decoded is List) {
            services = List<Map<String, dynamic>>.from(
                decoded.map((item) => Map<String, dynamic>.from(item as Map)));
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing selectedServices JSON: $e');
          }
          services = null;
        }
      } else if (json['selectedServices'] is List) {
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

    return LabResult(
      id: json['id']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      appointmentId: json['appointmentId']?.toString(),
      queueEntryId: json['queueEntryId']?.toString(),  // Added field
      serviceId: json['serviceId']?.toString(),
      selectedServices: services,
      category: category,
      testName: testName,
      results: resultsMap,
      status: status,
      recordType: json['recordType']?.toString() ?? 'laboratory',
      recordDate: json['recordDate'] != null 
          ? DateTime.parse(json['recordDate'].toString())
          : DateTime.now(),
      diagnosis: json['diagnosis']?.toString(),
      treatment: json['treatment']?.toString(),
      prescription: json['prescription']?.toString(),
      notes: json['notes']?.toString(),
      doctorId: json['doctorId']?.toString() ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'patientId': patientId,
      'recordType': recordType,
      'recordDate': recordDate.toIso8601String(),
      'doctorId': doctorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    
    // Add optional fields only if they're not null
    if (appointmentId != null) data['appointmentId'] = appointmentId;
    if (queueEntryId != null) data['queueEntryId'] = queueEntryId;
    if (serviceId != null) data['serviceId'] = serviceId;
    if (diagnosis != null) data['diagnosis'] = diagnosis;
    if (treatment != null) data['treatment'] = treatment;
    if (prescription != null) data['prescription'] = prescription;
    if (notes != null) data['notes'] = notes;
    
    // Serialize selected services if present
    if (selectedServices != null) {
      data['selectedServices'] = jsonEncode(selectedServices);
    }
    
    // Serialize lab results data
    data['labResults'] = jsonEncode({
      'testName': testName,
      'category': category,
      'status': status,
      'results': results,
    });
    
    return data;
  }

  LabResult copyWith({
    String? id,
    String? patientId,
    String? appointmentId,
    String? queueEntryId,  // Added field
    String? serviceId,
    List<Map<String, dynamic>>? selectedServices,
    String? category,
    String? testName,
    Map<String, dynamic>? results,
    String? status,
    String? recordType,
    DateTime? recordDate,
    String? diagnosis,
    String? treatment,
    String? prescription,
    String? notes,
    String? doctorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LabResult(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      appointmentId: appointmentId ?? this.appointmentId,
      queueEntryId: queueEntryId ?? this.queueEntryId,
      serviceId: serviceId ?? this.serviceId,
      selectedServices: selectedServices ?? this.selectedServices,
      category: category ?? this.category,
      testName: testName ?? this.testName,
      results: results ?? this.results,
      status: status ?? this.status,
      recordType: recordType ?? this.recordType,
      recordDate: recordDate ?? this.recordDate,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      prescription: prescription ?? this.prescription,
      notes: notes ?? this.notes,
      doctorId: doctorId ?? this.doctorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
