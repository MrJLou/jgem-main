import 'package:flutter/material.dart';

class AddServiceScreen extends StatelessWidget {
  final TextEditingController _serviceCategoryController = TextEditingController();
  final TextEditingController _specificServiceController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDescriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add Service',
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
            TextField(
              controller: _serviceCategoryController,
              decoration: InputDecoration(
                labelText: 'Service Category',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _specificServiceController,
              decoration: InputDecoration(
                labelText: 'Specific Service',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _servicePriceController,
              decoration: InputDecoration(
                labelText: 'Service Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _serviceDescriptionController,
              decoration: InputDecoration(
                labelText: 'Service Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to save service details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Service added successfully!'),
                    backgroundColor: Colors.teal,
                  ),
                );
                Navigator.pop(context);
              },
              child: Text('Save Service'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            ),
          ],
        ),
      ),
    );
  }
}