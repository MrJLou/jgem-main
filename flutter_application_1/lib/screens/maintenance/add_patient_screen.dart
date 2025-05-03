import 'package:flutter/material.dart';

class AddPatientScreen extends StatelessWidget {
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  final TextEditingController _patientGenderController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add Patient',
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
              controller: _patientNameController,
              decoration: InputDecoration(
                labelText: 'Patient Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _patientIdController,
              decoration: InputDecoration(
                labelText: 'Patient ID',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _patientAgeController,
              decoration: InputDecoration(
                labelText: 'Patient Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _patientGenderController,
              decoration: InputDecoration(
                labelText: 'Patient Gender',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to save patient details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Patient added successfully!'),
                    backgroundColor: Colors.teal,
                  ),
                );
                Navigator.pop(context);
              },
              child: Text('Save Patient'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            ),
          ],
        ),
      ),
    );
  }
}