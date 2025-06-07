import 'package:flutter/material.dart';

class PreviousLaboratoryResultsScreen extends StatefulWidget {
  @override
  _PreviousLaboratoryResultsScreenState createState() =>
      _PreviousLaboratoryResultsScreenState();
}

class _PreviousLaboratoryResultsScreenState
    extends State<PreviousLaboratoryResultsScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  void _fetchResults(String patientId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(Duration(milliseconds: 800));

    final mockData = [
      {
        'date': '2024-03-15',
        'test': 'Complete Blood Count (CBC)',
        'doctor': 'Dr. Sarah Johnson',
        'result': {
          'WBC': '7.5 x10^9/L',
          'RBC': '4.8 x10^12/L',
          'Hemoglobin': '14.2 g/dL',
          'Platelets': '250 x10^9/L'
        },
        'status': 'Normal',
        'notes': 'All values within normal range',
        'category': 'Hematology'
      },
      {
        'date': '2024-02-20',
        'test': 'Lipid Panel',
        'doctor': 'Dr. Michael Chen',
        'result': {
          'Total Cholesterol': '190 mg/dL',
          'HDL': '45 mg/dL',
          'LDL': '120 mg/dL',
          'Triglycerides': '150 mg/dL'
        },
        'status': 'Borderline',
        'notes': 'LDL slightly elevated, recommend dietary changes',
        'category': 'Chemistry'
      },
      {
        'date': '2024-01-10',
        'test': 'Urinalysis',
        'doctor': 'Dr. Emily Brown',
        'result': {
          'Color': 'Yellow',
          'Clarity': 'Clear',
          'pH': '6.0',
          'Protein': 'Negative',
          'Glucose': 'Negative'
        },
        'status': 'Normal',
        'notes': 'No abnormalities detected',
        'category': 'Urinalysis'
      },
    ];

    setState(() {
      _results = mockData;
      _isLoading = false;
    });
  }

  void _showResultDetails(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.science, color: Color(0xFF1ABC9C)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['test'],
                    style: TextStyle(color: Color(0xFF1ABC9C)),
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
        content: Container(
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
                SizedBox(height: 16),
                Text(
                  'Test Results',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1ABC9C),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
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
          'Previous Laboratory Results',
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
                  content: Text('Enter a patient ID to view their laboratory test results. The records will show all previous tests and their outcomes.'),
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
                          _fetchResults(patientId);
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
                            SizedBox(height: 16),
                            Text(_errorMessage!,
                                style: TextStyle(color: Colors.red[300])),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.science,
                                    size: 48, color: Colors.grey[400]),
                                SizedBox(height: 16),
                                Text('Enter a patient ID to view results',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(24),
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
    Key? key,
    required this.date,
    required this.test,
    required this.doctor,
    required this.status,
    required this.category,
    required this.onTap,
  }) : super(key: key);

  @override
  _LabResultCardState createState() => _LabResultCardState();
}

class _LabResultCardState extends State<LabResultCard> {
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
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFF1ABC9C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.category,
                          style: TextStyle(
                            color: Color(0xFF1ABC9C),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
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
              SizedBox(height: 12),
              Text(
                widget.test,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1ABC9C),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ordered by ${widget.doctor}',
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
