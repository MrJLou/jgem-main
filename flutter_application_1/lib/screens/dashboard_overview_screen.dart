import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import '../services/api_service.dart';

class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  DashboardOverviewScreenState createState() => DashboardOverviewScreenState();
}

class DashboardOverviewScreenState extends State<DashboardOverviewScreen> {
  Future<Map<String, int>>? _statisticsFuture;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  void _fetchStatistics() {
    setState(() {
      _statisticsFuture = ApiService.getDashboardStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatistics,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/settings').then((_) => _fetchStatistics());
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _statisticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No statistics available.'));
          }

          final stats = snapshot.data!;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient Statistics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatisticCard(
                    icon: Icons.people,
                    iconColor: Colors.teal,
                    title: 'Total Patients',
                    value: stats['totalPatients'].toString(),
                  ),
                  const SizedBox(height: 8),
                  _buildStatisticCard(
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    title: 'Confirmed Appointments',
                    value: stats['confirmedAppointments'].toString(),
                  ),
                  const SizedBox(height: 8),
                  _buildStatisticCard(
                    icon: Icons.cancel,
                    iconColor: Colors.red,
                    title: 'Cancelled Appointments',
                    value: stats['cancelledAppointments'].toString(),
                  ),
                  const SizedBox(height: 8),
                  _buildStatisticCard(
                    icon: Icons.done_all,
                    iconColor: Colors.blue,
                    title: 'Completed Appointments',
                    value: stats['completedAppointments'].toString(),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const DashboardScreen(accessLevel: 'admin')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Go to Appointment Module',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
