class PatientBill {
  final String id;
  final String patientId;
  final DateTime billDate;
  final double totalAmount;
  final String status; // e.g., 'Unpaid', 'Paid', 'PartiallyPaid'
  final String? notes;

  PatientBill({
    required this.id,
    required this.patientId,
    required this.billDate,
    required this.totalAmount,
    required this.status,
    this.notes,
  });

  factory PatientBill.fromJson(Map<String, dynamic> json) {
    return PatientBill(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      billDate: DateTime.parse(json['billDate'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'billDate': billDate.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status,
      'notes': notes,
    };
  }
}
