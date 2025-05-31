import 'package:flutter/material.dart';

class ReportHubScreen extends StatelessWidget {
  final String accessLevel;
  const ReportHubScreen({super.key, required this.accessLevel});

  @override
  Widget build(BuildContext context) {
    // Placeholder onTap actions - replace with actual navigation
    VoidCallback placeholderOnTap = () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation to be implemented.')),
      );
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Hub', // Changed Title
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: !(accessLevel == 'admin'),
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
                    Icons.receipt_long_outlined, // Changed Icon
                    size: 32,
                    color: Colors.teal[800],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports', // Changed Title
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Generate and view various reports', // Subtitle is okay
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
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons.description,
                      title: 'Patient Reports',
                      subtitle: 'Generate patient-related reports',
                      color: Colors.teal[700]!,
                      onTap: placeholderOnTap, // Replace with actual navigation
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons.medical_services,
                      title: 'Treatment Reports',
                      subtitle: 'View treatment and procedure reports',
                      color: Colors.teal[600]!,
                      onTap: placeholderOnTap, // Replace with actual navigation
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons.science,
                      title: 'Laboratory Reports',
                      subtitle: 'Access laboratory test reports',
                      color: Colors.teal[500]!,
                      onTap: placeholderOnTap, // Replace with actual navigation
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons.receipt_long,
                      title: 'Financial Reports',
                      subtitle: 'View financial statements and summaries',
                      color: Colors.teal[400]!,
                      onTap: placeholderOnTap, // Replace with actual navigation
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

  // Copied from MaintenanceHubScreen and renamed _buildReportCard to _buildFeatureCard
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
                  color: color.withOpacity(0.1),
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
