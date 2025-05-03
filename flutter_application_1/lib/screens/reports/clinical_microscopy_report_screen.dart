import 'package:flutter/material.dart';

class ClinicalMicroscopyReportScreen extends StatefulWidget {
  @override
  _ClinicalMicroscopyReportScreenState createState() =>
      _ClinicalMicroscopyReportScreenState();
}

class _ClinicalMicroscopyReportScreenState
    extends State<ClinicalMicroscopyReportScreen> {
  final List<PatientRecord> _records = [
    PatientRecord(
      name: 'Harold Finch',
      id: 'CM-5001',
      age: '66',
      diagnosis: 'Normal Urinalysis',
    ),
    PatientRecord(
      name: 'Samantha Groves',
      id: 'CM-5002',
      age: '35',
      diagnosis: 'Ova Detected in Stool Sample',
    ),
    PatientRecord(
      name: 'Root Shaw',
      id: 'CM-5003',
      age: '40',
      diagnosis: 'Elevated White Cells in Urine',
    ),
  ];

  PatientRecord? _selectedRecord;
  final Map<int, bool> _hoverStates = {};

  void _handleDownload(PatientRecord record) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Downloading ${record.name}\'s clinical microscopy report...')),
    );
  }

  void _handlePDFConversion() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generating PDF...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRecord = null),
      child: Scaffold(
        backgroundColor: Colors.teal[300],
        appBar: AppBar(
          title: const Text('Clinical Microscopy Reports'),
          backgroundColor: Colors.teal[600],
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _buildLeftPanel(),
              const SizedBox(width: 24),
              _buildRightPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Expanded(
      flex: 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectedReportSection(),
            const SizedBox(height: 24),
            _buildPatientList(),
            const SizedBox(height: 24),
            _buildActionButton('Convert to PDF', _handlePDFConversion),
            const SizedBox(height: 12),
            _buildActionButton('Download', () {
              if (_selectedRecord != null) _handleDownload(_selectedRecord!);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedReportSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Selected Microscopy Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.teal[800],
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedRecord != null)
            Text(
              _selectedRecord!.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            const Text('No report selected'),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    return Flexible(
      child: ListView.builder(
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          return MouseRegion(
            onEnter: (_) => setState(() => _hoverStates[index] = true),
            onExit: (_) => setState(() => _hoverStates[index] = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _hoverStates[index] ?? false
                    ? Colors.teal[100]
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal[700],
                  child: const Icon(Icons.biotech, color: Colors.white),
                ),
                title: Text(record.name),
                subtitle: Text('ID: ${record.id}'),
                onTap: () => setState(() => _selectedRecord = record),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Expanded(
      flex: 6,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Clinical Microscopy Report',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            const Divider(color: Colors.grey),
            if (_selectedRecord != null)
              Column(
                children: [
                  _buildKeyValueSection(),
                  const SizedBox(height: 16),
                  _buildDetailsSection(),
                ],
              )
            else
              const Center(child: Text('Select a report to view')),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueSection() {
    return Column(
      children: [
        _buildKeyValuePair('Name', _selectedRecord!.name),
        _buildKeyValuePair('ID', _selectedRecord!.id),
        _buildKeyValuePair('Age', _selectedRecord!.age),
        _buildKeyValuePair('Diagnosis', _selectedRecord!.diagnosis),
      ],
    );
  }

  Widget _buildKeyValuePair(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow('Test Date', 'May 3, 2025'),
        _buildDataRow('Conducted By', 'Dr. Elaine Thompson'),
        _buildDataRow('Department', 'Laboratory'),
        const SizedBox(height: 16),
        _buildSectionTitle('Microscopic Findings'),
        const Divider(),
        const Text(
          '• Urine: Clear, yellow, pH 6.0\n'
          '• White Blood Cells: 3-5/HPF\n'
          '• Red Blood Cells: 0-2/HPF\n'
          '• Crystals: Amorphous urates\n'
          '• Stool: Occasional parasite ova observed',
        ),
        const SizedBox(height: 8),
        _buildSectionTitle('Method'),
        const Divider(),
        const Text(
            'Manual microscopy of urine and stool specimens using standard lab procedures.'),
        const SizedBox(height: 8),
        _buildSectionTitle('Technician Notes'),
        const Divider(),
        Text(
          _selectedRecord!.diagnosis.contains('Normal')
              ? 'All parameters within reference range. No abnormalities noted.'
              : 'Further evaluation advised based on microscopy results.',
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.teal[600],
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class PatientRecord {
  final String name;
  final String id;
  final String age;
  final String diagnosis;

  PatientRecord({
    required this.name,
    required this.id,
    required this.age,
    required this.diagnosis,
  });
}
