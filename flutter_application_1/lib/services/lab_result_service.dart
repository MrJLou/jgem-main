import 'package:flutter_application_1/models/lab_result.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:uuid/uuid.dart';

class LabResultService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Save a lab result to the medical records table
  Future<String> saveLabResult(LabResult labResult) async {
    try {
      // Convert LabResult to medical record format
      final medicalRecordData = labResult.toJson();
      
      // Save to medical records table
      final recordId = await _dbHelper.insertMedicalRecord(medicalRecordData);
      
      return recordId;
    } catch (e) {
      throw Exception('Failed to save lab result: $e');
    }
  }

  /// Create a new LabResult instance
  static LabResult createLabResult({
    required String patientId,
    required String doctorId,
    String? queueEntryId,
    String? appointmentId,
    String? serviceId,
    List<Map<String, dynamic>>? selectedServices,
    String category = 'Laboratory',
    String testName = 'Laboratory Test',
    Map<String, dynamic> results = const {},
    String status = 'Completed',
    String recordType = 'laboratory',
    DateTime? recordDate,
    String? diagnosis,
    String? treatment,
    String? prescription,
    String? notes,
  }) {
    final now = DateTime.now();
    
    return LabResult(
      id: 'lab-${now.millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 8)}',
      patientId: patientId,
      appointmentId: appointmentId,
      queueEntryId: queueEntryId,
      serviceId: serviceId,
      selectedServices: selectedServices,
      category: category,
      testName: testName,
      results: results,
      status: status,
      recordType: recordType,
      recordDate: recordDate ?? now,
      diagnosis: diagnosis,
      treatment: treatment,
      prescription: prescription,
      notes: notes,
      doctorId: doctorId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get lab results for a patient
  Future<List<LabResult>> getLabResultsForPatient(String patientId) async {
    try {
      final records = await _dbHelper.getLabResultsHistoryForPatient(patientId);
      return records.map((record) => LabResult.fromJson(record)).toList();
    } catch (e) {
      throw Exception('Failed to get lab results for patient: $e');
    }
  }

  /// Update a lab result
  Future<bool> updateLabResult(LabResult labResult) async {
    try {
      final medicalRecordData = labResult.copyWith(
        updatedAt: DateTime.now(),
      ).toJson();
      
      final result = await _dbHelper.updateMedicalRecord(medicalRecordData);
      return result > 0;
    } catch (e) {
      throw Exception('Failed to update lab result: $e');
    }
  }

  /// Convert consultation data to LabResult format
  static LabResult fromConsultationData({
    required String patientId,
    required String doctorId,
    required String queueEntryId,
    required Map<String, dynamic> labResultControllers,
    String? diagnosis,
    String? notes,
    List<Map<String, dynamic>>? selectedServices,
  }) {
    // Process lab result controllers to extract results
    Map<String, dynamic> results = {};
    String testName = 'Laboratory Tests';
    
    // Extract results from controllers
    for (var testCategory in labResultControllers.keys) {
      if (labResultControllers[testCategory] is Map) {
        Map<String, String> categoryResults = {};
        final controllers = labResultControllers[testCategory] as Map<String, dynamic>;
        
        for (var testNameKey in controllers.keys) {
          final controller = controllers[testNameKey];
          if (controller != null && controller.toString().trim().isNotEmpty) {
            categoryResults[testNameKey] = controller.toString().trim();
          }
        }
        
        if (categoryResults.isNotEmpty) {
          results[testCategory] = categoryResults;
        }
      }
    }

    // Determine test name from services or use default
    if (selectedServices != null && selectedServices.isNotEmpty) {
      final labServices = selectedServices.where((service) {
        final category = (service['category'] as String? ?? '').toLowerCase();
        return ['laboratory', 'radiology', 'hematology', 'chemistry', 'urinalysis', 'microbiology', 'pathology'].contains(category);
      }).toList();
      
      if (labServices.isNotEmpty) {
        testName = labServices.map((s) => s['serviceName'] ?? s['name'] ?? 'Lab Test').join(', ');
      }
    }

    return createLabResult(
      patientId: patientId,
      doctorId: doctorId,
      queueEntryId: queueEntryId,
      selectedServices: selectedServices,
      testName: testName,
      results: results,
      diagnosis: diagnosis,
      notes: notes,
    );
  }
}
