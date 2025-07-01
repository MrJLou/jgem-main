import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/doctor_availability_service.dart';

/// Widget that displays today's available doctors
/// This is the main component for the "Today Doctor" feature
class TodayDoctorWidget extends StatefulWidget {
  final DateTime? selectedDate;
  final bool showDateSelector;
  final VoidCallback? onDoctorTapped;
  final bool isCompact; // For dashboard usage

  const TodayDoctorWidget({
    super.key,
    this.selectedDate,
    this.showDateSelector = false,
    this.onDoctorTapped,
    this.isCompact = false,
  });

  @override
  State<TodayDoctorWidget> createState() => _TodayDoctorWidgetState();
}

class _TodayDoctorWidgetState extends State<TodayDoctorWidget> {
  DateTime _selectedDate = DateTime.now();
  TodayDoctorSummary? _summary;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _loadDoctorSummary();
  }

  @override
  void didUpdateWidget(TodayDoctorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate ?? DateTime.now();
      _loadDoctorSummary();
    }
  }

  Future<void> _loadDoctorSummary() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await DoctorAvailabilityService.getDoctorSummaryForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _summary = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading doctor availability: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
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
      _loadDoctorSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactView();
    }
    
    return _buildFullView();
  }

  Widget _buildCompactView() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  color: Colors.teal[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Doctors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
                const Spacer(),
                if (widget.showDateSelector)
                  TextButton(
                    onPressed: _selectDate,
                    child: Text(
                      DateFormat.MMMd().format(_selectedDate),
                      style: TextStyle(color: Colors.teal[600]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_summary == null)
              const Text('No data available')
            else
              _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFullView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.medical_services,
                color: Colors.teal[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Doctor Availability',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              const Spacer(),
              if (widget.showDateSelector)
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat.yMMMd().format(_selectedDate)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[600],
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        
        // Content
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _summary == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No data available'),
                      ),
                    )
                  : _buildDoctorList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (_summary == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _summary!.getSummaryText(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (_summary!.hasAvailableDoctors) ...[
          Text(
            '${_summary!.availableCount} doctors available today',
            style: TextStyle(
              color: Colors.teal[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          Text(
            'No doctors available',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoctorList() {
    if (_summary == null) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildStatCard(
                  'Available',
                  _summary!.availableCount.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Total',
                  _summary!.totalDoctors.toString(),
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Day',
                  _summary!.dayDisplayName,
                  Colors.teal,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Available doctors
          if (_summary!.hasAvailableDoctors) ...[
            Text(
              'Available Doctors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
            ),
            const SizedBox(height: 12),
            ...(_summary!.availableDoctors.map((doctorInfo) => 
              _buildDoctorCard(doctorInfo, true))),
          ],
          
          // Unavailable doctors
          if (_summary!.unavailableDoctors.isNotEmpty) ...[
            if (_summary!.hasAvailableDoctors) const SizedBox(height: 24),
            Text(
              'Unavailable Doctors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ...(_summary!.unavailableDoctors.map((doctorInfo) => 
              _buildDoctorCard(doctorInfo, false))),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color[700],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(TodayDoctorInfo doctorInfo, bool isAvailable) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAvailable ? Colors.green[100] : Colors.grey[100],
          child: Icon(
            Icons.person,
            color: isAvailable ? Colors.green[700] : Colors.grey[600],
          ),
        ),
        title: Text(
          doctorInfo.doctor.fullName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isAvailable ? Colors.black87 : Colors.grey[600],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Role: Doctor',
              style: const TextStyle(fontSize: 12),
            ),
            if (isAvailable) ...[
              Text(
                'Hours: ${doctorInfo.workingHoursDisplay}',
                style: const TextStyle(fontSize: 12),
              ),
            ] else ...[
              Text(
                doctorInfo.statusDisplay,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: isAvailable
            ? Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 20,
              )
            : Icon(
                Icons.cancel,
                color: Colors.grey[400],
                size: 20,
              ),
        onTap: isAvailable ? widget.onDoctorTapped : null,
      ),
    );
  }
}
