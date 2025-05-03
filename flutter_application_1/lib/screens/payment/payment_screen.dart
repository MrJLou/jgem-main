import 'package:flutter/material.dart';
import 'transaction_history_screen.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountPaidController = TextEditingController();
  final double _totalAmount = 150.0; // Example total amount
  bool _isPaymentProcessed = false;
  double _change = 0.0;

  void _processPayment() {
    final double? amountPaid = double.tryParse(_amountPaidController.text);
    if (amountPaid == null || amountPaid < _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient amount paid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPaymentProcessed = true;
      _change = amountPaid - _totalAmount;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment processed successfully!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _generateReceipt() {
    if (!_isPaymentProcessed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please process the payment first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt generated successfully!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _receiveChange() {
    if (!_isPaymentProcessed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please process the payment first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Change of \$${_change.toStringAsFixed(2)} received successfully!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Payment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 10),
            ListTile(
              title: Text('Total Amount'),
              trailing: Text('\$${_totalAmount.toStringAsFixed(2)}'),
            ),
            Divider(),
            TextField(
              controller: _amountPaidController,
              decoration: InputDecoration(
                labelText: 'Enter Amount Paid',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _processPayment,
              child: Text('Process Payment'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.receipt, color: Colors.teal[700]),
              title: Text('Generate Receipt'),
              onTap: _generateReceipt,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.money_off, color: Colors.teal[700]),
              title: Text('Receive Change'),
              subtitle: _isPaymentProcessed
                  ? Text('Change: \$${_change.toStringAsFixed(2)}')
                  : null,
              onTap: _receiveChange,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.history, color: Colors.teal[700]),
              title: Text('Transaction History'),
              onTap: () {
                // Navigate to transaction history
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionHistoryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}