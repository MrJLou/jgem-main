import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/receipt_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:printing/printing.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final payments = await _dbHelper.getPaymentTransactions();
      setState(() {
        _receipts = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading receipts: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _viewReceipt(Map<String, dynamic> transaction) async {
    final referenceNumber = transaction['referenceNumber'] as String?;
    if (referenceNumber == null) {
      // Handle error
      return;
    }
    
    final details = await _dbHelper.getReceiptDetails(referenceNumber);

    if (details == null) {
      // Handle error
      return;
    }

    final payment = details['payment'] as Map<String, dynamic>;
    final items = details['items'] as List<Map<String, dynamic>>;

    final receiptDetails = {
      'patientName': transaction['patient_name'] as String? ?? 'N/A',
      'invoiceNumber': transaction['bill_invoice_number'] as String?,
      'referenceNumber': payment['referenceNumber'] as String,
      'paymentDate': DateTime.parse(payment['paymentDate'] as String),
      'totalAmount': (payment['totalBillAmount'] as num?)?.toDouble() ?? 0.0,
      'amountPaid': (payment['amountPaid'] as num?)?.toDouble() ?? 0.0,
      'change': ((payment['amountPaid'] as num?)?.toDouble() ?? 0.0) - ((payment['totalBillAmount'] as num?)?.toDouble() ?? 0.0),
      'billItems': items,
    };

    final pdfBytes = await ReceiptService.generateReceiptPdfBytes(receiptDetails);
    if (mounted) {
      _showReceiptPreviewDialog(pdfBytes, referenceNumber);
    }
  }

  void _showReceiptPreviewDialog(Uint8List pdfBytes, String referenceNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
          child: Column(
            children: [
              AppBar(
                title: Text('Receipt Preview - $referenceNumber'),
                backgroundColor: Colors.teal[700],
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    tooltip: 'Close Preview',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) => pdfBytes,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Receipt No.')),
                  DataColumn(label: Text('Patient Name')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _receipts.map((receipt) {
                  final paymentDate = DateTime.parse(receipt['paymentDate'] as String);
                  return DataRow(
                    cells: [
                      DataCell(Text(DateFormat('MMM dd, yyyy').format(paymentDate))),
                      DataCell(Text(receipt['referenceNumber'] as String? ?? 'N/A')),
                      DataCell(Text(receipt['patient_name'] as String? ?? 'N/A')),
                      DataCell(Text('₱${(receipt['amountPaid'] as num? ?? 0.0).toStringAsFixed(2)}')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () => _viewReceipt(receipt),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
} 