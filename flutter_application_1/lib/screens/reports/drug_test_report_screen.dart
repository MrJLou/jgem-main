import 'package:flutter/material.dart';

class DrugTestReportScreen extends StatefulWidget {
  const DrugTestReportScreen({super.key});

  @override
  DrugTestReportScreenState createState() => DrugTestReportScreenState();
}

class DrugTestReportScreenState extends State<DrugTestReportScreen> {
  final List<PatientRecord> _records = [
    PatientRecord(
      name: 'Alice Johnson',
      id: 'DT-2001',
      age: '28',
      diagnosis: 'Negative',
    ),
    PatientRecord(
      name: 'Mark Lee',
      id: 'DT-2002',
      age: '36',
      diagnosis: 'Positive',
    ),
    PatientRecord(
      name: 'Ella Wright',
      id: 'DT-2003',
      age: '45',
      diagnosis: 'Negative',
    ),
  ];

  PatientRecord? _selectedRecord;
  final Map<int, bool> _hoverStates = {};

  void _handleDownload(PatientRecord record) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${record.name}\'s report...')),
    );
  }

  void _handlePDFConversion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRecord = null),
      child: Scaffold(
        backgroundColor: Colors.teal[300],
        appBar: AppBar(
          title: const Text('Drug Test Reports'),
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
            'Selected Drug Test',
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
                    color: Colors.black.withAlpha(26),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal[700],
                  child: const Icon(Icons.person, color: Colors.white),
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
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label),
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
              'Drug Test Report',
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
        _buildKeyValuePair('Result', _selectedRecord!.diagnosis),
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
        _buildDataRow('Test Date', 'April 20, 2025'),
        _buildDataRow('Tested By', 'Dr. Nathan Reed'),
        _buildDataRow('Department', 'Toxicology Lab'),
        const SizedBox(height: 16),
        _buildSectionTitle('Substances Screened'),
        const Divider(),
        const Text(
          '• Marijuana (THC)\n'
          '• Cocaine\n'
          '• Amphetamines\n'
          '• Opiates\n'
          '• Benzodiazepines',
        ),
        const SizedBox(height: 8),
        _buildSectionTitle('Method'),
        const Divider(),
        const Text('Urine Test - Immunoassay Screening'),
        const SizedBox(height: 8),
        _buildSectionTitle('Doctor\'s Notes'),
        const Divider(),
        Text(
          _selectedRecord!.diagnosis == 'Negative'
              ? 'All screened substances tested negative. No further action required.'
              : 'Positive result. Recommended for follow-up confirmatory testing (GC-MS).',
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
