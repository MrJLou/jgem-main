import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class DashboardOverviewScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Overview', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.people, color: Colors.teal),
                title: Text('Total Patients'),
                trailing: Text('120', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Confirmed Appointments'),
                trailing: Text('45', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.cancel, color: Colors.red),
                title: Text('Cancelled Appointments'),
                trailing: Text('10', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.done_all, color: Colors.blue),
                title: Text('Completed Appointments'),
                trailing: Text('65', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DashboardScreen(accessLevel: 'admin')),
                  );
                },
                child: Text('Go to Appointment Module'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 254, 254, 254),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}