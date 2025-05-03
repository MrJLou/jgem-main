import 'package:flutter/material.dart';

class BackupScreen extends StatelessWidget {
  void _createBackup(BuildContext context) {
    // Simulate creating a backup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backup created successfully!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _restoreState(BuildContext context) {
    // Simulate restoring state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('State restored successfully!'),
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
          'Backup',
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
              'Backup Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.backup, color: Colors.teal[700]),
              title: Text('Create Backup'),
              onTap: () {
                _createBackup(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.restore, color: Colors.teal[700]),
              title: Text('Restore State'),
              onTap: () {
                _restoreState(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}