import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/patient.dart';
import 'package:intl/intl.dart';

class PreviousDiagnosesTreatmentsScreen extends StatefulWidget {
  const PreviousDiagnosesTreatmentsScreen({super.key});

  @override
  PreviousDiagnosesTreatmentsScreenState createState() =>
      PreviousDiagnosesTreatmentsScreenState();
}

class PreviousDiagnosesTreatmentsScreenState
    extends State<PreviousDiagnosesTreatmentsScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = false;
  String? _errorMessage;
  Patient? _foundPatient;

  void _fetchRecords(String patientId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _records = [];
      _foundPatient = null;
    });

    try {
      // First, verify patient exists
      final patient = await ApiService.getPatientById(patientId);
      _foundPatient = patient;
      
      // Get patient's medical records
      final medicalRecords = await ApiService.getPatientMedicalRecords(patientId);
      
      // Filter records that have diagnosis and/or treatment
      final diagnosisRecords = medicalRecords
          .where((record) => 
              (record.diagnosis != null && record.diagnosis!.isNotEmpty) ||
              (record.treatment != null && record.treatment!.isNotEmpty))
          .toList();
      
      // Sort by date (most recent first)
      diagnosisRecords.sort((a, b) => b.recordDate.compareTo(a.recordDate));
      
      // Get all users to map doctor IDs to names
      final allUsers = await ApiService.getUsers();
      final doctors = {for (var user in allUsers.where((u) => u.role == 'doctor')) user.id: user};
      
      // Transform medical records into diagnosis/treatment records
      final transformedRecords = <Map<String, dynamic>>[];
      
      for (final record in diagnosisRecords) {
        final doctor = doctors[record.doctorId];
        final doctorName = doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor';
        
        // Determine severity based on record type and diagnosis
        String severity = 'Mild';
        if (record.diagnosis != null) {
          final diagnosisLower = record.diagnosis!.toLowerCase();
          if (diagnosisLower.contains('severe') || diagnosisLower.contains('critical') || 
              diagnosisLower.contains('emergency') || diagnosisLower.contains('acute')) {
            severity = 'Severe';
          } else if (diagnosisLower.contains('moderate') || diagnosisLower.contains('chronic')) {
            severity = 'Moderate';
          }
        }
        
        // Determine status
        String status = 'Ongoing';
        if (record.notes != null) {
          final notesLower = record.notes!.toLowerCase();
          if (notesLower.contains('resolved') || notesLower.contains('completed') ||
              notesLower.contains('healed') || notesLower.contains('cured')) {
            status = 'Resolved';
          } else if (notesLower.contains('improving') || notesLower.contains('better')) {
            status = 'Improving';
          }
        }
        
        transformedRecords.add({
          'id': record.id,
          'date': DateFormat('yyyy-MM-dd').format(record.recordDate),
          'doctor': doctorName,
          'diagnosis': record.diagnosis ?? 'No diagnosis recorded',
          'severity': severity,
          'treatment': record.treatment ?? 'No treatment recorded',
          'duration': _calculateTreatmentDuration(record.recordDate),
          'followUp': _getFollowUpFromNotes(record.notes),
          'status': status,
          'recordType': record.recordType,
          'prescription': record.prescription ?? 'No prescription',
          'notes': record.notes ?? 'No additional notes',
        });
      }

      if (!mounted) return;
      setState(() {
        _records = transformedRecords;
        _isLoading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _records = [];
        _foundPatient = null;
      });
    }
  }

  String _calculateTreatmentDuration(DateTime recordDate) {
    final now = DateTime.now();
    final difference = now.difference(recordDate);
    
    if (difference.inDays < 7) {
      return '${difference.inDays} day(s)';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).round()} week(s)';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).round()} month(s)';
    } else {
      return '${(difference.inDays / 365).round()} year(s)';
    }
  }

  String _getFollowUpFromNotes(String? notes) {
    if (notes == null || notes.isEmpty) return 'As needed';
    
    final notesLower = notes.toLowerCase();
    if (notesLower.contains('weekly')) return 'Weekly';
    if (notesLower.contains('monthly')) return 'Monthly';
    if (notesLower.contains('daily')) return 'Daily';
    if (notesLower.contains('follow') && notesLower.contains('up')) return 'Follow-up required';
    if (notesLower.contains('completed') || notesLower.contains('resolved')) return 'Completed';
    
    return 'As needed';
  }

  void _showRecordDetails(BuildContext context, Map<String, dynamic> record) {
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
              'Diagnosis & Treatment Details',
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
              _buildDetailRow('Date', record['date']),
              _buildDetailRow('Doctor', record['doctor']),
              _buildDetailRow('Diagnosis', record['diagnosis']),
              _buildDetailRow('Severity', record['severity']),
              _buildDetailRow('Treatment', record['treatment']),
              _buildDetailRow('Duration', record['duration']),
              _buildDetailRow('Follow-up', record['followUp']),
              _buildDetailRow('Status', record['status']),
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
          'Previous Diagnoses & Treatments',
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
                  content: const Text('Enter a patient ID to view their diagnosis and treatment history. The records will show all previous medical conditions and their treatments.'),
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
                          _fetchRecords(patientId);
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
                      )                    : _records.isEmpty
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
                          )
                        : Column(
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
                                        '${_records.length} record(s) found',
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
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    return DiagnosisTreatmentCard(
                                      date: record['date']!,
                                      doctor: record['doctor']!,
                                      diagnosis: record['diagnosis']!,
                                      treatment: record['treatment']!,
                                      severity: record['severity']!,
                                      status: record['status']!,
                                      onTap: () => _showRecordDetails(context, record),
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

class DiagnosisTreatmentCard extends StatefulWidget {
  final String date;
  final String doctor;
  final String diagnosis;
  final String treatment;
  final String severity;
  final String status;
  final VoidCallback onTap;

  const DiagnosisTreatmentCard({
    super.key,
    required this.date,
    required this.doctor,
    required this.diagnosis,
    required this.treatment,
    required this.severity,
    required this.status,
    required this.onTap,
  });

  @override
  DiagnosisTreatmentCardState createState() => DiagnosisTreatmentCardState();
}

class DiagnosisTreatmentCardState extends State<DiagnosisTreatmentCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  Color _getSeverityColor() {
    switch (widget.severity.toLowerCase()) {
      case 'mild':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _getSeverityColor().withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.severity,
                          style: TextStyle(
                            color: _getSeverityColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ABC9C).withAlpha(26),
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
                'Diagnosis: ${widget.diagnosis}',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.treatment,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
