// Doctors section widget for dashboard
import 'package:flutter/material.dart';

class DashboardDoctorsSection extends StatelessWidget {
  const DashboardDoctorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Doctors",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDoctorCard('Dr. James Wilson', 'Orthopedic',
                    'assets/images/doctor_male1.png', '11:30 am to 3:30 pm'),
                _buildDoctorCard('Dr. Eric Rodriguez', 'Cardiology',
                    'assets/images/doctor_male2.png', '10:00 am to 2:30 pm'),
                _buildDoctorCard('Dr. Lora Wallace', 'Neurology',
                    'assets/images/doctor_female1.png', '3:00 pm to 6:00 pm'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(String name, String specialty, String imagePath, String availability) {
    Widget imageWidget;
    if (imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(
        imagePath,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.person, size: 30, color: Colors.grey[400])),
      );
    } else {
      imageWidget = CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, size: 30, color: Colors.grey[400]));
    }
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.teal[50],
              child: ClipOval(
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 10),
            Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(specialty,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (index) =>
                      Icon(Icons.star, color: Colors.amber[600], size: 13)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 11, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(availability,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
