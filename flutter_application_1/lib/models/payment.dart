// Payment model will be defined here.

class Payment {
  final int? id;
  final String? billId; // Nullable if payment is not tied to a specific bill
  final String patientId;
  final String patientName;
  final String referenceNumber;
  final DateTime paymentDate;
  final double amountPaid;
  final String paymentMethod; // e.g., 'Cash', 'Card Terminal'
  final String receivedByUserId;
  final String? notes;

  Payment({
    this.id,
    this.billId,
    required this.patientId,
    required this.patientName,
    required this.referenceNumber,
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentMethod,
    required this.receivedByUserId,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int?,
      billId: json['billId'] as String?,
      patientId: json['patientId'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      referenceNumber: json['referenceNumber'] as String? ?? '',
      paymentDate: DateTime.parse(json['paymentDate'] as String? ?? DateTime.now().toIso8601String()),
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? '',
      receivedByUserId: json['receivedByUserId'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billId': billId,
      'patientId': patientId,
      'patientName': patientName,
      'referenceNumber': referenceNumber,
      'paymentDate': paymentDate.toIso8601String(),
      'amountPaid': amountPaid,
      'paymentMethod': paymentMethod,
      'receivedByUserId': receivedByUserId,
      'notes': notes,
    };
  }
}
