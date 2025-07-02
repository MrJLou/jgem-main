import 'package:flutter/material.dart';
import '../../utils/error_dialog_utils.dart';

class AddServiceScreen extends StatelessWidget {
  final TextEditingController _serviceCategoryController = TextEditingController();
  final TextEditingController _specificServiceController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDescriptionController = TextEditingController();

  AddServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
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
              decoration: const InputDecoration(
                labelText: 'Service Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _specificServiceController,
              decoration: const InputDecoration(
                labelText: 'Specific Service',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _servicePriceController,
              decoration: const InputDecoration(
                labelText: 'Service Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _serviceDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Service Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to save service details
                ErrorDialogUtils.showSuccessDialog(
                  context: context,
                  title: 'Success',
                  message: 'Service added successfully!',
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.pop(context); // Go back to previous screen
                  },
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
              child: const Text('Save Service'),
            ),
          ],
        ),
      ),
    );
  }
}