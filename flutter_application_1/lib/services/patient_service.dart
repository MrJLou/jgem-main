import 'package:flutter/foundation.dart';

import '../models/patient.dart';
import 'api_service.dart';

class PatientService {
  static Future<String> getPatientFullName(String patientId) async {
    try {
      final patient = await ApiService.getPatientById(patientId);
      return patient.fullName;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching patient name for ID $patientId: $e');
      }
    }
    return 'Unknown Patient';
  }
  static Future<List<Patient>> searchPatients(String query) async {
    try {
      return await ApiService.searchPatients(query);
    } catch (e) {
      if (kDebugMode) {
        print('Error searching patients: $e');
      }
      return [];
    }
  }
} 