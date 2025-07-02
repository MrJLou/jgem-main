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
    
    // Filter doctors who are currently available (within work hours)
    final currentlyAvailable = workingToday.where((doctor) {
      return doctor.isCurrentlyWorking();
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
                          'Available Now: ${currentlyAvailable.length} • Scheduled Today: ${workingToday.length}',
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
            height: 140, // Optimized height for compact cards
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
      elevation: 3,
      margin: const EdgeInsets.only(right: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(6), // Further reduced padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4), // Further reduced padding
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medical_services,
                    size: 18, // Further reduced icon size
                    color: Colors.teal[700],
                  ),
                ),
                if (isCurrentlyWorking)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 8, // Further reduced size
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2), // Reduced spacing
            
            // Doctor title
            Text(
              'Doctor',
              style: TextStyle(
                fontSize: 7, // Further reduced font size
                color: Colors.teal[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            
            // Doctor name - constrained to prevent overflow
            SizedBox(
              height: 24, // Further reduced height for name area
              child: Text(
                doctor.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9, // Further reduced font size
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            
            // Current status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Further reduced padding
              decoration: BoxDecoration(
                color: isCurrentlyWorking ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCurrentlyWorking ? 'Available' : 'Off Duty',
                style: TextStyle(
                  fontSize: 7, // Further reduced font size
                  color: isCurrentlyWorking ? Colors.green[700] : Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            
            // Work schedule information - more compact
            if (doctor.arrivalTime != null && doctor.departureTime != null) ...[
              Text(
                doctor.getFormattedTimeRange(),
                style: TextStyle(
                  fontSize: 7, // Further reduced font size
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Working days summary - very compact
              if (doctor.workingDays != null && doctor.getWorkingDaysList().isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  'Days: ${doctor.getWorkingDaysList().take(2).map((day) => day.substring(0, 2)).join(', ')}${doctor.getWorkingDaysList().length > 2 ? '..' : ''}',
                  style: TextStyle(
                    fontSize: 6, // Further reduced font size
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ] else ...[
              Text(
                'No Schedule',
                style: TextStyle(
                  fontSize: 6, // Further reduced font size
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal[700],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Doctor Schedules',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
                // Content with horizontal layout
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _doctors.isEmpty
                          ? const Center(
                              child: Text(
                                'No doctors registered yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )
                          : Row(
                              children: [
                                // Left side - Overview panel
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      border: Border(
                                        right: BorderSide(color: Colors.grey[200]!),
                                      ),
                                    ),
                                    child: _buildVerticalOverviewPanel(),
                                  ),
                                ),
                                // Right side - Doctors list
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'All Doctors',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal[700],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: _doctors.length,
                                            itemBuilder: (context, index) {
                                              return _buildCompactDoctorCard(_doctors[index]);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalOverviewPanel() {
    // Get today's day name for filtering working doctors
    final today = DateTime.now();
    final dayName = _getDayName(today.weekday);
    
    // Calculate summary statistics
    final workingToday = _doctors.where((doctor) {
      return doctor.worksOnDay(dayName) && 
             doctor.arrivalTime != null && 
             doctor.departureTime != null;
    }).toList();
    
    final currentlyAvailable = workingToday.where((doctor) => doctor.isCurrentlyWorking()).toList();
    final withSchedule = _doctors.where((doctor) => doctor.arrivalTime != null && doctor.departureTime != null).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[700]!, Colors.teal[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Doctors Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Overview cards
          _buildOverviewMetric(
            'Total Registered',
            _doctors.length.toString(),
            Icons.person_add,
            Colors.white,
          ),
          const SizedBox(height: 16),
          
          _buildOverviewMetric(
            'Working Today',
            workingToday.length.toString(),
            Icons.today,
            Colors.white,
          ),
          const SizedBox(height: 16),
          
          _buildOverviewMetric(
            'Available Now',
            currentlyAvailable.length.toString(),
            Icons.check_circle,
            Colors.green[200]!,
          ),
          const SizedBox(height: 16),
          
          _buildOverviewMetric(
            'With Schedule',
            withSchedule.length.toString(),
            Icons.schedule,
            Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 32),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactDoctorCard(User doctor) {
    final workingDays = doctor.getWorkingDaysList();
    final hasSchedule = doctor.arrivalTime != null && doctor.departureTime != null;
    final isCurrentlyWorking = hasSchedule && doctor.isCurrentlyWorking();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor name and status
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal[50],
                  child: Icon(
                    Icons.medical_services,
                    size: 28,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (doctor.email != null)
                        Text(
                          doctor.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCurrentlyWorking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green[600], size: 8),
                        const SizedBox(width: 4),
                        Text(
                          'Available',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Working schedule
            if (hasSchedule) ...[
              Container(
                width: double.infinity,
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
                        Icon(Icons.access_time, color: Colors.teal[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Hours: ${doctor.getFormattedTimeRange()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.teal[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: ${doctor.getDurationInHours().toStringAsFixed(1)} hours',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Working days
            if (workingDays.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Working Days:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
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
                      border: isToday ? Border.all(color: Colors.teal[800]!) : null,
                    ),
                    child: Text(
                      day.substring(0, 3).toUpperCase(),
                      style: TextStyle(
                        color: isToday ? Colors.white : Colors.grey[700],
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[600], size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'No working days set',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
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
