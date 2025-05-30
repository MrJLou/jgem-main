import 'package:flutter/material.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: Colors.teal[700],
      ),
      body: const Center(
        child: Text('System Settings - Content Coming Soon!'),
      ),
    );
  }
}
