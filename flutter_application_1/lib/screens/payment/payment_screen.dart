import 'dart:convert'; // Added for jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/queue_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart'; // For fetching current user ID

// Removed TransactionHistoryScreen import as it's not used directly in this refactor yet.
// import 'transaction_history_screen.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountPaidController = TextEditingController();
  // double _totalAmount = 150.0; // Example total amount - will be dynamic
  bool _isPaymentProcessed = false;
  double _change = 0.0;
  String? _generatedReferenceNumber;

  List<ActivePatientQueueItem> _inConsultationPatients = [];
  ActivePatientQueueItem? _selectedPatientQueueItem;
  bool _isLoadingPatients = true;
  String? _currentUserId;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();
  final Uuid _uuid = Uuid(); // Made Uuid final

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _fetchInConsultationPatients();
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

  Future<void> _fetchInConsultationPatients() async {
    setState(() {
      _isLoadingPatients = true;
      // _selectedPatientQueueItem = null; // Don't reset selection if list is just refreshing
      _amountPaidController.clear();
      _isPaymentProcessed = false;
      _change = 0.0;
      _generatedReferenceNumber = null;
    });
    try {
      final patients =
          await _dbHelper.getActiveQueue(statuses: ['in_consultation']);
      print("Fetched 'in_consultation' patients BEFORE filtering:");
      for (var p in patients) {
        print(
            "  Patient Name: ${p.patientName}, Patient ID: ${p.patientId}, totalPrice: ${p.totalPrice}, selectedServices: ${p.selectedServices}, conditionOrPurpose: ${p.conditionOrPurpose}");
      }
      final validPatients = patients
          .where((p) =>
              p.patientId != null &&
              p.patientId!.isNotEmpty &&
              p.totalPrice != null &&
              p.totalPrice! > 0)
          .toList();

      setState(() {
        _inConsultationPatients = validPatients;
        _isLoadingPatients = false;
        // If a selected patient is no longer in the valid list, clear selection.
        if (_selectedPatientQueueItem != null &&
            !validPatients.any((p) =>
                p.queueEntryId == _selectedPatientQueueItem!.queueEntryId)) {
          _selectedPatientQueueItem = null;
        } else if (_selectedPatientQueueItem == null &&
            validPatients.isNotEmpty) {
          // Optionally, auto-select the first patient if none is selected
          // _selectedPatientQueueItem = validPatients.first;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingPatients = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching patients: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processPayment() async {
    if (_selectedPatientQueueItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a patient from the list.'),
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

    final double? amountPaid = double.tryParse(_amountPaidController.text);
    final double totalBillAmount = _selectedPatientQueueItem!.totalPrice ?? 0.0;

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

    // Consider adding a loading indicator state for the payment button
    // setState(() { _isProcessingPayment = true; });

    try {
      final referenceNumber = 'PAY-${_uuid.v4().substring(0, 8).toUpperCase()}';
      final paymentDateTime = DateTime.now();

      final paymentData = {
        'patientId': _selectedPatientQueueItem!.patientId!,
        'referenceNumber': referenceNumber,
        'paymentDate': paymentDateTime.toIso8601String(),
        'amountPaid': amountPaid,
        'paymentMethod': 'Cash',
        'receivedByUserId': _currentUserId!,
        'notes':
            'Payment for services: ${_selectedPatientQueueItem!.conditionOrPurpose}',
      };

      await _dbHelper.insertPayment(paymentData);

      await _queueService.updatePatientStatusInQueue(
        _selectedPatientQueueItem!.queueEntryId,
        'served',
        servedAt: paymentDateTime,
      );

      await _dbHelper.logUserActivity(
        _currentUserId!,
        'Processed payment for patient ${_selectedPatientQueueItem!.patientName} (Ref: $referenceNumber)',
        targetRecordId: _selectedPatientQueueItem!.patientId,
        targetTable: _dbHelper.tablePayments,
        details: jsonEncode({
          'queueEntryId': _selectedPatientQueueItem!.queueEntryId,
          'amountPaid': amountPaid,
          'totalBill': totalBillAmount,
          'services': _selectedPatientQueueItem!.selectedServices,
        }),
      );

      setState(() {
        _isPaymentProcessed = true;
        _change = amountPaid - totalBillAmount;
        _generatedReferenceNumber = referenceNumber;
        // _selectedPatientQueueItem will be removed from the list by _fetchInConsultationPatients
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment processed successfully! Ref: $referenceNumber. Change: ₱${_change.toStringAsFixed(2)}'),
          backgroundColor: Colors.teal,
        ),
      );
      _fetchInConsultationPatients(); // Refresh list, selected patient should be gone
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // setState(() { _isProcessingPayment = false; });
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

  Widget _buildInConsultationPatientList() {
    if (_isLoadingPatients) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_inConsultationPatients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No patients currently "In Consultation" and eligible for payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _inConsultationPatients.length,
      itemBuilder: (context, index) {
        final patient = _inConsultationPatients[index];
        final bool isSelected =
            _selectedPatientQueueItem?.queueEntryId == patient.queueEntryId;
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.teal[100] : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal[700],
              child: Text(
                patient.queueNumber?.toString() ?? '?',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(patient.patientName,
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
                'ID: ${patient.patientId?.substring(0, 8) ?? "N/A"}\nServices: ${patient.conditionOrPurpose ?? "N/A"}'),
            trailing: Text('₱${(patient.totalPrice ?? 0.0).toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.bold)),
            selected: isSelected,
            onTap: () {
              setState(() {
                _selectedPatientQueueItem = patient;
                _amountPaidController.clear();
                _isPaymentProcessed = false;
                _change = 0.0;
                _generatedReferenceNumber = null;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPaymentDetailsSection() {
    if (_selectedPatientQueueItem == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined,
                  size: 60, color: Colors.teal[300]),
              SizedBox(height: 16),
              Text(
                'Select a patient from the list on the left to view payment details.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    final patient = _selectedPatientQueueItem!;
    final totalAmount = patient.totalPrice ?? 0.0;
    final services = patient.selectedServices ?? [];

    return SingleChildScrollView(
      // Ensure right pane is scrollable if content overflows
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
                'Payment for: ${patient.patientName}',
                style: TextStyle(
                    fontSize: 20, // Increased font size
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800]),
              ),
              const SizedBox(height: 10), // Increased spacing
              Text('Patient ID: ${patient.patientId ?? "N/A"}',
                  style: TextStyle(fontSize: 15)),
              Text('Queue Number: ${patient.queueNumber}',
                  style: TextStyle(fontSize: 15)),
              const Divider(height: 25), // Increased spacing
              const Text('Services/Items:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600)), // Increased font size
              const SizedBox(height: 5),
              if (services.isEmpty &&
                  (patient.conditionOrPurpose == null ||
                      patient.conditionOrPurpose!.isEmpty))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No specific services listed.',
                      style:
                          TextStyle(fontStyle: FontStyle.italic, fontSize: 15)),
                )
              else if (services.isNotEmpty)
                ...services.map((service) {
                  final serviceName = service['name'] ?? 'Unknown Service';
                  final price = service['price'] as double? ?? 0.0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(serviceName, style: TextStyle(fontSize: 15)),
                    trailing: Text('₱${price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 15)),
                  );
                }).toList()
              else if (patient.conditionOrPurpose != null &&
                  patient.conditionOrPurpose!.isNotEmpty)
                // Fallback to conditionOrPurpose if services list is empty but conditionOrPurpose exists
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(patient.conditionOrPurpose!,
                      style: TextStyle(fontSize: 15)),
                  trailing: Text('₱${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 15)),
                ),

              if (services.isNotEmpty &&
                  patient.conditionOrPurpose != null &&
                  patient.conditionOrPurpose!.toLowerCase().contains('other:'))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                      'Other: ${patient.conditionOrPurpose!.substring(patient.conditionOrPurpose!.toLowerCase().indexOf('other:') + 6).trim()}',
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 15)),
                ),
              const Divider(height: 25), // Increased spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Due:',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold)), // Increased font size
                  Text('₱${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20, // Increased font size
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700])),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountPaidController,
                style: TextStyle(fontSize: 15),
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
              const SizedBox(height: 25), // Increased spacing
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text('Process Cash Payment'),
                  onPressed: _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15), // Increased padding
                    textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold), // Increased font size
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (_isPaymentProcessed && _generatedReferenceNumber != null) ...[
                const Divider(height: 30),
                Text('Payment Successful!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700])),
                const SizedBox(height: 8),
                SelectableText(
                    'Reference Number: $_generatedReferenceNumber', // Made reference selectable
                    style: const TextStyle(fontSize: 16)),
                Text('Change Due: ₱${_change.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
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
      backgroundColor: Colors.grey[100], // Lighten background
      appBar: AppBar(
        title: const Text(
          'Process Payment',
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
            onPressed: () {
              _selectedPatientQueueItem =
                  null; // Clear selection on manual refresh
              _fetchInConsultationPatients();
            },
            tooltip: 'Refresh Patient List',
          )
        ],
      ),
      body: Row(
        children: [
          // Left Pane: Patient List
          Expanded(
            flex: 1, // Adjust flex ratio as needed (e.g., 1 out of 3 parts)
            child: Container(
              color: Colors
                  .teal[50], // Give a distinct background to the list pane
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      "Patients In Consultation",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800]),
                    ),
                  ),
                  Expanded(child: _buildInConsultationPatientList()),
                ],
              ),
            ),
          ),
          // Right Pane: Payment Details
          Expanded(
            flex: 2, // Adjust flex ratio as needed (e.g., 2 out of 3 parts)
            child: _buildPaymentDetailsSection(),
          ),
        ],
      ),
    );
  }
}
