import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/logs/user_activity_log_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blueGrey),
            title: const Text('User Activity Logs'),
            subtitle: const Text('View system and user activity logs.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UserActivityLogScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: const Text('Reset Database'),
            subtitle: const Text('Deletes all patient data, appointments, and records. This action cannot be undone.'),
            onTap: () => _showResetConfirmationDialog(context),
          ),
          // Add other settings options here
        ],
      ),
    );
  }

  Future<void> _showResetConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Database Reset'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to reset the database?'),
                Text('All data, except for the admin user and clinic services, will be permanently deleted.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Reset'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the confirmation dialog
                _performReset(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performReset(BuildContext context) async {
    try {
      await ApiService.resetDatabase();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database has been reset successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 