// Metrics section widget for dashboard
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/queue_service.dart';

class DashboardMetricsSection extends StatefulWidget {
  const DashboardMetricsSection({super.key});

  @override
  State<DashboardMetricsSection> createState() => _DashboardMetricsSectionState();
}

class _DashboardMetricsSectionState extends State<DashboardMetricsSection> {
  int _totalAppointmentsToday = 0;
  int _currentQueueNumber = 0;
  int _availableDoctors = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    
    // Refresh metrics every 20 seconds to catch queue changes
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _loadMetrics();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }  Future<void> _loadMetrics() async {
    try {
      // Get today's date
      final today = DateTime.now();

      // Load appointments for today - count all appointments including completed for total count
      final todayAppointments = await ApiService.getAppointments(today);
      
      // Load current queue and count only active patients (waiting + in_consultation)
      final queueService = QueueService();
      final activeQueueItems = await queueService.getActiveQueueItems(
        statuses: ['waiting', 'in_consultation']
      );
      
      // Load all users and count doctors
      final allUsers = await ApiService.getUsers();
      final doctors = allUsers.where((user) => user.role.toLowerCase() == 'doctor').toList();

      if (mounted) {
        setState(() {
          _totalAppointmentsToday = todayAppointments.length;
          _currentQueueNumber = activeQueueItems.length; // Only active patients in queue
          _availableDoctors = doctors.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalAppointmentsToday = 0;
          _currentQueueNumber = 0;
          _availableDoctors = 0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildMetricCard(
              'Appointments',
              _isLoading ? '...' : _totalAppointmentsToday.toString(),
              Icons.calendar_today,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              'Current Queue',
              _isLoading ? '...' : _currentQueueNumber.toString(),
              Icons.queue,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              'Available Doctors',
              _isLoading ? '...' : _availableDoctors.toString(),
              Icons.person_search,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: AspectRatio(
        aspectRatio: 1.0, // This makes it square
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: color
                    ),
                  ),
                  Text(
                    'TODAY',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
