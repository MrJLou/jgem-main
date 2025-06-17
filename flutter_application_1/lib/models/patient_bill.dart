import 'package:flutter_application_1/screens/billing/bill_history_screen.dart';

import '../../models/patient.dart';

class PatientBill {
  final String id;
  final String displayInvoiceNumber;
  final String? patientId;
  final List<Map<String, dynamic>> billItems;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String status; // e.g., 'Unpaid', 'Paid', 'Pending'
  final String createdByUserId;
  final String? notes;
  final Patient? patient; // Populated after fetching

  PatientBill({
    required this.id,
    required this.displayInvoiceNumber,
    this.patientId,
    required this.billItems,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    required this.createdByUserId,
    this.notes,
    this.patient,
  });

  factory PatientBill.fromMap(Map<String, dynamic> map, [Patient? patient]) {
    return PatientBill(
      id: map['id'] as String,
      displayInvoiceNumber: map['displayInvoiceNumber'] as String,
      patientId: map['patientId'] as String?,
      billItems: (map['billItems'] as List<dynamic>?)?.map((item) => item as Map<String, dynamic>).toList() ?? [],
      subtotal: (map['subtotal'] as num).toDouble(),
      discountAmount: (map['discountAmount'] as num).toDouble(),
      taxAmount: (map['taxAmount'] as num).toDouble(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      invoiceDate: DateTime.parse(map['invoiceDate'] as String),
      dueDate: DateTime.parse(map['dueDate'] as String),
      status: map['status'] as String,
      createdByUserId: map['createdByUserId'] as String,
      notes: map['notes'] as String?,
      patient: patient,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'billDate': invoiceDate.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status,
      'notes': notes,
    };
  }
}
