import 'package:flutter/material.dart';

class SerologyTestReportScreen extends StatefulWidget {
  const SerologyTestReportScreen({super.key});

  @override
  _SerologyTestReportScreen createState() => _SerologyTestReportScreen();
}

class _SerologyTestReportScreen extends State<SerologyTestReportScreen> {
  final List<PatientRecord> _records = [
    PatientRecord(
      name: 'Angela Cruz',
      id: 'SERO-7001',
      age: '38',
      diagnosis: 'Hepatitis B Surface Antigen Positive',
    ),
    PatientRecord(
      name: 'Daniel Reed',
      id: 'SERO-7002',
      age: '44',
      diagnosis: 'HIV Non-Reactive',
    ),
    PatientRecord(
      name: 'Linda Park',
      id: 'SERO-7003',
      age: '50',
      diagnosis: 'Syphilis Reactive',
    ),
  ];

  PatientRecord? _selectedRecord;
  final Map<int, bool> _hoverStates = {};

  void _handleDownload(PatientRecord record) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Downloading ${record.name}\'s serology report...')),
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
          title: const Text('Serology Reports'),
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
            'Selected Serology Report',
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              'Serology Test Report',
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
        _buildDataRow('Conducted By', 'Dr. Ava Santos'),
        _buildDataRow('Department', 'Serology'),
        const SizedBox(height: 16),
        _buildSectionTitle('Serological Markers'),
        const Divider(),
        const Text(
          '• HBsAg: Positive\n'
          '• HIV: Non-Reactive\n'
          '• Syphilis (TPHA): Reactive\n'
          '• Anti-HCV: Non-Reactive',
        ),
        const SizedBox(height: 8),
        _buildSectionTitle('Method'),
        const Divider(),
        const Text('Enzyme-linked Immunosorbent Assay (ELISA)'),
        const SizedBox(height: 8),
        _buildSectionTitle('Doctor\'s Interpretation'),
        const Divider(),
        Text(
          _selectedRecord!.diagnosis.contains('Non-Reactive')
              ? 'No serological evidence of infection.'
              : 'Reactive result detected. Further evaluation is recommended.',
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
