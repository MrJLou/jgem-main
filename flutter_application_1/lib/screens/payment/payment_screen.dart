import 'dart:convert'; // Added for jsonEncode
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../models/active_patient_queue_item.dart';
import '../../services/auth_service.dart'; // For fetching current user ID
import '../../services/database_helper.dart';
import '../../services/queue_service.dart';
import '../../services/receipt_service.dart';
import '../../utils/error_dialog_utils.dart';

class PaymentScreen extends StatefulWidget {
  final String? invoiceNumber;
  const PaymentScreen({super.key, this.invoiceNumber});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountPaidController = TextEditingController();
  // double _totalAmount = 150.0; // Example total amount - will be dynamic
  bool _isPaymentProcessed = false;
  double _change = 0.0;
  String? _generatedReferenceNumber;
  String? _currentUserId;
  ActivePatientQueueItem? _relatedQueueItem;

  // PDF / Receipt state
  Uint8List? _generatedReceiptBytes;

  // New state variables for invoice search workflow
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  Map<String, dynamic>?
      _searchedInvoiceDetails; // To hold bill, items, and patient data
  bool _isLoadingInvoice = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    if (widget.invoiceNumber != null) {
      _invoiceNumberController.text = widget.invoiceNumber!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchInvoice();
      });
    }
    // _fetchInConsultationPatients(); // Removed old patient fetching
    // _loadLastProcessedPaymentSummary(); // Removed old summary loading
  }

  Future<void> _loadCurrentUserId() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    } else {
      // Handle case where user is not logged in, though this screen should be protected
      ErrorDialogUtils.showErrorDialog(
        context: context,
        title: 'Authentication Error',
        message: 'Error: Could not identify current user. Please log in again.',
      );
    }
  }

  // This method is no longer fetching a list of patients for selection.
  // It can be repurposed or removed. For now, let's clear its old logic.
  // Or, it could be used to reset the payment screen to initial state.
  void _resetPaymentScreen() {
    setState(() {
      _invoiceNumberController.clear();
      _amountPaidController.clear();
      _searchedInvoiceDetails = null;
      _isPaymentProcessed = false;
      _change = 0.0;
      _generatedReferenceNumber = null;
      _isLoadingInvoice = false;
      _generatedReceiptBytes = null;
      _relatedQueueItem = null;
    });
  }

  Future<Map<String, dynamic>?> _prepareReceiptDetails() {
    if (_searchedInvoiceDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please load an invoice first.'),
            backgroundColor: Colors.orange),
      );
      return Future.value(null);
    }

    final billData = _searchedInvoiceDetails!['bill'] as Map<String, dynamic>;
    final totalBillAmount =
        (billData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = double.tryParse(_amountPaidController.text);

    if (amountPaid == null || amountPaid < totalBillAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter a valid amount greater than or equal to the total due.'),
            backgroundColor: Colors.red),
      );
      return Future.value(null);
    }

    final patientData =
        _searchedInvoiceDetails!['patient'] as Map<String, dynamic>?;
    final patientName = patientData?['fullName'] as String? ?? 'N/A';

    return Future.value({
      'patientName': patientName,
      'invoiceNumber': billData['invoiceNumber'],
      'referenceNumber': 'PREVIEW-DRAFT', // Placeholder for pre-payment receipt
      'paymentDate': DateTime.now(),
      'totalAmount': totalBillAmount,
      'amountPaid': amountPaid,
      'change': amountPaid - totalBillAmount,
      'receivedByUserId': _currentUserId ?? 'N/A',
      'billItems': _searchedInvoiceDetails!['items'],
    });
  }

  Future<void> _handlePrintReceipt() async {
    final details = await _prepareReceiptDetails();
    if (details == null) return;

    try {
      final pdfBytes = await ReceiptService.generateReceiptPdfBytes(details);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error generating receipt for printing: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSaveReceipt() async {
    final details = await _prepareReceiptDetails();
    if (details == null) return;

    try {
      final pdfBytes = await ReceiptService.generateReceiptPdfBytes(details);
      final invoiceNumber = details['invoiceNumber'] as String? ?? 'receipt';

      // Get the directory and save the file
      final directory = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${directory.path}/Receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final filePath =
          '${receiptsDir.path}/${invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt saved to: $filePath'),
          action: SnackBarAction(
              label: 'Open', onPressed: () => OpenFilex.open(filePath)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // Removed _loadLastProcessedPaymentSummary, _saveLastProcessedPaymentSummary, _clearLastProcessedPaymentSummary
  // Removed _buildInConsultationPatientList, _buildProcessedPaymentSummarySection

  void _processPayment() async {
    // This method will be significantly updated later to use _searchedInvoiceDetails
    if (_searchedInvoiceDetails == null) {
      // Updated condition
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please search and load an invoice first.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (_currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot process payment: User not identified.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final billData = _searchedInvoiceDetails!['bill'] as Map<String, dynamic>;
    final double totalBillAmount =
        (billData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final String billId = billData['id'] as String;
    final String? patientId = billData['patientId'] as String?;
    final patientData = _searchedInvoiceDetails!['patient']
        as Map<String, dynamic>?; // Could be null
    final String patientName = patientData?['fullName'] as String? ?? 'N/A';

    final double? amountPaid = double.tryParse(_amountPaidController.text);

    if (amountPaid == null || amountPaid < totalBillAmount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Insufficient amount paid. Required: ₱${totalBillAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final uuidString = _uuid.v4().replaceAll('-', '');
      final referenceNumber =
          'PAY-${uuidString.length >= 8 ? uuidString.substring(0, 8).toUpperCase() : uuidString.toUpperCase()}';
      final paymentDateTime = DateTime.now();

      final paymentData = {
        'billId': billId, // Crucial for updating bill status
        'patientId': patientId, // patientId from the bill
        'patientName': patientName,
        'referenceNumber': referenceNumber,
        'paymentDate': paymentDateTime.toIso8601String(),
        'amountPaid': amountPaid,
        'paymentMethod': 'Cash', // Assuming cash for now
        'receivedByUserId': _currentUserId!,
        'notes': 'Payment for Invoice #: ${billData['invoiceNumber']}',
        'totalBillAmount':
            totalBillAmount, // Store the actual bill amount at time of payment
      };

      await _dbHelper
          .insertPayment(paymentData); // This now also updates bill status

      // If the patient was found in the active queue, update their status
      if (_relatedQueueItem != null) {
        await QueueService()
            .markPaymentSuccessfulAndServe(_relatedQueueItem!.queueEntryId);
      }

      await _dbHelper.logUserActivity(
        _currentUserId!,
        'Processed payment for invoice ${billData['invoiceNumber']} for patient $patientName (Ref: $referenceNumber)',
        targetRecordId: billId, // Target the bill record
        targetTable: DatabaseHelper.tablePatientBills,
        details: jsonEncode({
          'paymentReference': referenceNumber,
          'amountPaid': amountPaid,
          'totalBill': totalBillAmount,
        }),
      );

      final receiptDetails = {
        'patientName': patientName,
        'invoiceNumber': billData['invoiceNumber'],
        'referenceNumber': referenceNumber,
        'paymentDate': paymentDateTime,
        'totalAmount': totalBillAmount,
        'amountPaid': amountPaid,
        'change': amountPaid - totalBillAmount,
        'receivedByUserId': _currentUserId!,
        'billItems': _searchedInvoiceDetails!['items'],
      };

      try {
        final pdfBytes =
            await ReceiptService.generateReceiptPdfBytes(receiptDetails);

        // Track the generated receipt PDF for sync
        try {
          await _dbHelper.documentTrackingService.trackReceiptGeneration(
            paymentId: referenceNumber,
            referenceNumber: referenceNumber,
            pdfBytes: pdfBytes,
            patientName: patientName,
            userId: _currentUserId,
            additionalMetadata: {
              'invoiceNumber': billData['invoiceNumber'],
              'totalAmount': totalBillAmount,
              'amountPaid': amountPaid,
              'change': amountPaid - totalBillAmount,
            },
          );
          debugPrint('Payment receipt PDF tracked for sync: $referenceNumber');
        } catch (e) {
          debugPrint('Warning: Failed to track receipt PDF for sync: $e');
          // Continue with receipt generation even if tracking fails
        }

        if (mounted) {
          setState(() {
            _generatedReceiptBytes = pdfBytes;
          });
        }
      } catch (e) {
        debugPrint('Error generating receipt PDF: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Payment successful, but receipt generation failed: ${e.toString()}'),
                backgroundColor: Colors.orange),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isPaymentProcessed = true;
        _change = amountPaid - totalBillAmount;
        _generatedReferenceNumber = referenceNumber;
        _amountPaidController.clear();
        // No longer clearing _selectedPatientQueueItem as it's not used in the same way
        // Consider resetting _searchedInvoiceDetails or parts of it to prevent re-payment without new search
        _searchedInvoiceDetails =
            null; // Reset after payment to force new search
        _invoiceNumberController.clear();
        _relatedQueueItem = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment processed successfully! Ref: $referenceNumber. Change: ₱${_change.toStringAsFixed(2)}'),
          backgroundColor: Colors.teal,
        ),
      );
      // No need to call _fetchInConsultationPatients() anymore
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveFinalReceipt(String invoiceNumber) async {
    if (_generatedReceiptBytes == null || _generatedReferenceNumber == null) {
      return;
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${directory.path}/Receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final filePath =
          '${receiptsDir.path}/RECEIPT_${invoiceNumber}_$_generatedReferenceNumber.pdf';
      final file = File(filePath);
      await file.writeAsBytes(_generatedReceiptBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to: $filePath'),
            action: SnackBarAction(
                label: 'Open', onPressed: () => OpenFilex.open(filePath)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving receipt: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Placeholder for the new search method
  Future<void> _searchInvoice() async {
    final String invoiceNum = _invoiceNumberController.text.trim();
    if (invoiceNum.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter an invoice number.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoadingInvoice = true;
      _searchedInvoiceDetails = null; // Clear previous details
      _isPaymentProcessed = false; // Reset payment status
      _amountPaidController.clear();
      _generatedReferenceNumber = null;
      _change = 0.0;
      _generatedReceiptBytes = null;
      _relatedQueueItem = null;
    });

    try {
      final details = await _dbHelper.getPatientBillByInvoiceNumber(invoiceNum);
      if (!mounted) return;
      if (details != null) {
        setState(() {
          _searchedInvoiceDetails = details;
        });

        final billData =
            _searchedInvoiceDetails!['bill'] as Map<String, dynamic>;
        final patientId = billData['patientId'] as String?;

        if (patientId != null) {
          final queueItem = await QueueService().findPatientInQueue(patientId);
          if (mounted && queueItem != null) {
            setState(() {
              _relatedQueueItem = queueItem;
            });
          }
        }

        final billStatus = billData['status'] as String?;
        if (billStatus == 'Paid') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Invoice $invoiceNum has already been paid.'),
                backgroundColor: Colors.blueAccent),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Invoice number "$invoiceNum" not found.'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error searching for invoice: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInvoice = false;
        });
      }
    }
  }

  Widget _buildInvoiceSearchPane() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Find Invoice",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _invoiceNumberController,
            decoration: InputDecoration(
              labelText: 'Enter Invoice Number',
              hintText: 'e.g., INV-XXXXXX',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.receipt_long_outlined),
            ),
            onSubmitted: (_) => _searchInvoice(), // Allow search on submit
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _isLoadingInvoice
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator()))
                : ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Search Invoice'),
                    onPressed: _searchInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    // This will be updated to use _searchedInvoiceDetails
    if (_searchedInvoiceDetails == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.teal[50],
                child: Icon(
                  Icons.search_outlined, // Changed icon
                  size: 45,
                  color: Colors.teal[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Search for Invoice',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter an invoice number in the left pane to load details for payment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    // ... more detailed implementation will follow using _searchedInvoiceDetails ...
    final billData = _searchedInvoiceDetails!['bill'] as Map<String, dynamic>;
    final patientData =
        _searchedInvoiceDetails!['patient'] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> billItems =
        (_searchedInvoiceDetails!['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final String patientName = patientData?['fullName'] as String? ?? 'N/A';
    final double totalAmount =
        (billData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final String processedInvoiceNumber = billData['invoiceNumber'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment for Invoice: ${billData['invoiceNumber']}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800]),
              ),
              if (_isPaymentProcessed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Status: PAID',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700])),
                )
              else if (billData['status'] == 'Paid')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Status: PAID',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700])),
                ),
              const SizedBox(height: 10),
              Text('Patient: $patientName',
                  style: const TextStyle(fontSize: 15)),
              if (patientData != null && patientData['id'] != null)
                Text('Patient ID: ${patientData['id']}',
                    style: const TextStyle(fontSize: 15)),
              const Divider(height: 25),
              const Text('Services/Items:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              if (billItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No specific services listed for this bill.',
                      style:
                          TextStyle(fontStyle: FontStyle.italic, fontSize: 15)),
                )
              else
                ...billItems.map((item) {
                  final itemName =
                      item['description'] as String? ?? 'Unknown Service';
                  final itemQty = item['quantity'] as int? ?? 1;
                  final itemPrice =
                      (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
                  final itemTotal = (item['itemTotal'] as num?)?.toDouble() ??
                      (itemPrice * itemQty);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('$itemName (Qty: $itemQty)',
                        style: const TextStyle(fontSize: 15)),
                    trailing: Text('₱${itemTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15)),
                  );
                }),
              const Divider(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Due:',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('₱${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700])),
                ],
              ),
              const SizedBox(height: 20),
              if (billData['status'] != 'Paid') ...[
                TextFormField(
                  controller: _amountPaidController,
                  onChanged: (value) =>
                      setState(() {}), // To rebuild and enable/disable buttons
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Enter Amount Paid (Cash)',
                    hintText: 'e.g., ${totalAmount.toStringAsFixed(2)}',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.money, color: Colors.green[700]),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount paid.';
                    }
                    final pVal = double.tryParse(value);
                    if (pVal == null) return 'Invalid amount.';
                    if (pVal < totalAmount) {
                      return 'Amount is less than total due.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print Receipt'),
                        onPressed: _amountPaidController.text.isNotEmpty
                            ? _handlePrintReceipt
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: BorderSide(color: Colors.teal.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Save Receipt'),
                        onPressed: _amountPaidController.text.isNotEmpty
                            ? _handleSaveReceipt
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: BorderSide(color: Colors.indigo.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Process Cash Payment'),
                    onPressed: _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
              if (_isPaymentProcessed && _generatedReferenceNumber != null) ...[
                const Divider(height: 30),
                Text('Payment Successful!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700])),
                const SizedBox(height: 8),
                SelectableText('Payment Reference: $_generatedReferenceNumber',
                    style: const TextStyle(fontSize: 16)),
                Text('Change Due: ₱${_change.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: [
                    ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text("New Payment"),
                        onPressed: _resetPaymentScreen,
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blueAccent)),
                    if (_generatedReceiptBytes != null) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.receipt_long),
                        label: const Text("View Receipt"),
                        onPressed: () =>
                            _showReceiptPreviewDialog(_generatedReceiptBytes!),
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.orange),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text("Print"),
                        onPressed: () => Printing.layoutPdf(
                            onLayout: (format) async =>
                                _generatedReceiptBytes!),
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.teal),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text("Save"),
                        onPressed: () =>
                            _saveFinalReceipt(processedInvoiceNumber),
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.indigo),
                      ),
                    ]
                  ],
                )
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          'Process Payment by Invoice', // Updated title
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetPaymentScreen, // Use reset for the refresh button
            tooltip: 'Clear / New Payment',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Pane: Invoice Search
            Expanded(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.only(right: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(77),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _buildInvoiceSearchPane(), // New pane for searching
              ),
            ),
            // Right Pane: Payment Details
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(77),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                // The _buildPaymentDetailsSection now returns a SingleChildScrollView with a Card
                // if details are loaded, or a placeholder. So no need for Column/Expanded here for summary.
                child: _buildPaymentDetailsSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptPreviewDialog(Uint8List pdfBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
          child: Column(
            children: [
              AppBar(
                title: Text('Receipt Preview - $_generatedReferenceNumber'),
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
}
