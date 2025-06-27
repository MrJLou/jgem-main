// Welcome section widget for dashboard
import 'package:flutter/material.dart';

class DashboardWelcomeSection extends StatelessWidget {
  const DashboardWelcomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.cyan.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome',
                  style: TextStyle(
                      fontSize: 16, color: Colors.white.withAlpha(230)),
                ),
                const Text(
                  'Valued User',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'To keep the body in good health is a duty... otherwise we shall not be able to keep our mind strong and clear.',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(217),
                      height: 1.4),
                ),
              ],
            ),
          ),
          Icon(Icons.medical_services_outlined,
              size: 100, color: Colors.white.withAlpha(26))
        ],
      ),
    );
  }
}
