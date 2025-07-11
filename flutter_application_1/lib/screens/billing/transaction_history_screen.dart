import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_helper.dart';
import '../../services/database_sync_client.dart';
import 'dart:async';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  TransactionHistoryScreenState createState() => TransactionHistoryScreenState();
}

class TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
    _setupSyncListener();
  }

  void _setupSyncListener() {
    _syncSubscription = DatabaseSyncClient.syncUpdates.listen((updateEvent) {
      if (!mounted) return;
      
      // Handle payment/billing changes
      switch (updateEvent['type']) {
        case 'remote_change_applied':
        case 'database_change':
          final change = updateEvent['change'] as Map<String, dynamic>?;
          if (change != null && (change['table'] == 'payments' || 
                                change['table'] == 'patient_bills')) {
            // Refresh transactions when payments or bills change
            if (_hasSearched) {
              _searchTransactions();
            } else {
              _loadRecentTransactions();
            }
          }
          break;
        case 'ui_refresh_requested':
          // Periodic refresh for transaction updates
          if (DateTime.now().millisecondsSinceEpoch % 30000 < 2000) {
            if (_hasSearched) {
              _searchTransactions();
            } else {
              _loadRecentTransactions();
            }
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _patientIdController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load last 20 transactions by default
      final transactions = await _dbHelper.getPaymentTransactions();
      setState(() {
        _transactions = transactions.take(20).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load transactions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchTransactions() async {
    final patientId = _patientIdController.text.trim();
    final patientName = _patientNameController.text.trim();
    final invoiceNumber = _invoiceController.text.trim();
    
    if (patientId.isEmpty && patientName.isEmpty && invoiceNumber.isEmpty) {
      _loadRecentTransactions();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final transactions = await _dbHelper.getPaymentTransactions(
        patientId: patientId.isNotEmpty ? patientId : null,
        patientName: patientName.isNotEmpty ? patientName : null,
        invoiceNumber: invoiceNumber.isNotEmpty ? invoiceNumber : null,
      );
      
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: ${e.toString()}';
        _isLoading = false;
        _transactions = [];
      });
    }
  }

  void _clearSearch() {
    _patientIdController.clear();
    _patientNameController.clear();
    _invoiceController.clear();
    setState(() {
      _hasSearched = false;
      _errorMessage = null;
    });
    _loadRecentTransactions();
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
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Transactions',
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
                          child: TextField(
                            controller: _patientIdController,
                            decoration: const InputDecoration(
                              labelText: 'Patient ID',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _patientNameController,
                            decoration: const InputDecoration(
                              labelText: 'Patient Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _invoiceController,
                            decoration: const InputDecoration(
                              labelText: 'Invoice Number (optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.receipt),
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox()), // Empty space for alignment
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _searchTransactions,
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
                          label: Text(_isLoading ? 'Searching...' : 'Search'),
                        ),
                        const SizedBox(width: 12),
                        if (_hasSearched)
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
                  : _transactions.isEmpty
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
                                _hasSearched 
                                    ? 'No transactions found for your search'
                                    : 'No transactions found',
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
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final paymentDate = DateTime.parse(transaction['paymentDate'] as String);
    final amountPaid = (transaction['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final patientName = transaction['patient_name'] as String? ?? 'Unknown Patient';
    final invoiceNumber = transaction['invoiceNumber'] as String? ?? 
                         transaction['bill_invoice_number'] as String? ?? 'N/A';
    final referenceNumber = transaction['referenceNumber'] as String? ?? 'N/A';
    final paymentMethod = transaction['paymentMethod'] as String? ?? 'N/A';

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
                        'Ref: $referenceNumber',
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
                      '₱${amountPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(paymentDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDetailChip('Invoice', invoiceNumber),
                const SizedBox(width: 8),
                _buildDetailChip('Method', paymentMethod),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.teal[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}