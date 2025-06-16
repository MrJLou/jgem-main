// Doctors section widget for dashboard
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class DashboardDoctorsSection extends StatefulWidget {
  const DashboardDoctorsSection({super.key});

  @override
  State<DashboardDoctorsSection> createState() => _DashboardDoctorsSectionState();
}

class _DashboardDoctorsSectionState extends State<DashboardDoctorsSection> {
  List<User> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final allUsers = await ApiService.getUsers();
      if (mounted) {
        setState(() {
          _doctors = allUsers.where((user) => user.role == 'doctor').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctors = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Doctors",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _doctors.isEmpty
                    ? Center(
                        child: Text(
                          'No doctors available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _doctors.length,
                        itemBuilder: (context, index) {
                          return _buildDoctorCard(_doctors[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }  Widget _buildDoctorCard(User doctor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.teal[50],
              child: Icon(
                Icons.person,
                size: 24,
                color: Colors.teal[700],
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                'Dr. ${doctor.fullName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Doctor',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
