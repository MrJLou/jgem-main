class MedicalRecord {
  final String id;
  final String patientId;
  final String? appointmentId;
  final String? serviceId;
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
    this.serviceId,
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
    return MedicalRecord(
      id: json['id'],
      patientId: json['patientId'],
      appointmentId: json['appointmentId'] as String?,
      serviceId: json['serviceId'] as String?,
      recordType: json['recordType'],
      recordDate: DateTime.parse(json['recordDate']),
      diagnosis: json['diagnosis'],
      treatment: json['treatment'],
      prescription: json['prescription'],
      labResults: json['labResults'],
      notes: json['notes'],
      doctorId: json['doctorId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'appointmentId': appointmentId,
      'serviceId': serviceId,
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
    String? serviceId,
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
      serviceId: serviceId ?? this.serviceId,
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
