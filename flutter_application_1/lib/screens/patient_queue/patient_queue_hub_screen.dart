import 'package:flutter/material.dart';
import 'add_to_queue_screen.dart';
import 'remove_from_queue_screen.dart';
import 'view_queue_screen.dart';
import 'queue_reports_screen.dart';
import '../../services/queue_service.dart';

class PatientQueueHubScreen extends StatefulWidget {
  final String accessLevel;
  const PatientQueueHubScreen({super.key, required this.accessLevel});

  @override
  PatientQueueHubScreenState createState() => PatientQueueHubScreenState();
}

class PatientQueueHubScreenState extends State<PatientQueueHubScreen> {
  final QueueService _queueService = QueueService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Queue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: !(widget.accessLevel == 'admin'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 32,
                    color: Colors.teal[800],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Queue',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Manage daily queue and reports',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.person_add,
                      title: 'Add to Queue',
                      subtitle: 'Add new patients to today\'s queue',
                      color: Colors.teal[700]!,                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddToQueueScreen(queueService: _queueService),
                        ),
                      ).then((_) {
                        if (!mounted) return;
                        // Refresh B-Tree if it exists
                        ViewQueueScreen.refreshBTreeIfExists();
                        setState(() {});
                      }),
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      context,
                      icon: Icons.person_remove,
                      title: 'Remove from Queue',
                      subtitle: 'Remove patients from today\'s queue',
                      color: Colors.teal[600]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RemoveFromQueueScreen(
                              queueService: _queueService),
                        ),
                      ).then((_) {
                        if (!mounted) return;
                        setState(() {});
                      }),
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      context,
                      icon: Icons.list,
                      title: 'View Queue',
                      subtitle: 'View current patient queue',
                      color: Colors.teal[500]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewQueueScreen(queueService: _queueService),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      context,
                      icon: Icons.analytics,
                      title: 'Queue Reports',
                      subtitle: 'View daily reports and export as PDF',
                      color: Colors.teal[400]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QueueReportsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
