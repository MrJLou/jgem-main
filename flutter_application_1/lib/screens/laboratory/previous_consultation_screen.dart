import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: PreviousConsultationScreen(),
  ));
}

class PreviousConsultationScreen extends StatefulWidget {
  @override
  _PreviousConsultationScreenState createState() =>
      _PreviousConsultationScreenState();
}

class _PreviousConsultationScreenState
    extends State<PreviousConsultationScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = false;
  String? _errorMessage;

  void _fetchConsultationRecords(String patientId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 800));

    final mockData = [
      {
        'date': '2024-03-15',
        'doctor': 'Dr. Sarah Johnson',
        'details': 'General Checkup',
        'symptoms': 'Routine health assessment',
        'prescription': 'Vitamin D supplements',
        'followUp': '3 months',
        'status': 'Completed'
      },
      {
        'date': '2024-02-20',
        'doctor': 'Dr. Michael Chen',
        'details': 'Flu Symptoms',
        'symptoms': 'Fever, cough, fatigue',
        'prescription': 'Antiviral medication',
        'followUp': '1 week',
        'status': 'Completed'
      },
      {
        'date': '2024-01-10',
        'doctor': 'Dr. Emily Brown',
        'details': 'Follow-up Visit',
        'symptoms': 'Post-treatment evaluation',
        'prescription': 'Continue current medication',
        'followUp': 'As needed',
        'status': 'Completed'
      },
    ];

    setState(() {
      _consultations = mockData;
      _isLoading = false;
    });
  }

  void _showConsultationDetails(BuildContext context, Map<String, dynamic> consultation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.medical_services, color: Color(0xFF1ABC9C)),
            SizedBox(width: 10),
            Text(
              'Consultation Details',
              style: TextStyle(color: Color(0xFF1ABC9C)),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', consultation['date']),
              _buildDetailRow('Doctor', consultation['doctor']),
              _buildDetailRow('Symptoms', consultation['symptoms']),
              _buildDetailRow('Prescription', consultation['prescription']),
              _buildDetailRow('Follow-up', consultation['followUp']),
              _buildDetailRow('Status', consultation['status']),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('Close', style: TextStyle(color: Color(0xFF1ABC9C))),
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
        title: Text(
          'Previous Consultations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Help'),
                  content: Text('Enter a patient ID to view their consultation history. The records will show all previous medical consultations and their details.'),
                  actions: [
                    TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: Text('Got it'),
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
            padding: EdgeInsets.fromLTRB(24, 20, 24, 40),
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
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                  ),
                    ],
                  ),
                  child: TextField(
                    controller: _patientIdController,
                    style: TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Enter Patient ID',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                      ),
                      prefixIcon: Icon(
                        Icons.person_search,
                        color: Color(0xFF1ABC9C),
                        size: 28,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 20,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
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
                      child: Row(
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
                  style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
            Expanded(
            child: _isLoading
                ? Center(
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
                            SizedBox(height: 16),
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
                                SizedBox(height: 16),
                                Text('Enter a patient ID to view records',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(24),
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
    Key? key,
    required this.date,
    required this.doctor,
    required this.details,
    required this.status,
    required this.onTap,
  }) : super(key: key);

  @override
  _ConsultationCardState createState() => _ConsultationCardState();
}

class _ConsultationCardState extends State<ConsultationCard> {
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
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(16),
          transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _isHovering
                    ? Colors.black.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
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
                      Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFF1ABC9C)),
                      SizedBox(width: 8),
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
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF1ABC9C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.status,
                      style: TextStyle(
                        color: Color(0xFF1ABC9C),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                widget.doctor,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1ABC9C),
                      ),
                    ),
              SizedBox(height: 4),
                    Text(
                      widget.details,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                    ),
              SizedBox(height: 12),
              Row(
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
