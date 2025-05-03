import 'package:flutter/material.dart';

class InvoiceScreen extends StatefulWidget {
  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _invoiceDetails;

  // Mock data for invoices
  final Map<String, Map<String, dynamic>> _mockInvoices = {
    'PT-1001': {
      'name': 'John Doe',
      'services': [
        {'service': 'Consultation', 'cost': 50.0},
        {'service': 'Blood Test', 'cost': 30.0},
        {'service': 'X-Ray', 'cost': 100.0},
      ],
      'surcharges': 20.0,
    },
    'PT-1002': {
      'name': 'Jane Smith',
      'services': [
        {'service': 'Consultation', 'cost': 60.0},
        {'service': 'MRI', 'cost': 200.0},
      ],
      'surcharges': 25.0,
    },
  };

  void _fetchInvoice() {
    setState(() => _isLoading = true);

    final patientId = _patientIdController.text.trim();
    final patientName = _patientNameController.text.trim();

    // Simulate fetching invoice details
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _invoiceDetails = _mockInvoices[patientId] ??
            _mockInvoices.values.firstWhere(
              (invoice) => invoice['name'] == patientName,
              orElse: () => {},
            );
      });

      if (_invoiceDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No invoice found for the given details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Invoice',
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
              'Search Invoice',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _patientIdController,
              decoration: InputDecoration(
                labelText: 'Enter Patient ID',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _patientNameController,
              decoration: InputDecoration(
                labelText: 'Enter Patient Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchInvoice,
              child: Text('Search'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_invoiceDetails != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice for ${_invoiceDetails!['name']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _invoiceDetails!['services'].length,
                        itemBuilder: (context, index) {
                          final service = _invoiceDetails!['services'][index];
                          return ListTile(
                            title: Text(service['service']),
                            trailing: Text('\$${service['cost'].toStringAsFixed(2)}'),
                          );
                        },
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('Surcharges'),
                      trailing: Text(
                          '\$${_invoiceDetails!['surcharges'].toStringAsFixed(2)}'),
                    ),
                    ListTile(
                      title: Text(
                        'Total Charges',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '\$${(_invoiceDetails!['services']
                                    .fold(0.0, (sum, item) => sum + item['cost']) +
                                _invoiceDetails!['surcharges'])
                            .toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Logic to generate invoice
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invoice generated successfully!'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          },
                          child: Text('Generate Invoice'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700]),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Logic to download invoice
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invoice downloaded successfully!'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          },
                          child: Text('Download'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Text(
                  'No invoice details available.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}