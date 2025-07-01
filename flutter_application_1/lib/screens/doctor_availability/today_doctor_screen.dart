import 'package:flutter/material.dart';
import '../../models/doctor_availability.dart';
import '../../services/doctor_availability_service.dart';
import '../../widgets/dashboard/today_doctor_widget.dart';

/// Screen for viewing and managing doctor availability
/// This provides the main interface for the "Today Doctor" feature
class TodayDoctorScreen extends StatefulWidget {
  const TodayDoctorScreen({super.key});

  @override
  State<TodayDoctorScreen> createState() => _TodayDoctorScreenState();
}

class _TodayDoctorScreenState extends State<TodayDoctorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize default availability for all doctors
    _initializeDefaultAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeDefaultAvailability() async {
    try {
      await DoctorAvailabilityService.initializeDefaultAvailabilityForAllDoctors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing doctor availability: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Availability'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.today),
              text: 'Today\'s Doctors',
            ),
            Tab(
              icon: Icon(Icons.calendar_view_week),
              text: 'Weekly Schedule',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showDatePicker();
            },
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildWeeklyTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showScheduleManagementDialog();
        },
        backgroundColor: Colors.teal[700],
        tooltip: 'Manage Schedules',
        child: const Icon(Icons.edit_calendar, color: Colors.white),
      ),
    );
  }

  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Date selector card
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.teal[600]),
              title: Text(
                'Selected Date',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.teal[700],
                ),
              ),
              subtitle: Text(
                '${_getDayName(_selectedDate)}, ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: const TextStyle(fontSize: 16),
              ),
              trailing: const Icon(Icons.edit),
              onTap: _showDatePicker,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Today's doctors widget
          TodayDoctorWidget(
            selectedDate: _selectedDate,
            showDateSelector: false,
            isCompact: false,
            onDoctorTapped: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Doctor scheduling integration coming soon!'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Doctor Availability Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.teal[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View doctor schedules for the entire week',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Week overview cards
          ...DayOfWeek.values.map((day) => _buildDayCard(day)),
        ],
      ),
    );
  }

  Widget _buildDayCard(DayOfWeek dayOfWeek) {
    final date = _getDateForDayOfWeek(dayOfWeek);
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _isToday(date) ? Colors.teal[100] : Colors.grey[100],
          child: Text(
            dayOfWeek.shortName,
            style: TextStyle(
              color: _isToday(date) ? Colors.teal[700] : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          dayOfWeek.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: _isToday(date) ? Colors.teal[700] : null,
          ),
        ),
        subtitle: Text(
          '${date.day}/${date.month}/${date.year}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: TodayDoctorWidget(
              selectedDate: date,
              showDateSelector: false,
              isCompact: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showScheduleManagementDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Schedule Management'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule management features:'),
              SizedBox(height: 16),
              Text('• Individual doctor schedules'),
              Text('• Time slot management'),
              Text('• Holiday/vacation planning'),
              Text('• Specialty assignments'),
              Text('• Room/location assignments'),
              SizedBox(height: 16),
              Text(
                'These features will be added in future updates.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeDefaultAvailability();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Default schedules refreshed for all doctors'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh Defaults'),
            ),
          ],
        );
      },
    );
  }

  String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday', 
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  DateTime _getDateForDayOfWeek(DayOfWeek dayOfWeek) {
    final today = _selectedDate;
    final currentWeekday = today.weekday;
    final targetWeekday = dayOfWeek.dateTimeWeekday;
    final daysToAdd = targetWeekday - currentWeekday;
    
    return today.add(Duration(days: daysToAdd));
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
}
