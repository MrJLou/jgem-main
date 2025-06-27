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
  List<Map<String, dynamic>> _filteredReceipts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _searchController.addListener(_filterReceipts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final payments = await _dbHelper.getPaymentTransactions();
      setState(() {
        _receipts = payments;
        _filteredReceipts = payments;
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

  void _filterReceipts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReceipts = _receipts.where((receipt) {
        final patientName = (receipt['patient_name'] as String? ?? '').toLowerCase();
        final referenceNumber = (receipt['referenceNumber'] as String? ?? '').toLowerCase();
        final amount = receipt['amountPaid'].toString();
        
        return patientName.contains(query) ||
               referenceNumber.contains(query) ||
               amount.contains(query);
      }).toList();
    });
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
                title: Text('Receipt Preview - $referenceNumber',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.teal[700],
                iconTheme: const IconThemeData(color: Colors.white),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    tooltip: 'Close Preview',
                    icon: const Icon(Icons.close, color: Colors.white),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Receipts History', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[50]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Header with search
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 32,
                        color: Colors.teal[800],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receipts History',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[800],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'View and manage payment receipts',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(10),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by patient name, reference number, or amount...',
                        prefixIcon: Icon(Icons.search, color: Colors.teal[600]),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.teal[600]),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            // Receipts count and list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[700]!),
                      ),
                    )
                  : _filteredReceipts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No receipts found matching your search'
                                    : 'No receipts available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_searchController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Try different search terms',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Results count
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  Text(
                                    '${_filteredReceipts.length} receipt${_filteredReceipts.length != 1 ? 's' : ''} found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Receipts list
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _filteredReceipts.length,
                                itemBuilder: (context, index) {
                                  final receipt = _filteredReceipts[index];
                                  return _buildReceiptCard(receipt);
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final paymentDate = DateTime.parse(receipt['paymentDate'] as String);
    final referenceNumber = receipt['referenceNumber'] as String? ?? 'N/A';
    final patientName = receipt['patient_name'] as String? ?? 'N/A';
    final amount = (receipt['amountPaid'] as num? ?? 0.0).toDouble();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewReceipt(receipt),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Receipt icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.teal[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Receipt details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '₱${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Receipt No: $referenceNumber',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(paymentDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.visibility,
                          size: 16,
                          color: Colors.teal[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.teal[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}