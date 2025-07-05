import 'package:flutter/material.dart';
import 'consultation_results_screen.dart';

class ConsultationHubScreen extends StatefulWidget {
  final String accessLevel;

  const ConsultationHubScreen({
    super.key,
    required this.accessLevel,
  });

  @override
  ConsultationHubScreenState createState() => ConsultationHubScreenState();
}

class ConsultationHubScreenState extends State<ConsultationHubScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.accessLevel.toLowerCase() == 'medtech' ? 'Laboratory' : 'Consultation'} Hub',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[600]!, Colors.teal[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.accessLevel.toLowerCase() == 'medtech'
                            ? Icons.science
                            : Icons.medical_services,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.accessLevel.toLowerCase() == 'medtech'
                                  ? 'Laboratory Management'
                                  : 'Consultation Management',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.accessLevel.toLowerCase() == 'medtech'
                                  ? 'Record and manage laboratory test results for patients in consultation'
                                  : 'Record and manage consultation notes and patient care documentation',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feature cards
            const Text(
              'Available Features',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: widget.accessLevel.toLowerCase() == 'medtech'
                  ? Icons.biotech
                  : Icons.edit_note,
              title: widget.accessLevel.toLowerCase() == 'medtech'
                  ? 'Record Lab Results'
                  : 'Record Consultation',
              description: widget.accessLevel.toLowerCase() == 'medtech'
                  ? 'Input and save laboratory test results for patients currently in consultation'
                  : 'Document consultation notes, diagnosis, and treatment plans for patients',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConsultationResultsScreen(
                      accessLevel: widget.accessLevel,
                    ),
                  ),
                );
              },
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            // Quick stats or info section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.grey[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.accessLevel.toLowerCase() == 'medtech'
                        ? '• Only patients currently "in consultation" status can have lab results recorded\n'
                            '• Lab results are automatically saved to the patient\'s medical record\n'
                            '• Results can be linked to specific laboratory services selected\n'
                            '• All entries are timestamped and linked to your user account'
                        : '• Only patients currently "in consultation" status can have notes recorded\n'
                            '• Consultation notes are saved to the patient\'s medical record\n'
                            '• Include diagnosis, treatment plans, and prescriptions\n'
                            '• All entries are timestamped and linked to your user account',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
