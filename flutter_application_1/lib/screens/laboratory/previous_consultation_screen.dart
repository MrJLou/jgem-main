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
  List<Map<String, String>> _consultations = [];

  void _fetchConsultationRecords(String patientId) {
    final mockData = [
      {'date': '2023-10-15', 'details': 'General Checkup'},
      {'date': '2023-09-20', 'details': 'Flu Symptoms'},
      {'date': '2023-08-10', 'details': 'Follow-up Visit'},
    ];

    setState(() {
      _consultations = mockData;
    });
  }

  void _showConsultationDetails(
      BuildContext context, Map<String, String> consultation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Consultation Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${consultation['date']}'),
            SizedBox(height: 8),
            Text('Details: ${consultation['details']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('Close'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Previous Consultations'),
        backgroundColor: const Color(0xFF1ABC9C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Patient ID',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // INPUT FIELD
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1ABC9C),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _patientIdController,
                    decoration: InputDecoration(
                      hintText: 'Enter Patient ID',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // FETCH BUTTON
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: ElevatedButton(
                  onPressed: () {
                    final patientId = _patientIdController.text.trim();
                    if (patientId.isNotEmpty) {
                      _fetchConsultationRecords(patientId);
                    }
                  },
                  child: const Text('Fetch Records',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ABC9C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // RESULTS CONTAINER
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1000),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: _consultations.isEmpty
                        ? const Center(child: Text('No records found'))
                        : ListView.builder(
                            itemCount: _consultations.length,
                            itemBuilder: (context, index) {
                              final consultation = _consultations[index];
                              return ConsultationCard(
                                date: consultation['date']!,
                                details: consultation['details']!,
                                onTap: () => _showConsultationDetails(
                                    context, consultation),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Individual consultation card with hover + click effects
class ConsultationCard extends StatefulWidget {
  final String date;
  final String details;
  final VoidCallback onTap;

  const ConsultationCard({
    Key? key,
    required this.date,
    required this.details,
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
            color: _isHovering || _isPressed
                ? Colors.white.withOpacity(0.9)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovering
                ? [BoxShadow(blurRadius: 4, color: Colors.black12)]
                : [],
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: Color(0xFF1ABC9C)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultation on ${widget.date}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1ABC9C),
                      ),
                    ),
                    Text(
                      widget.details,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
