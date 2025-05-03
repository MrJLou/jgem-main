import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Help',
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
              'Help & Navigation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Select a module to learn more or navigate directly.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _HelpCard(
                    icon: Icons.people,
                    title: 'Registration',
                    subtitle: 'Manage patient registrations.',
                    color: Colors.teal[700]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/registration');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.search,
                    title: 'Search',
                    subtitle: 'Search for patients, payments, or services.',
                    color: Colors.teal[600]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/search');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.calendar_today,
                    title: 'Appointments',
                    subtitle: 'View and manage appointments.',
                    color: Colors.teal[500]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/appointments');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.people_alt,
                    title: 'Patient Queue',
                    subtitle: 'Manage the patient queue.',
                    color: Colors.teal[400]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/patientQueue');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.analytics,
                    title: 'Patient Analytics',
                    subtitle: 'Analyze patient data and statistics.',
                    color: Colors.teal[300]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/analytics');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.report,
                    title: 'Reports',
                    subtitle: 'Generate and view reports.',
                    color: Colors.teal[200]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/reports');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.receipt,
                    title: 'Billing',
                    subtitle: 'Manage invoices and transactions.',
                    color: Colors.teal[100]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/billing');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.payment,
                    title: 'Payment',
                    subtitle: 'Process payments and view history.',
                    color: Colors.teal[50]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/payment');
                    },
                  ),
                  SizedBox(height: 20),
                  _HelpCard(
                    icon: Icons.settings,
                    title: 'Maintenance',
                    subtitle: 'Update, add, or back up data.',
                    color: Colors.teal[700]!,
                    onTap: () {
                      Navigator.pop(context); // Close Help Screen
                      Navigator.pushNamed(context, '/maintenance');
                    },
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

class _HelpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HelpCard({
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