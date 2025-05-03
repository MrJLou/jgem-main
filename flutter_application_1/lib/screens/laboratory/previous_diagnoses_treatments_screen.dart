import 'package:flutter/material.dart';

class PreviousDiagnosesTreatmentsScreen extends StatefulWidget {
  @override
  _PreviousDiagnosesTreatmentsScreenState createState() =>
      _PreviousDiagnosesTreatmentsScreenState();
}

class _PreviousDiagnosesTreatmentsScreenState
    extends State<PreviousDiagnosesTreatmentsScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  List<Map<String, String>> _records = [];
  bool _isLoading = false;

  void _fetchRecords(String patientId) async {
    setState(() => _isLoading = true);

    await Future.delayed(Duration(milliseconds: 800));

    final mockData = [
      {
        'diagnosis': 'Hypertension',
        'treatment': 'Medication',
        'date': '2023-09-15'
      },
      {
        'diagnosis': 'Diabetes',
        'treatment': 'Insulin Therapy',
        'date': '2023-08-20'
      },
      {'diagnosis': 'Asthma', 'treatment': 'Inhaler', 'date': '2023-07-10'},
    ];

    setState(() {
      _records = mockData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Previous Diagnoses & Treatments'),
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
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: ElevatedButton(
                  onPressed: () {
                    final patientId = _patientIdController.text.trim();
                    if (patientId.isNotEmpty) {
                      _fetchRecords(patientId);
                    }
                  },
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text('Fetch Records',
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
                    child: _records.isEmpty
                        ? const Center(child: Text('No records found'))
                        : ListView.builder(
                            itemCount: _records.length,
                            itemBuilder: (context, index) {
                              final record = _records[index];
                              return RecordCard(
                                diagnosis: record['diagnosis']!,
                                treatment: record['treatment']!,
                                date: record['date']!,
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

class RecordCard extends StatefulWidget {
  final String diagnosis;
  final String treatment;
  final String date;

  const RecordCard({
    Key? key,
    required this.diagnosis,
    required this.treatment,
    required this.date,
  }) : super(key: key);

  @override
  _RecordCardState createState() => _RecordCardState();
}

class _RecordCardState extends State<RecordCard> {
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
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Diagnosis Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Diagnosis: ${widget.diagnosis}'),
                  SizedBox(height: 8),
                  Text('Treatment: ${widget.treatment}'),
                  SizedBox(height: 8),
                  Text('Date: ${widget.date}'),
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
        },
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
              Icon(Icons.local_hospital, color: Color(0xFF1ABC9C)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diagnosis: ${widget.diagnosis}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1ABC9C),
                      ),
                    ),
                    Text(
                      'Treatment: ${widget.treatment}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Date: ${widget.date}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
