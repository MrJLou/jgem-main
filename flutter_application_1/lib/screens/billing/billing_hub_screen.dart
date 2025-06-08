import 'package:flutter/material.dart';
import 'invoice_screen.dart'; // Import the InvoiceScreen
// Import specific screens if they exist, e.g.:
// import 'create_invoice_screen.dart';
// import 'billing_history_screen.dart';
// import 'pending_bills_screen.dart';
// import 'billing_settings_screen.dart';

class BillingHubScreen extends StatelessWidget {
  const BillingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder onTap actions - replace with actual navigation
    placeholderOnTap() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation to be implemented.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Hub', // Changed Title
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
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
                    Icons.request_quote_outlined, // Changed Icon
                    size: 32,
                    color: Colors.teal[800],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Billing', // Title is okay
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Manage patient billing and invoices', // Subtitle is okay
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
                      icon: Icons.receipt_long_outlined, // More specific icon
                      title: 'Create Invoice',
                      subtitle: 'Generate new patient invoices',
                      color: Colors.teal[700]!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => InvoiceScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon: Icons
                          .history_toggle_off_outlined, // More specific icon
                      title: 'Billing History',
                      subtitle: 'View past billing records',
                      color: Colors.teal[600]!,
                      onTap: placeholderOnTap, // Replace with actual navigation
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon:
                          Icons.pending_actions_outlined, // More specific icon
                      title: 'Pending Bills',
                      subtitle: 'View unpaid invoices',
                      color: Colors.teal[500]!,
                      onTap: placeholderOnTap, // Replace with actual navigation
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      // Changed to _buildFeatureCard
                      context,
                      icon:
                          Icons.settings_suggest_outlined, // More specific icon
                      title: 'Billing Settings',
                      subtitle: 'Configure billing preferences',
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

  // Copied from MaintenanceHubScreen and renamed _buildBillingCard to _buildFeatureCard
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
