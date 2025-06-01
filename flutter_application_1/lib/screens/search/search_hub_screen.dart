import 'package:flutter/material.dart';
import 'patient_search_screen.dart';
import 'payment_search_screen.dart';
import 'service_search_screen.dart';

class SearchHubScreen extends StatelessWidget {
  final String accessLevel;
  const SearchHubScreen({super.key, required this.accessLevel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Hub',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading:
            !(accessLevel == 'admin'), // Hide back button for admin
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
                    Icons.search_outlined, // Changed Icon
                    size: 32,
                    color: Colors.teal[800],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search', // Changed Title
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Find patients, records, and more', // Changed Subtitle
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
                      icon: Icons.person_search,
                      title: 'Patient Search',
                      subtitle: 'Find patient medical records and history',
                      color: Colors.teal[700]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PatientSearchScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons.payment,
                      title: 'Payment Search',
                      subtitle: 'View payment transactions and invoices',
                      color: Colors.teal[600]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PaymentSearchScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons.medical_services,
                      title: 'Service Search',
                      subtitle: 'Explore available medical services',
                      color: Colors.teal[500]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ServiceSearchScreen()),
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

  // Copied from MaintenanceHubScreen and renamed _SearchCard to _buildFeatureCard
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
