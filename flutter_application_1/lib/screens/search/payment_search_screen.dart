import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class PaymentSearchScreen extends StatefulWidget {
  const PaymentSearchScreen({super.key});

  @override
  _PaymentSearchScreenState createState() => _PaymentSearchScreenState();
}

class _PaymentSearchScreenState extends State<PaymentSearchScreen> {
  final TextEditingController _referenceController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _paymentData = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPaymentType = 'all';
  final List<Map<String, String>> _paymentTypes = [
    {'value': 'all', 'label': 'All Payment Types'},
    {'value': 'card', 'label': 'Card Payment'},
    {'value': 'cash', 'label': 'Cash Payment'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Payment Search',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchCard(),
            if (_hasSearched) ...[
              const SizedBox(height: 24),
              if (_paymentData.isNotEmpty)
                _buildPaymentDetails()
              else
                _buildNoResultsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.teal[700],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal[700]!,
            Colors.teal[800]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Payment Records',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: Text(
                'Search and manage payment transactions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: Colors.teal.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Payments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Reference Number',
                hintText: 'Enter payment reference',
                prefixIcon: Icon(Icons.receipt, color: Colors.teal[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal[700]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                labelStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      prefixIcon: Icon(Icons.calendar_today, color: Colors.teal[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: _startDate != null
                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                          : '',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      prefixIcon: Icon(Icons.calendar_today, color: Colors.teal[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: _endDate != null
                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                          : '',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPaymentType,
                        isExpanded: true,
                        items: _paymentTypes.map((type) {
                          return DropdownMenuItem(
                            value: type['value'],
                            child: Text(type['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPaymentType = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Show advanced filters
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('More'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchPayment,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isLoading ? 'SEARCHING...' : 'SEARCH PAYMENTS',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PAYMENT DETAILS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.print, color: Colors.teal[700]),
                  onPressed: () {},
                  tooltip: 'Print Receipt',
                ),
              ],
            ),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 15),
            
            _buildDetailRow('Reference Number', _paymentData[0]['reference']),
            _buildDetailRow('Date & Time', _paymentData[0]['date']),
            _buildDetailRow('Patient Name', _paymentData[0]['patientName']),
            _buildDetailRow('Service Provided', _paymentData[0]['service']),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount Paid',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '£${_paymentData[0]['amount']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _buildDetailRow('Payment Method', _paymentData[0]['method']),
            _buildDetailRow('Payment Status', _paymentData[0]['status']),
            
            if (_paymentData[0]['notes'] != null && _paymentData[0]['notes'].isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  _paymentData[0]['notes'],
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
            
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: Colors.teal[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'EMAIL RECEIPT',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'CREATE NEW PAYMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchPayment() async {
    if (_referenceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a reference number to search'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Create dummy payment data for testing
      _paymentData = [
        {
          'reference': 'PAY001',
          'date': '15/03/2024 14:30',
          'patientName': 'John Smith',
          'service': 'General Consultation',
          'amount': '75.00',
          'method': 'Card Payment',
          'status': 'Completed',
          'notes': 'Payment received successfully',
        },
        {
          'reference': 'PAY002',
          'date': '15/03/2024 15:45',
          'patientName': 'Mary Johnson',
          'service': 'Complete Blood Count',
          'amount': '45.00',
          'method': 'Cash Payment',
          'status': 'Completed',
          'notes': '',
        },
        {
          'reference': 'PAY003',
          'date': '15/03/2024 16:15',
          'patientName': 'David Wilson',
          'service': 'X-Ray Chest',
          'amount': '120.00',
          'method': 'Card Payment',
          'status': 'Pending',
          'notes': 'Awaiting authorization',
        }
      ];

      // Filter by reference number
      if (_referenceController.text.isNotEmpty) {
        final searchTerm = _referenceController.text.toLowerCase();
        _paymentData = _paymentData.where((payment) =>
          payment['reference'].toString().toLowerCase().contains(searchTerm)
        ).toList();
      }

      // Filter by date range
      if (_startDate != null) {
        _paymentData = _paymentData.where((payment) {
          final paymentDate = DateFormat('dd/MM/yyyy HH:mm').parse(payment['date']);
          return paymentDate.isAfter(_startDate!) || paymentDate.isAtSameMomentAs(_startDate!);
        }).toList();
      }

      if (_endDate != null) {
        _paymentData = _paymentData.where((payment) {
          final paymentDate = DateFormat('dd/MM/yyyy HH:mm').parse(payment['date']);
          return paymentDate.isBefore(_endDate!) || paymentDate.isAtSameMomentAs(_endDate!);
        }).toList();
      }

      // Filter by payment type
      if (_selectedPaymentType != 'all') {
        _paymentData = _paymentData.where((payment) =>
          payment['method'] == (_selectedPaymentType == 'card' ? 'Card Payment' : 'Cash Payment')
        ).toList();
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _paymentData = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for payment: ${e.toString()}'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildNoResultsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Payment Records Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search criteria or date range',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _referenceController.clear();
                  _hasSearched = false;
                  _paymentData = [];
                  _startDate = null;
                  _endDate = null;
                  _selectedPaymentType = 'all';
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal[700],
                side: BorderSide(color: Colors.teal[700]!),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}