import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import 'package:intl/intl.dart';

class PreviousConsultationScreen extends StatefulWidget {
  const PreviousConsultationScreen({super.key});

  @override
  PreviousConsultationScreenState createState() =>
      PreviousConsultationScreenState();
}

class PreviousConsultationScreenState
    extends State<PreviousConsultationScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = false;
  String? _errorMessage;
  Patient? _foundPatient;

  void _fetchConsultationRecords(String patientId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _consultations = [];
      _foundPatient = null;
    });

    try {
      // First, verify patient exists
      final patient = await ApiService.getPatientById(patientId);
      _foundPatient = patient;
      
      // Get patient's appointments 
      final appointments = await ApiService.getPatientAppointments(patientId);
      
      // Filter completed appointments and get additional data
      final completedAppointments = appointments
          .where((appt) => appt.status == 'Completed' || appt.status == 'Served')
          .toList();
      
      // Sort by date (most recent first)
      completedAppointments.sort((a, b) => b.date.compareTo(a.date));
      
      // Get all users to map doctor IDs to names
      final allUsers = await ApiService.getUsers();
      final doctors = {for (var user in allUsers.where((u) => u.role == 'doctor')) user.id: user};
      
      // Transform appointments into consultation records
      final consultationRecords = <Map<String, dynamic>>[];
      
      for (final appointment in completedAppointments) {
        final doctor = doctors[appointment.doctorId];
        final doctorName = doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor';
        
        // Create consultation record
        consultationRecords.add({
          'id': appointment.id,
          'date': DateFormat('yyyy-MM-dd').format(appointment.date),
          'doctor': doctorName,
          'details': appointment.consultationType,
          'symptoms': appointment.consultationType,
          'prescription': appointment.notes ?? 'No prescription noted',
          'followUp': _getFollowUpText(appointment),
          'status': appointment.status,
          'services': appointment.selectedServices.map((s) => s['name'] ?? 'Unknown Service').join(', '),
          'totalPrice': appointment.totalPrice,
        });
      }

      if (!mounted) return;
      setState(() {
        _consultations = consultationRecords;
        _isLoading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _consultations = [];
        _foundPatient = null;
      });
    }
  }

  String _getFollowUpText(Appointment appointment) {
    if (appointment.notes != null && appointment.notes!.isNotEmpty) {
      return 'See notes';
    }
    return 'As needed';
  }
  void _showConsultationDetails(BuildContext context, Map<String, dynamic> consultation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Color(0xFF1ABC9C)),
            SizedBox(width: 10),
            Text(
              'Consultation Details',
              style: TextStyle(color: Color(0xFF1ABC9C)),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', consultation['date']),
              _buildDetailRow('Doctor', consultation['doctor']),
              _buildDetailRow('Type', consultation['details']),
              if (consultation['services'] != null && consultation['services'].isNotEmpty)
                _buildDetailRow('Services', consultation['services']),
              _buildDetailRow('Prescription', consultation['prescription']),
              _buildDetailRow('Follow-up', consultation['followUp']),
              _buildDetailRow('Status', consultation['status']),
              if (consultation['totalPrice'] != null)
                _buildDetailRow('Total Cost', 'PHP ${consultation['totalPrice'].toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Close', style: TextStyle(color: Color(0xFF1ABC9C))),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Previous Consultations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Help'),
                  content: const Text('Enter a patient ID to view their consultation history. The records will show all previous medical consultations and their details.'),
                  actions: [
                    TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.teal[700],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                  ),
                    ],
                  ),
                  child: TextField(
                    controller: _patientIdController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Enter Patient ID',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_search,
                        color: Color(0xFF1ABC9C),
                        size: 28,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
            Center(
              child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    final patientId = _patientIdController.text.trim();
                    if (patientId.isNotEmpty) {
                      _fetchConsultationRecords(patientId);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                  ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            color: Color(0xFF1ABC9C),
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Search Records',
                            style: TextStyle(
                              color: Color(0xFF1ABC9C),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
              ],
            ),
          ),
            Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
                        ),
                        SizedBox(height: 16),
                        Text('Fetching records...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(_errorMessage!,
                                style: TextStyle(color: Colors.red[300])),
                          ],
                        ),
                      )
                    : _consultations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('Enter a patient ID to view records',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )                        : Column(
                            children: [
                              if (_foundPatient != null)
                                Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.teal[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: Colors.teal[700], size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _foundPatient!.fullName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal[800],
                                              ),
                                            ),
                                            Text(
                                              'Patient ID: ${_foundPatient!.id}',
                                              style: TextStyle(
                                                color: Colors.teal[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${_consultations.length} record(s) found',
                                        style: TextStyle(
                                          color: Colors.teal[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: _consultations.length,
                                  itemBuilder: (context, index) {
                                    final consultation = _consultations[index];
                                    return ConsultationCard(
                                      date: consultation['date']!,
                                      doctor: consultation['doctor']!,
                                      details: consultation['details']!,
                                      status: consultation['status']!,
                                      onTap: () =>
                                          _showConsultationDetails(context, consultation),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
            ),
          ],
      ),
    );
  }
}

// Individual consultation card with hover + click effects
class ConsultationCard extends StatefulWidget {
  final String date;
  final String doctor;
  final String details;
  final String status;
  final VoidCallback onTap;

  const ConsultationCard({
    super.key,
    required this.date,
    required this.doctor,
    required this.details,
    required this.status,
    required this.onTap,
  });

  @override
  ConsultationCardState createState() => ConsultationCardState();
}

class ConsultationCardState extends State<ConsultationCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _isHovering
                    ? Colors.black.withAlpha(26)
                    : Colors.black.withAlpha(13),
                blurRadius: _isHovering ? 10 : 5,
                offset: Offset(0, _isHovering ? 5 : 2),
              ),
            ],
          ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFF1ABC9C)),
                      const SizedBox(width: 8),
                    Text(
                        widget.date,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.status,
                      style: const TextStyle(
                        color: Color(0xFF1ABC9C),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.doctor,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1ABC9C),
                      ),
                    ),
              const SizedBox(height: 4),
                    Text(
                      widget.details,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                    ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: Color(0xFF1ABC9C),
                      fontWeight: FontWeight.w500,
                ),
              ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF1ABC9C),
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
