import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs',
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
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFAQCategory(
                        title: 'Getting Started',
                        faqs: [
                          {
                            'question': 'How do I log in to the system?',
                            'answer':
                                'To log in, enter your username and password on the login screen. If you\'ve forgotten your password, click on the "Forgot Password" link to reset it.',
                          },
                          {
                            'question': 'How do I change my password?',
                            'answer':
                                'Go to Settings > User Profile > Security, then click on "Change Password". Enter your current password and your new password twice to confirm.',
                          },
                          {
                            'question': 'What should I do if I\'m locked out?',
                            'answer':
                                'If you\'re locked out, contact your system administrator or use the "Forgot Password" feature. For immediate assistance, contact our support team.',
                          },
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFAQCategory(
                        title: 'Patient Management',
                        faqs: [
                          {
                            'question': 'How do I register a new patient?',
                            'answer':
                                'Click on "Registration" in the main menu, then select "Patient Registration". Fill in all required fields and click "Save" to register the patient.',
                          },
                          {
                            'question': 'How do I update patient information?',
                            'answer':
                                'Search for the patient using the search function, open their profile, click "Edit", make the necessary changes, and save the updates.',
                          },
                          {
                            'question': 'Can I merge duplicate patient records?',
                            'answer':
                                'Yes, but this requires administrator privileges. Contact your system administrator to merge duplicate records.',
                          },
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFAQCategory(
                        title: 'Appointments',
                        faqs: [
                          {
                            'question': 'How do I schedule an appointment?',
                            'answer':
                                'Go to the Appointments module, click "New Appointment", select the patient, choose date/time, and confirm the booking.',
                          },
                          {
                            'question': 'How do I cancel or reschedule?',
                            'answer':
                                'Find the appointment in the calendar, click on it, then select "Cancel" or "Reschedule". Follow the prompts to complete the action.',
                          },
                          {
                            'question': 'What is the cancellation policy?',
                            'answer':
                                'Appointments should be cancelled at least 24 hours in advance. Late cancellations may be subject to a fee.',
                          },
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFAQCategory(
                        title: 'Technical Issues',
                        faqs: [
                          {
                            'question': 'What do I do if the system is slow?',
                            'answer':
                                'Try clearing your browser cache, refreshing the page, or logging out and back in. If the issue persists, contact technical support.',
                          },
                          {
                            'question': 'How do I report a bug?',
                            'answer':
                                'Use the "Submit Feedback" option in the Help menu to report any bugs. Include as much detail as possible about what you were doing when the issue occurred.',
                          },
                          {
                            'question': 'Is my data being backed up?',
                            'answer':
                                'Yes, all data is automatically backed up every 24 hours. System administrators can also perform manual backups when needed.',
                          },
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implement contact support functionality
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.contact_support, color: Colors.teal[700]),
                  const SizedBox(width: 10),
                  const Text('Need More Help?'),
                ],
              ),
              content: const Text(
                'If you couldn\'t find the answer you\'re looking for, our support team is here to help!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to contact support
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                  ),
                  child: const Text('Contact Support'),
                ),
              ],
            ),
          );
        },
        backgroundColor: Colors.teal[700],
        child: const Icon(Icons.contact_support),
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
          hintText: 'Search FAQs...',
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

  Widget _buildFAQCategory({
    required String title,
    required List<Map<String, String>> faqs,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.teal[700]),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...faqs.map((faq) => _buildFAQItem(faq['question']!, faq['answer']!)),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 