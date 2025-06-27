import 'package:flutter_application_1/models/medical_record.dart';
import 'package:flutter_application_1/models/patient.dart';

class PatientReport {
  final MedicalRecord record;
  final Patient patient;

  PatientReport({required this.record, required this.patient});
} 