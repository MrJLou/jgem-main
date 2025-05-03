import 'package:flutter/material.dart';

class PatientStatisticsScreen extends StatefulWidget {
  @override
  _PatientStatisticsScreenState createState() =>
      _PatientStatisticsScreenState();
}

class _PatientStatisticsScreenState extends State<PatientStatisticsScreen> {
  List<Map<String, dynamic>> patients = [
    {
      'no': '01',
      'date': '18/01/2025',
      'id': 'ID001',
      'name': 'Christian',
      'age': 21,
      'gender': 'Male',
      'diagnosis': 'Drug Test',
    },
    {
      'no': '02',
      'date': '18/01/2025',
      'id': 'ID002',
      'name': 'Justin',
      'age': 21,
      'gender': 'Male',
      'diagnosis': 'Drug Test',
    },
    {
      'no': '03',
      'date': '18/01/2025',
      'id': 'ID003',
      'name': 'Rainler',
      'age': 22,
      'gender': 'Male',
      'diagnosis': 'Routine Checkup',
    },
  ];

  final Color primaryColor = Colors.teal[700]!;
  final TextStyle headerStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );
  final TextStyle cellStyle = TextStyle(fontSize: 14);

  void addPatient() {
    final newNo = (patients.length + 1).toString().padLeft(2, '0');
    final newId = 'ID${patients.length + 1}';
    setState(() {
      patients.add({
        'no': newNo,
        'date': '19/01/2025',
        'id': newId,
        'name': 'New Patient',
        'age': 30,
        'gender': 'Female',
        'diagnosis':
            patients.isNotEmpty && patients[0]['diagnosis'] == 'Drug Test'
                ? 'Routine Checkup'
                : 'Drug Test',
      });
    });
  }

  void removePatient(int index) {
    setState(() {
      patients.removeAt(index);
    });
  }

  Future<bool?> showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Are you sure you want to remove this patient?"),
        actions: [
          TextButton(
              onPressed: Navigator.of(context).pop, child: Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPatients = patients.length;

    final ages = patients.map((p) => p['age'] as int).toList();
    final minAge = ages.isNotEmpty ? ages.reduce((a, b) => a < b ? a : b) : 0;
    final maxAge = ages.isNotEmpty ? ages.reduce((a, b) => a > b ? a : b) : 0;
    final ageRange = ages.isNotEmpty ? '$minAge–$maxAge' : '0–0';

    final genderCounts = <String, int>{};
    for (var p in patients) {
      final gender = p['gender'] as String;
      genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
    }
    final mostCommonGender = genderCounts.entries.isNotEmpty
        ? genderCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'None';

    final diagnosisCounts = <String, int>{};
    for (var p in patients) {
      final diagnosis = p['diagnosis'] as String;
      diagnosisCounts[diagnosis] = (diagnosisCounts[diagnosis] ?? 0) + 1;
    }
    final mostCommonDiagnosis = diagnosisCounts.entries.isNotEmpty
        ? diagnosisCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
        : 'None';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: Text(
          'Patient Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryCard('Total Patients', totalPatients.toString(),
                      Icons.local_hospital),
                  _buildSummaryCard('Average Age', ageRange, Icons.person),
                  _buildSummaryCard(
                      'Gender', 'Mostly $mostCommonGender', Icons.transgender),
                  _buildSummaryCard('Diagnoses', 'Mostly $mostCommonDiagnosis',
                      Icons.medical_services),
                ],
              ),
              SizedBox(height: 20),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Latest Patient Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              _buildPatientTable(),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: addPatient,
                  icon: Icon(Icons.add),
                  label: Text('Add Patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.teal, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Icon(icon, size: 30, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientTable() {
    final headers = [
      'No.',
      'Date',
      'ID',
      'Name',
      'Age',
      'Gender',
      'Diagnosis',
      'Actions'
    ];

    return Column(
      children: [
        Container(
          color: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: headers
                .map((text) => TableCellWidget(text: text, style: headerStyle))
                .toList(),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            final cells = [
              patient['no'],
              patient['date'],
              patient['id'],
              patient['name'],
              patient['age'].toString(),
              patient['gender'],
              patient['diagnosis'],
            ];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ...cells.map((text) => Expanded(
                        child: Center(
                          child: Text(text, style: cellStyle),
                        ),
                      )),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tooltip(
                          message: "Remove",
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red[400]),
                            onPressed: () async {
                              final shouldDelete =
                                  await showDeleteDialog(context);
                              if (shouldDelete ?? false) {
                                removePatient(index);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class TableCellWidget extends StatelessWidget {
  final String text;
  final TextStyle style;

  const TableCellWidget({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(text, style: style),
      ),
    );
  }
}
