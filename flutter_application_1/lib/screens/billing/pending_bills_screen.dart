import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../models/active_patient_queue_item.dart';
import '../../models/patient.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/pdf_invoice_service.dart';
import '../../services/queue_service.dart';
import '../payment/payment_screen.dart';
import '../patient_queue/view_queue_screen.dart';

class PendingBillsScreen extends StatefulWidget {
  const PendingBillsScreen({super.key});

  @override
  PendingBillsScreenState createState() => PendingBillsScreenState();
}

class PendingBillsScreenState extends State<PendingBillsScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PdfInvoiceService _pdfInvoiceService = PdfInvoiceService();
  final QueueService _queueService = QueueService();
  final AuthService _authService = AuthService();
  static const Uuid _uuid = Uuid();
  
  List<Map<String, dynamic>> _pendingBills = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadAllPendingBills();
  }

  Future<void> _loadAllPendingBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bills = await _dbHelper.getUnpaidBills();
      setState(() {
        _pendingBills = bills;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pending bills: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchPendingBills() async {
    final patientIdOrName = _patientIdController.text.trim();
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final bills = await _dbHelper.getUnpaidBills(
        patientIdOrName: patientIdOrName.isNotEmpty ? patientIdOrName : null,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
      
      setState(() {
        _pendingBills = bills;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: ${e.toString()}';
        _isLoading = false;
        _pendingBills = [];
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearSearch() {
    _patientIdController.clear();
    setState(() {
      _hasSearched = false;
      _errorMessage = null;
      _selectedDateRange = null;
    });
    _loadAllPendingBills();
  }

  Future<void> _handlePrintOrSaveBill(Map<String, dynamic> bill,
      {required bool isPrinting, bool markAsPaid = false}) async {
    final invoiceNumber = bill['invoiceNumber'] as String?;
    if (invoiceNumber == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice number not found.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (markAsPaid) {
        final currentUserId = await _authService.getCurrentUserId();
        if (currentUserId == null) {
          throw Exception('User not logged in.');
        }

        final billId = bill['id'] as String;
        final patientId = bill['patientId'] as String?;
        final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
        
        // Create payment record
        final uuidString = _uuid.v4().replaceAll('-', '');
        final referenceNumber = 'PAY-${uuidString.substring(0, 8).toUpperCase()}';
        final paymentDateTime = DateTime.now();
        final paymentData = {
          'billId': billId,
          'patientId': patientId,
          'referenceNumber': referenceNumber,
          'paymentDate': paymentDateTime.toIso8601String(),
          'amountPaid': totalAmount, // Assuming full amount is paid
          'paymentMethod': 'Cash', // Defaulting to Cash
          'receivedByUserId': currentUserId,
          'notes': 'Payment marked as paid from Pending Bills screen for Invoice #: $invoiceNumber',
          'totalBillAmount': totalAmount,
        };
        await _dbHelper.insertPayment(paymentData);

        // Update queue status
        if (patientId != null) {
          final queueItem = await _queueService.findPatientInQueue(patientId);
          if (queueItem != null) {
            await _queueService.markPaymentSuccessfulAndServe(queueItem.queueEntryId);
          }
        }
        
        await _dbHelper.logUserActivity(
          currentUserId,
          'Marked bill as paid and saved for invoice $invoiceNumber',
          targetRecordId: billId,
          targetTable: DatabaseHelper.tablePatientBills,
          details: jsonEncode({'paymentReference': referenceNumber, 'amountPaid': totalAmount}),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice $invoiceNumber marked as paid.'), backgroundColor: Colors.green),
        );
        
        // Refresh queue displays after marking payment
        ViewQueueScreen.refreshDashboardAfterPayment();
      }

      // PDF generation part, runs for all cases
      final patientDetails = {
        'fullName': bill['patient_name'],
        'id': bill['patientId'],
      };

      final billItems = await _dbHelper.getBillItems(bill['id']);

      final pdfBytes = await _pdfInvoiceService.generateInvoicePdf(
        patientDetails: Patient.fromJson(patientDetails),
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.parse(bill['billDate']),
        queueItem: ActivePatientQueueItem(
          queueEntryId: '',
          patientId: bill['patientId'],
          patientName: bill['patient_name'],
          arrivalTime: DateTime.now(),
          queueNumber: 0,
          status: markAsPaid ? 'paid' : 'unpaid', // Reflect status in PDF
          createdAt: DateTime.now(),
          selectedServices: billItems.map((item) {
            return {
              'name': item['description'],
              'price': item['unitPrice'],
            };
          }).toList(),
        ),
      );

      if (isPrinting) {
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final receiptsDir = Directory('${directory.path}/Invoice');
        if (!await receiptsDir.exists()) {
          await receiptsDir.create(recursive: true);
        }
        final filePath = '${receiptsDir.path}/$invoiceNumber.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        if (!mounted) return;
        final message = markAsPaid
            ? 'Paid invoice saved to: $filePath'
            : 'Unpaid bill saved to: $filePath';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
                label: 'Open', onPressed: () => OpenFilex.open(filePath)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error processing bill: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (markAsPaid) {
          _loadAllPendingBills(); // Refresh the list
        }
      }
    }
  }

  double _calculateTotalPending() {
    return _pendingBills.fold(0.0, (sum, bill) {
      final amount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _calculateTotalPending();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pending Bills',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        actions: [
          if (_hasSearched)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: _clearSearch,
              tooltip: 'Clear Search',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Card(
              elevation: 4,
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      size: 40,
                      color: Colors.orange[600],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pending Amount',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₱${totalPending.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_pendingBills.length} Bills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Search Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Pending Bills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _patientIdController,
                            decoration: const InputDecoration(
                              labelText: 'Patient ID or Name (optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: _selectDateRange,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedDateRange == null
                                          ? 'Select Date Range'
                                          : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                                      style: TextStyle(
                                        color: _selectedDateRange == null 
                                            ? Colors.grey[600] 
                                            : Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _searchPendingBills,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                          ),
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isLoading ? 'Searching...' : 'Filter'),
                        ),
                        const SizedBox(width: 12),
                        if (_hasSearched || _selectedDateRange != null)
                          TextButton.icon(
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingBills.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _hasSearched 
                                    ? 'No pending bills found for your search'
                                    : 'No pending bills found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _pendingBills.length,
                          itemBuilder: (context, index) {
                            final bill = _pendingBills[index];
                            return _buildPendingBillCard(bill);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBillCard(Map<String, dynamic> bill) {
    final billDate = DateTime.parse(bill['billDate'] as String);
    final dueDate = bill['dueDate'] != null 
        ? DateTime.parse(bill['dueDate'] as String)
        : billDate.add(const Duration(days: 30));
    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final patientName = bill['patient_name'] as String? ?? 'Unknown Patient';
    final invoiceNumber = bill['invoiceNumber'] as String? ?? 'N/A';
    final patientContact = bill['patient_contact'] as String?;
    final createdBy = bill['created_by_user_name'] as String? ?? 'N/A';

    // Calculate days overdue
    final now = DateTime.now();
    final isOverdue = now.isAfter(dueDate);
    final daysOverdue = isOverdue ? now.difference(dueDate).inDays : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invoice: $invoiceNumber',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (patientContact != null)
                        Text(
                          'Contact: $patientContact',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red[600] : Colors.orange[600],
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$daysOverdue days overdue',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDetailChip(
                  'Bill Date', 
                  DateFormat('MMM dd, yyyy').format(billDate),
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  'Due Date', 
                  DateFormat('MMM dd, yyyy').format(dueDate),
                  isOverdue ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  'Created By', 
                  createdBy,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showBillDetails(bill),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _processPayment(bill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[600],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Process Payment'),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print Bill'),
                      onPressed: () => _handlePrintOrSaveBill(bill, isPrinting: true),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.save_alt_outlined, size: 16),
                      label: const Text('Save Bill'),
                      onPressed: () =>
                          _handlePrintOrSaveBill(bill, isPrinting: false),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Paid'),
                      onPressed: () => _handlePrintOrSaveBill(bill, isPrinting: false, markAsPaid: true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    )
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: color[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill Details - ${bill['invoiceNumber']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Patient', bill['patient_name'] ?? 'N/A'),
            _buildDetailRow('Invoice Number', bill['invoiceNumber'] ?? 'N/A'),
            _buildDetailRow('Total Amount', '₱${((bill['totalAmount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
            _buildDetailRow('Bill Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(bill['billDate']))),
            if (bill['dueDate'] != null)
              _buildDetailRow('Due Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(bill['dueDate']))),
            _buildDetailRow('Created By', bill['created_by_user_name'] ?? 'N/A'),
            if (bill['notes'] != null && (bill['notes'] as String).isNotEmpty)
              _buildDetailRow('Notes', bill['notes']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _processPayment(Map<String, dynamic> bill) {
    final invoiceNumber = bill['invoiceNumber'] as String?;
    if (invoiceNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Invoice number is missing.'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(invoiceNumber: invoiceNumber),
      ),
    );
  }
}
