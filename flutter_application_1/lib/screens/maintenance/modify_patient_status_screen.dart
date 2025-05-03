import 'package:flutter/material.dart';

class ModifyPatientStatusScreen extends StatelessWidget {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _patientStatusController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Modify Patient Status',
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
              controller: _patientIdController,
              decoration: InputDecoration(
                labelText: 'Enter Patient ID',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _patientStatusController,
              decoration: InputDecoration(
                labelText: 'Enter New Status',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to update patient status
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Patient status updated successfully!'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              child: Text('Update Status'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            ),
          ],
        ),
      ),
    );
  }
}