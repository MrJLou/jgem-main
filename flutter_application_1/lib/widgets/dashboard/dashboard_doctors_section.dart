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
      final doctors = allUsers.where((user) => user.role.toLowerCase() == 'doctor').toList();
      
      if (mounted) {
        setState(() {
          _doctors = doctors;
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
    // Get today's day name for filtering working doctors
    final today = DateTime.now();
    final dayName = _getDayName(today.weekday);
    
    // Filter doctors working today based on their User model working days
    final workingToday = _doctors.where((doctor) {
      return doctor.worksOnDay(dayName) && 
             doctor.arrivalTime != null && 
             doctor.departureTime != null;
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
                  _showDoctorsInfoDialog(context);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('View Info'),
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
                          'Available: ${workingToday.where((doctor) => doctor.isCurrentlyWorking()).length} • On Schedule: ${workingToday.length}',
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
    final isCurrentlyWorking = doctor.isCurrentlyWorking();
    
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
            if (doctor.arrivalTime != null && doctor.departureTime != null) ...[
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
                      doctor.getFormattedTimeRange(),
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
              const SizedBox(height: 4),
              
              // Working days
              if (doctor.workingDays != null && doctor.getWorkingDaysList().isNotEmpty) ...[
                Text(
                  'Working Days',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.getWorkingDaysList().take(3).join(', ') + 
                  (doctor.getWorkingDaysList().length > 3 ? '...' : ''),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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

  void _showDoctorsInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal[700],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Doctor Schedules',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _doctors.isEmpty
                          ? const Center(
                              child: Text(
                                'No doctors registered yet',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _doctors.length,
                              itemBuilder: (context, index) {
                                return _buildDoctorInfoCard(_doctors[index]);
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoctorInfoCard(User doctor) {
    final workingDays = doctor.getWorkingDaysList();
    final hasSchedule = doctor.arrivalTime != null && doctor.departureTime != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor name and status
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.teal[50],
                  child: Icon(
                    Icons.medical_services,
                    size: 30,
                    color: Colors.teal[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.fullName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (doctor.email != null)
                        Text(
                          doctor.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasSchedule && doctor.isCurrentlyWorking())
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green[600], size: 8),
                        const SizedBox(width: 4),
                        Text(
                          'Available Now',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Working schedule
            if (hasSchedule) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.teal[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Work Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hours: ${doctor.getFormattedTimeRange()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${doctor.getDurationInHours().toStringAsFixed(1)} hours',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Working days
            if (workingDays.isNotEmpty) ...[
              Text(
                'Working Days:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: workingDays.map((day) {
                  final isToday = day.toLowerCase() == _getDayName(DateTime.now().weekday);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.teal[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        color: isToday ? Colors.white : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'No working days set',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
