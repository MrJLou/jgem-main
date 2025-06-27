import 'package:flutter/material.dart';
import 'user_guide_screen.dart';
import 'contact_support_screen.dart';
import 'faq_screen.dart';
import 'feedback_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How can we help you?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Select a category below to get started',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildHelpCard(
                      context,
                      icon: Icons.menu_book,
                      title: 'User Guide',
                      subtitle: 'Learn how to use the system with our comprehensive guide',
                      color: Colors.teal[700]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserGuideScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildHelpCard(
                      context,
                      icon: Icons.support_agent,
                      title: 'Contact Support',
                      subtitle: 'Get in touch with our dedicated support team',
                      color: Colors.teal[600]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildHelpCard(
                      context,
                      icon: Icons.question_answer,
                      title: 'FAQs',
                      subtitle: 'Find answers to commonly asked questions',
                      color: Colors.teal[500]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FAQScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildHelpCard(
                      context,
                      icon: Icons.rate_review,
                      title: 'Feedback',
                      subtitle: 'Share your thoughts and help us improve',
                      color: Colors.teal[400]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FeedbackScreen()),
                      ),
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
                  Icon(Icons.lightbulb_outline, color: Colors.teal[700]),
                  const SizedBox(width: 10),
                  const Text('Quick Tips'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Tap on any card to explore that section'),
                  SizedBox(height: 8),
                  Text('• Use the search feature in each section to find specific help topics'),
                  SizedBox(height: 8),
                  Text('• Contact support for urgent assistance'),
                  SizedBox(height: 8),
                  Text('• Check FAQs for quick answers to common questions'),
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
        child: const Icon(Icons.lightbulb_outline),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.teal[700],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Help Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Find guides and answers to your questions',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Our support team is available 24/7 to assist you with any questions or concerns',
                    style: TextStyle(
                      color: Colors.white.withAlpha(90),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(
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
          padding: const EdgeInsets.all(20.0),
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
                  size: 28,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 5),
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