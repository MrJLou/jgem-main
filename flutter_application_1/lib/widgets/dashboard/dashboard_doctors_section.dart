// Doctors section widget for dashboard
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../services/doctor_schedule_service.dart';
import '../../models/doctor_schedule.dart';

class DashboardDoctorsSection extends StatefulWidget {
  const DashboardDoctorsSection({super.key});

  @override
  State<DashboardDoctorsSection> createState() => _DashboardDoctorsSectionState();
}

class _DashboardDoctorsSectionState extends State<DashboardDoctorsSection> {
  List<User> _doctors = [];
  Map<String, DoctorSchedule> _doctorSchedules = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorsAndSchedules();
  }

  Future<void> _loadDoctorsAndSchedules() async {
    try {
      final allUsers = await ApiService.getUsers();
      final doctors = allUsers.where((user) => user.role.toLowerCase() == 'doctor').toList();
      
      // Load schedules for all doctors
      final schedules = <String, DoctorSchedule>{};
      for (final doctor in doctors) {
        final schedule = await DoctorScheduleService.getDoctorSchedule(doctor.id);
        if (schedule != null) {
          schedules[doctor.id] = schedule;
        }
      }
      
      if (mounted) {
        setState(() {
          _doctors = doctors;
          _doctorSchedules = schedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctors = [];
          _doctorSchedules = {};
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get today's day name for filtering working doctors
    final today = DateTime.now();
    final dayName = _getDayName(today.weekday);
    
    // Filter doctors working today
    final workingToday = _doctors.where((doctor) {
      final schedule = _doctorSchedules[doctor.id];
      return schedule != null && schedule.worksOnDay(dayName);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Doctors",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700]),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/doctor-schedule');
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('View Schedule'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Working today summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_services, color: Colors.teal[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${workingToday.length} doctors working today',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[700],
                          fontSize: 14,
                        ),
                      ),
                      if (workingToday.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Available: ${workingToday.where((doctor) {
                            final schedule = _doctorSchedules[doctor.id];
                            return schedule?.isCurrentlyWorking() ?? false;
                          }).length} • On Schedule: ${workingToday.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.access_time, color: Colors.teal[600], size: 16),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Today's working doctors list
          Text(
            "Doctors Working Today",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.teal[600]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : workingToday.isEmpty
                    ? Center(
                        child: Text(
                          'No doctors scheduled for today',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: workingToday.length,
                        itemBuilder: (context, index) {
                          return _buildDoctorCard(workingToday[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }  Widget _buildDoctorCard(User doctor) {
    final schedule = _doctorSchedules[doctor.id];
    final isCurrentlyWorking = schedule?.isCurrentlyWorking() ?? false;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.teal[50],
                  child: Icon(
                    Icons.medical_services,
                    size: 26,
                    color: Colors.teal[700],
                  ),
                ),
                if (isCurrentlyWorking)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Doctor title and name
            Text(
              'Doctor',
              style: TextStyle(
                fontSize: 11,
                color: Colors.teal[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              doctor.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            
            // Work schedule information
            if (schedule != null) ...[
              // Work hours container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal[200]!, width: 0.5),
                ),
                child: Column(
                  children: [
                    Text(
                      'Work Hours',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.teal[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schedule.getFormattedTimeRange(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.teal[800],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              
              // Current status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCurrentlyWorking ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isCurrentlyWorking ? 'Available Now' : 'Not Available',
                  style: TextStyle(
                    fontSize: 9,
                    color: isCurrentlyWorking ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              // No schedule container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!, width: 0.5),
                ),
                child: Text(
                  'Schedule not set',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }
}
