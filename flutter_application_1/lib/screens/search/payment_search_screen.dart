import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/database_helper.dart';
import '../../models/payment.dart';

class PaymentSearchScreen extends StatefulWidget {
  const PaymentSearchScreen({super.key});

  @override
  _PaymentSearchScreenState createState() => _PaymentSearchScreenState();
}

class _PaymentSearchScreenState extends State<PaymentSearchScreen> {
  final TextEditingController _referenceController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _paymentResults = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPaymentType = 'all';
  final List<Map<String, String>> _paymentTypes = [
    {'value': 'all', 'label': 'All Payment Types'},
    {'value': 'Cash', 'label': 'Cash Payment'},
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();

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
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_paymentResults.isNotEmpty)
                _buildPaymentResultsList()
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
                'Search and manage payment transactions by Reference Number',
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
                hintText: 'Enter payment reference (e.g., PAY-XXXXXX)',
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
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                labelStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Start Date (Optional)',
                      prefixIcon:
                          Icon(Icons.calendar_today, color: Colors.teal[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: _startDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _startDate = null))
                          : null,
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
                      labelText: 'End Date (Optional)',
                      prefixIcon:
                          Icon(Icons.calendar_today, color: Colors.teal[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: _endDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _endDate = null))
                          : null,
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
                        firstDate: _startDate ?? DateTime(2000),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                            value: type['value']!,
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
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchPayments,
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
                  foregroundColor: Colors.white,
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

  Widget _buildPaymentResultsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _paymentResults.length,
      itemBuilder: (context, index) {
        final payment = _paymentResults[index];
        DateTime paymentDate =
            DateTime.tryParse(payment['paymentDate'] ?? '') ?? DateTime.now();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ref: ${payment['referenceNumber'] ?? 'N/A'}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800]),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Divider(height: 15),
                _buildDetailRow(
                    'Patient Name:', payment['patient_name'] ?? 'N/A'),
                _buildDetailRow('Amount Paid:',
                    '₱${(payment['amountPaid'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                _buildDetailRow(
                    'Payment Method:', payment['paymentMethod'] ?? 'N/A'),
                _buildDetailRow(
                    'Received By:',
                    payment['received_by_user_name'] ??
                        payment['receivedByUserId'] ??
                        'N/A'),
                if (payment['notes'] != null && payment['notes'].isNotEmpty)
                  _buildDetailRow('Notes:', payment['notes']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchPayments() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _paymentResults = [];
    });

    try {
      final results = await _dbHelper.searchPayments(
        reference: _referenceController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        paymentType:
            _selectedPaymentType == 'all' ? null : _selectedPaymentType,
      );

      setState(() {
        _paymentResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _paymentResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching payments: ${e.toString()}'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Payment Records Found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No payments match your search criteria.\nPlease check the Reference Number or adjust filters and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _referenceController.clear();
                  _hasSearched = false;
                  _paymentResults = [];
                  _startDate = null;
                  _endDate = null;
                  _selectedPaymentType = 'all';
                  _isLoading = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal[700],
                side: BorderSide(color: Colors.teal[700]!),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
