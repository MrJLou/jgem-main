import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[50]!, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSearchBar(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Getting Started',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildGuideSection(
                      title: 'System Overview',
                      items: [
                        'Introduction to the System',
                        'Navigation Guide',
                        'Key Features',
                        'User Roles and Permissions',
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Core Features',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildGuideSection(
                      title: 'Patient Management',
                      items: [
                        'Patient Registration',
                        'Updating Patient Information',
                        'Managing Patient Records',
                        'Patient Search and Filters',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildGuideSection(
                      title: 'Appointments',
                      items: [
                        'Scheduling Appointments',
                        'Managing Calendar',
                        'Appointment Reminders',
                        'Cancellation Policy',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildGuideSection(
                      title: 'Medical Records',
                      items: [
                        'Creating Medical Records',
                        'Updating Patient History',
                        'Managing Test Results',
                        'Prescriptions and Medications',
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Advanced Features',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildGuideSection(
                      title: 'Reports and Analytics',
                      items: [
                        'Generating Reports',
                        'Data Analysis',
                        'Custom Reports',
                        'Export Options',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildGuideSection(
                      title: 'System Settings',
                      items: [
                        'User Preferences',
                        'System Configuration',
                        'Security Settings',
                        'Backup and Recovery',
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.tips_and_updates, color: Colors.teal[700]),
                  const SizedBox(width: 10),
                  const Text('Pro Tips'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Use the search bar to quickly find specific topics'),
                  SizedBox(height: 8),
                  Text('• Tap on any section to expand and view detailed instructions'),
                  SizedBox(height: 8),
                  Text('• Bookmark frequently accessed guides for quick reference'),
                  SizedBox(height: 8),
                  Text('• Check for regular updates to the user guide'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
        },
        backgroundColor: Colors.teal[700],
        child: const Icon(Icons.tips_and_updates),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal[700],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search guides...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required String title,
    required List<String> items,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: Icon(Icons.article_outlined, color: Colors.teal[700]),
          childrenPadding: const EdgeInsets.all(20),
          children: items.map((item) => _buildGuideItem(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildGuideItem(String title) {
    return InkWell(
      onTap: () {
        // Navigate to detailed guide page
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.article, color: Colors.grey[600], size: 20),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
} 