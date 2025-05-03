import 'package:flutter/material.dart';
import 'add_to_queue_screen.dart';
import 'remove_from_queue_screen.dart';
import 'view_queue_screen.dart';

class PatientQueueHubScreen extends StatefulWidget {
  @override
  _PatientQueueHubScreenState createState() => _PatientQueueHubScreenState();
}

class _PatientQueueHubScreenState extends State<PatientQueueHubScreen> {
  List<Map<String, dynamic>> _queue = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Patient Queue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queue Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Select an option to manage the patient queue',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _QueueCard(
                    icon: Icons.add_circle_outline,
                    title: 'Add to Queue',
                    subtitle: 'Add patients to the queue',
                    color: Colors.teal[700]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddToQueueScreen(queue: _queue),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _QueueCard(
                    icon: Icons.remove_circle_outline,
                    title: 'Remove from Queue',
                    subtitle: 'Remove patients from the queue',
                    color: Colors.teal[600]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RemoveFromQueueScreen(queue: _queue),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _QueueCard(
                    icon: Icons.view_list,
                    title: 'View Queue',
                    subtitle: 'View the current patient queue',
                    color: Colors.teal[500]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewQueueScreen(queue: _queue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QueueCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: color.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[900],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
