import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentSearchScreen extends StatefulWidget {
  @override
  _PaymentSearchScreenState createState() => _PaymentSearchScreenState();
}

class _PaymentSearchScreenState extends State<PaymentSearchScreen> {
  final TextEditingController _referenceController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  Map<String, dynamic>? _paymentData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Payment Search',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find Payment Records',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Search by payment reference number',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              shadowColor: Colors.teal.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _referenceController,
                      label: 'Reference Number',
                      icon: Icons.receipt,
                      hintText: 'Enter payment reference',
                    ),
                    SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _searchPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'SEARCH PAYMENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_hasSearched) ...[
              SizedBox(height: 30),
              if (_paymentData != null)
                _buildPaymentDetails()
              else
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: Colors.orange[700]),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'No payment found with this reference',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.teal[700]),
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
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        labelStyle: TextStyle(color: Colors.grey[600]),
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
        padding: EdgeInsets.all(20),
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
            SizedBox(height: 15),
            
            _buildDetailRow('Reference Number', _paymentData!['reference']),
            _buildDetailRow('Date & Time', _paymentData!['date']),
            _buildDetailRow('Patient Name', _paymentData!['patientName']),
            _buildDetailRow('Service Provided', _paymentData!['service']),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(15),
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
                    '£${_paymentData!['amount']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            _buildDetailRow('Payment Method', _paymentData!['method']),
            _buildDetailRow('Payment Status', _paymentData!['status']),
            
            if (_paymentData!['notes'] != null && _paymentData!['notes'].isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  _paymentData!['notes'],
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
            
                SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
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
                SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
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
      padding: EdgeInsets.symmetric(vertical: 8),
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
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _searchPayment() {
    if (_referenceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a reference number to search'),
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

    // Simulate API call delay
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        // Mock payment data - replace with actual API call
        _paymentData = {
          'reference': 'PAY-${DateTime.now().year}-${_referenceController.text}',
          'date': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
          'patientName': 'John Doe',
          'service': 'General Consultation + Blood Test',
          'amount': '125.00',
          'method': 'Credit Card (VISA ****4242)',
          'status': 'Completed',
          'notes': 'Payment processed successfully. Receipt emailed to johndoe@example.com'
        };
      });
    });
  }

  // Add this at the top of your file
  // import 'package:intl/intl.dart';
}