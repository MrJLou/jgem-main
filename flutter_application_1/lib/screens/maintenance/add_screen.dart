import 'package:flutter/material.dart';
import 'add_patient_screen.dart';
import 'add_service_screen.dart';

class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Add',
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
              'Add Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.person_add, color: Colors.teal[700]),
              title: const Text('Add Patient'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPatientScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: Colors.teal[700]),
              title: const Text('Add Service'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddServiceScreen(),
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