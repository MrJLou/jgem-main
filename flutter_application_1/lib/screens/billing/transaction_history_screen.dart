import 'package:flutter/material.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  TransactionHistoryScreenState createState() => TransactionHistoryScreenState();
}

class TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final List<Map<String, String>> _transactions = [
    {'id': 'PT-1001', 'date': '2023-04-01', 'amount': '\$150.00'},
    {'id': 'PT-1002', 'date': '2023-04-02', 'amount': '\$200.00'},
  ];
  List<Map<String, String>> _filteredTransactions = [];

  void _searchTransactions() {
    final patientId = _patientIdController.text.trim();
    setState(() {
      _filteredTransactions = _transactions.where((t) => t['id'] == patientId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Transaction History',
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
              'Search Transaction History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _patientIdController,
              decoration: const InputDecoration(
                labelText: 'Enter Patient ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _searchTransactions,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
              child: const Text('Search'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _filteredTransactions.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : ListView.builder(
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _filteredTransactions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text('Date: ${transaction['date']}'),
                            subtitle: Text('Amount: ${transaction['amount']}'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}