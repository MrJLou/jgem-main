import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/patient.dart';
import 'package:intl/intl.dart';

class PreviousLaboratoryResultsScreen extends StatefulWidget {
  const PreviousLaboratoryResultsScreen({super.key});

  @override
  PreviousLaboratoryResultsScreenState createState() =>
      PreviousLaboratoryResultsScreenState();
}

class PreviousLaboratoryResultsScreenState
    extends State<PreviousLaboratoryResultsScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  Patient? _foundPatient;

  void _fetchResults(String patientId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
      _foundPatient = null;
    });

    try {
      // First, verify patient exists
      final patient = await ApiService.getPatientById(patientId);
      _foundPatient = patient;
      
      // Get patient's medical records
      final medicalRecords = await ApiService.getPatientMedicalRecords(patientId);
      
      // Filter records that have lab results
      final labRecords = medicalRecords
          .where((record) => 
              record.labResults != null && record.labResults!.isNotEmpty)
          .toList();
      
      // Sort by date (most recent first)
      labRecords.sort((a, b) => b.recordDate.compareTo(a.recordDate));
      
      // Get all users to map doctor IDs to names
      final allUsers = await ApiService.getUsers();
      final doctors = {for (var user in allUsers.where((u) => u.role == 'doctor')) user.id: user};
      
      // Transform medical records into lab result records
      final transformedResults = <Map<String, dynamic>>[];
      
      for (final record in labRecords) {
        final doctor = doctors[record.doctorId];
        final doctorName = doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor';
        
        // Parse lab results - try to handle JSON or simple text
        Map<String, String> parsedResults = {};
        try {
          // Try to parse as key-value pairs from text
          final labText = record.labResults!;
          final lines = labText.split('\n');
          for (final line in lines) {
            if (line.contains(':')) {
              final parts = line.split(':');
              if (parts.length >= 2) {
                parsedResults[parts[0].trim()] = parts.sublist(1).join(':').trim();
              }
            }
          }
          
          // If no key-value pairs found, create a general result
          if (parsedResults.isEmpty) {
            parsedResults['Result'] = labText;
          }
        } catch (e) {
          parsedResults['Result'] = record.labResults!;
        }
        
        // Determine test category based on record type or lab results content
        String category = _determineTestCategory(record.recordType, record.labResults!);
        
        // Determine status based on results or notes
        String status = _determineResultStatus(record.labResults!, record.notes);
        
        transformedResults.add({
          'id': record.id,
          'date': DateFormat('yyyy-MM-dd').format(record.recordDate),
          'test': record.recordType.isNotEmpty ? record.recordType : 'Laboratory Test',
          'doctor': doctorName,
          'result': parsedResults,
          'status': status,
          'notes': record.notes ?? 'No additional notes',
          'category': category,
          'diagnosis': record.diagnosis ?? '',
        });
      }

      if (!mounted) return;
      setState(() {
        _results = transformedResults;
        _isLoading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _results = [];
        _foundPatient = null;
      });
    }
  }

  String _determineTestCategory(String recordType, String labResults) {
    final combined = '$recordType $labResults'.toLowerCase();
    
    if (combined.contains('blood') || combined.contains('cbc') || combined.contains('hemoglobin') ||
        combined.contains('wbc') || combined.contains('rbc') || combined.contains('platelet')) {
      return 'Hematology';
    } else if (combined.contains('glucose') || combined.contains('cholesterol') || 
               combined.contains('lipid') || combined.contains('chemistry') ||
               combined.contains('liver') || combined.contains('kidney')) {
      return 'Chemistry';
    } else if (combined.contains('urine') || combined.contains('urinalysis')) {
      return 'Urinalysis';
    } else if (combined.contains('culture') || combined.contains('bacteria') ||
               combined.contains('sensitivity') || combined.contains('microbiology')) {
      return 'Microbiology';
    } else if (combined.contains('x-ray') || combined.contains('imaging') ||
               combined.contains('radiology') || combined.contains('scan')) {
      return 'Radiology';
    } else {
      return 'General';
    }
  }

  String _determineResultStatus(String labResults, String? notes) {
    final combined = '$labResults ${notes ?? ''}'.toLowerCase();
    
    if (combined.contains('normal') || combined.contains('negative') ||
        combined.contains('within range') || combined.contains('clear')) {
      return 'Normal';
    } else if (combined.contains('abnormal') || combined.contains('positive') ||
               combined.contains('elevated') || combined.contains('high') ||
               combined.contains('low') || combined.contains('critical')) {
      return 'Abnormal';
    } else if (combined.contains('borderline') || combined.contains('slightly')) {
      return 'Borderline';
    } else {
      return 'Pending Review';
    }
  }

  void _showResultDetails(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.science, color: Color(0xFF1ABC9C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['test'],
                    style: const TextStyle(color: Color(0xFF1ABC9C)),
                  ),
                  Text(
                    result['category'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Date', result['date']),
                _buildDetailRow('Doctor', result['doctor']),
                _buildDetailRow('Status', result['status']),
                _buildDetailRow('Notes', result['notes']),
                const SizedBox(height: 16),
                const Text(
                  'Test Results',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1ABC9C),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...(result['result'] as Map<String, dynamic>).entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          'Previous Laboratory Results',
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
                  content: const Text('Enter a patient ID to view their laboratory test results. The records will show all previous tests and their outcomes.'),
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
                          _fetchResults(patientId);
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
                        Text('Fetching results...'),
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
                      )                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.science,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('Enter a patient ID to view results',
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
                                        '${_results.length} result(s) found',
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
                                  itemCount: _results.length,
                                  itemBuilder: (context, index) {
                                    final result = _results[index];
                                    return LabResultCard(
                                      date: result['date']!,
                                      test: result['test']!,
                                      doctor: result['doctor']!,
                                      status: result['status']!,
                                      category: result['category']!,
                                      onTap: () => _showResultDetails(context, result),
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

class LabResultCard extends StatefulWidget {
  final String date;
  final String test;
  final String doctor;
  final String status;
  final String category;
  final VoidCallback onTap;

  const LabResultCard({
    super.key,
    required this.date,
    required this.test,
    required this.doctor,
    required this.status,
    required this.category,
    required this.onTap,
  });

  @override
  LabResultCardState createState() => LabResultCardState();
}

class LabResultCardState extends State<LabResultCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  Color _getStatusColor() {
    switch (widget.status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'borderline':
        return Colors.orange;
      case 'abnormal':
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
                          color: const Color(0xFF1ABC9C).withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.category,
                          style: const TextStyle(
                            color: Color(0xFF1ABC9C),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.status,
                          style: TextStyle(
                            color: _getStatusColor(),
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
                widget.test,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1ABC9C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ordered by ${widget.doctor}',
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
