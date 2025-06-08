import 'dart:convert'; // Added for jsonEncode
import 'package:flutter/material.dart';
// import 'package:flutter_application_1/models/active_patient_queue_item.dart'; // No longer directly selected
import 'package:flutter_application_1/models/patient.dart'; // For displaying patient details
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/queue_service.dart'; // May still be used if payment affects queue
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart'; // For fetching current user ID
// import 'package:shared_preferences/shared_preferences.dart'; // No longer using shared_prefs for last payment summary

// Removed TransactionHistoryScreen import as it's not used directly in this refactor yet.
// import 'transaction_history_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountPaidController = TextEditingController();
  // double _totalAmount = 150.0; // Example total amount - will be dynamic
  bool _isPaymentProcessed = false;
  double _change = 0.0;
  String? _generatedReferenceNumber;
  String? _currentUserId;
  
  // New state variables for invoice search workflow
  final TextEditingController _invoiceNumberController = TextEditingController();
  Map<String, dynamic>? _searchedInvoiceDetails; // To hold bill, items, and patient data
  bool _isLoadingInvoice = false; 

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService(); // Keep for now, might be needed if payment serves a patient
  static const Uuid _uuid = Uuid();

  // Keys for SharedPreferences
  static const String _lastPaymentRefKey = 'last_payment_ref';
  static const String _lastPatientItemKey = 'last_patient_item_json';
  static const String _lastChangeKey = 'last_payment_change';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    // _fetchInConsultationPatients(); // Removed old patient fetching
    // _loadLastProcessedPaymentSummary(); // Removed old summary loading
  }

  Future<void> _loadCurrentUserId() async {
    final user = await AuthService().getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    } else {
      // Handle case where user is not logged in, though this screen should be protected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Error: Could not identify current user. Please log in again.'),
          backgroundColor: Colors.red,
        ),
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
    });
      }

  // Removed _loadLastProcessedPaymentSummary, _saveLastProcessedPaymentSummary, _clearLastProcessedPaymentSummary
  // Removed _buildInConsultationPatientList, _buildProcessedPaymentSummarySection 

  void _processPayment() async {
    // This method will be significantly updated later to use _searchedInvoiceDetails
    if (_searchedInvoiceDetails == null) { // Updated condition
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please search and load an invoice first.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot process payment: User not identified.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final billData = _searchedInvoiceDetails!['bill'] as Map<String, dynamic>;    
    final double totalBillAmount = (billData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final String billId = billData['id'] as String;
    final String? patientId = billData['patientId'] as String?;
    final patientData = _searchedInvoiceDetails!['patient'] as Map<String, dynamic>?; // Could be null
    final String patientName = patientData?['fullName'] as String? ?? 'N/A';
    
    // Find queueEntryId if this payment should mark a patient as served
    // This part needs careful consideration. If payment is for an old invoice,
    // the patient might not be in the active queue anymore.
    // For now, we assume if the invoice is from an active queue item originally,
    // that queue item's ID *might* be stored with the bill or needs a different lookup.
    // This is a simplification for now and might need adjustment based on how queueEntryId is linked to bills.
    String? queueEntryIdForServing; 
    // Example: if (billData.containsKey('originalQueueEntryId')) { 
    //   queueEntryIdForServing = billData['originalQueueEntryId']; 
    // }

    final double? amountPaid = double.tryParse(_amountPaidController.text);

    if (amountPaid == null || amountPaid < totalBillAmount) {
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
      final referenceNumber = 'PAY-${_uuid.v4().substring(0, 8).toUpperCase()}';
      final paymentDateTime = DateTime.now();

      final paymentData = {
        'billId': billId, // Crucial for updating bill status
        'patientId': patientId, // patientId from the bill
        'referenceNumber': referenceNumber,
        'paymentDate': paymentDateTime.toIso8601String(),
        'amountPaid': amountPaid,
        'paymentMethod': 'Cash', // Assuming cash for now
        'receivedByUserId': _currentUserId!,
        'notes': 'Payment for Invoice #: ${billData['invoiceNumber']}',
        'totalBillAmount': totalBillAmount, // Store the actual bill amount at time of payment
      };

      await _dbHelper.insertPayment(paymentData); // This now also updates bill status
      
      // If payment needs to mark a patient as served in the queue:
      if (queueEntryIdForServing != null && queueEntryIdForServing.isNotEmpty) {
        bool paymentAndServeSuccess = await _queueService.markPaymentSuccessfulAndServe(queueEntryIdForServing);
      if (!paymentAndServeSuccess) {
           print('Warning: Payment recorded and bill updated, but failed to update queue status for $queueEntryIdForServing');
          // Not throwing an error here, as DB transaction for payment is most critical.
        }
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

      setState(() {
        _isPaymentProcessed = true;
        _change = amountPaid - totalBillAmount;
        _generatedReferenceNumber = referenceNumber;
        _amountPaidController.clear();
        // No longer clearing _selectedPatientQueueItem as it's not used in the same way
        // Consider resetting _searchedInvoiceDetails or parts of it to prevent re-payment without new search
        _searchedInvoiceDetails = null; // Reset after payment to force new search
        _invoiceNumberController.clear();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // void _generateReceipt() { // Placeholder - can be implemented later
  //   if (!_isPaymentProcessed || _generatedReferenceNumber == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Please process the payment first.'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('Receipt generation for $_generatedReferenceNumber to be implemented.'),
  //       backgroundColor: Colors.blue,
  //     ),
  //   );
  // }

  // Placeholder for the new search method
  Future<void> _searchInvoice() async {
    final String invoiceNum = _invoiceNumberController.text.trim();
    if (invoiceNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an invoice number.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoadingInvoice = true;
      _searchedInvoiceDetails = null; // Clear previous details
      _isPaymentProcessed = false;    // Reset payment status
      _amountPaidController.clear();
      _generatedReferenceNumber = null;
      _change = 0.0;
    });

    try {
      final details = await _dbHelper.getPatientBillByInvoiceNumber(invoiceNum);
      if (details != null) {
        setState(() {
          _searchedInvoiceDetails = details;
        });
        final billStatus = (_searchedInvoiceDetails!['bill'] as Map<String, dynamic>)['status'] as String?;
        if (billStatus == 'Paid') {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice $invoiceNum has already been paid.'), backgroundColor: Colors.blueAccent),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice $invoiceNum not found.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching invoice: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
    setState(() {
      _isLoadingInvoice = false;
    });
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.receipt_long_outlined),
            ),
            onSubmitted: (_) => _searchInvoice(), // Allow search on submit
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _isLoadingInvoice 
              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())) 
              : ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search Invoice'),
                  onPressed: _searchInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    final patientData = _searchedInvoiceDetails!['patient'] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> billItems = (_searchedInvoiceDetails!['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    final String patientName = patientData?['fullName'] as String? ?? 'N/A';
    final double totalAmount = (billData['totalAmount'] as num?)?.toDouble() ?? 0.0;

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
              if (billData['status'] == 'Paid')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Status: PAID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700])),
                )
              else
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Status: ${billData['status']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                ),
              const SizedBox(height: 10),
              Text('Patient: $patientName', style: const TextStyle(fontSize: 15)),
              if (patientData != null && patientData['id'] != null)
                 Text('Patient ID: ${patientData['id']}', style: const TextStyle(fontSize: 15)),
              const Divider(height: 25),
              const Text('Services/Items:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              if (billItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No specific services listed for this bill.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15)),
                )
              else
                ...billItems.map((item) {
                  final itemName = item['description'] as String? ?? 'Unknown Service';
                  final itemQty = item['quantity'] as int? ?? 1;
                  final itemPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
                  final itemTotal = (item['itemTotal'] as num?)?.toDouble() ?? (itemPrice * itemQty);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('$itemName (Qty: $itemQty)', style: const TextStyle(fontSize: 15)),
                    trailing: Text('₱${itemTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15)),
                  );
                }),
              const Divider(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Due:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('₱${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[700])),
                ],
              ),
              const SizedBox(height: 20),
              if (billData['status'] != 'Paid') ...[
              TextFormField(
                controller: _amountPaidController,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Enter Amount Paid (Cash)',
                  hintText: 'e.g., ${totalAmount.toStringAsFixed(2)}',
                  prefixText: '₱ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.money, color: Colors.green[700]),
                ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter amount paid.';
                  final pVal = double.tryParse(value);
                  if (pVal == null) return 'Invalid amount.';
                    if (pVal < totalAmount) return 'Amount is less than total due.';
                  return null;
                },
              ),
                const SizedBox(height: 25),
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
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              ],
              if (_isPaymentProcessed && _generatedReferenceNumber != null && billData['status'] == 'Paid') ...[
                const Divider(height: 30),
                Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
                const SizedBox(height: 8),
                SelectableText('Payment Reference: $_generatedReferenceNumber', style: const TextStyle(fontSize: 16)),
                Text('Change Due: ₱${_change.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                 ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_outlined), 
                  label: const Text("New Payment"), 
                  onPressed: _resetPaymentScreen,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent)
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
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
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
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
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
}
