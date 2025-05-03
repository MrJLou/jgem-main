import 'package:flutter/material.dart';

class LaboratoryStatisticsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Laboratory Test Statistics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<LabTestStat>>(
        future: fetchLabStats(), // Replace with real API later
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data available'));
          }

          final stats = snapshot.data!;

          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.teal[100]),
                  dataRowHeight: 65,
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  columns: const [
                    DataColumn(
                      label: Text('Test Name'),
                    ),
                    DataColumn(
                      label: Text('ICU Day 1'),
                    ),
                    DataColumn(
                      label: Text('ICU Day 2'),
                    ),
                    DataColumn(
                      label: Text('ICU Day 3'),
                    ),
                  ],
                  rows: stats.map((stat) {
                    return DataRow(
                      cells: [
                        DataCell(Text(stat.name)),
                        DataCell(Text(stat.day1)),
                        DataCell(Text(stat.day2)),
                        DataCell(Text(stat.day3)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Mock data model
class LabTestStat {
  final String name;
  final String day1;
  final String day2;
  final String day3;

  LabTestStat({
    required this.name,
    required this.day1,
    required this.day2,
    required this.day3,
  });
}

// Placeholder data until backend is available
Future<List<LabTestStat>> fetchLabStats() async {
  await Future.delayed(Duration(seconds: 1)); // Simulate network delay
  return [
    LabTestStat(
        name: 'Hematocrit (%)',
        day1: '31.9 [5.0]',
        day2: '30.7 [4.4]',
        day3: '30.4 [4.2]'),
    LabTestStat(
        name: 'Platelet (K/μL)',
        day1: '218.4 [112.2]',
        day2: '198.8 [110.4]',
        day3: '196.0 [114.9]'),
    LabTestStat(
        name: 'WBC (K/μL)',
        day1: '12.3 [8.8]',
        day2: '12.0 [7.6]',
        day3: '11.8 [7.9]'),
    LabTestStat(
        name: 'Glucose (mg/dL)',
        day1: '139.3 [50.5]',
        day2: '128.4 [44.2]',
        day3: '129.1 [43.0]'),
    LabTestStat(
        name: 'HCO₃ (mEq/L)',
        day1: '24.4 [4.6]',
        day2: '25.0 [4.6]',
        day3: '25.5 [4.8]'),
    LabTestStat(
        name: 'Potassium (mEq/L)',
        day1: '4.1 [0.5]',
        day2: '4.1 [0.5]',
        day3: '4.0 [0.5]'),
    LabTestStat(
        name: 'Sodium (mEq/L)',
        day1: '138.6 [4.4]',
        day2: '138.7 [4.5]',
        day3: '138.9 [4.7]'),
    LabTestStat(
        name: 'Chloride (mEq/L)',
        day1: '105.5 [5.7]',
        day2: '105.3 [5.6]',
        day3: '105.0 [5.8]'),
    LabTestStat(
        name: 'BUN (mg/dL)',
        day1: '25.3 [20.9]',
        day2: '26.2 [21.2]',
        day3: '28.0 [22.1]'),
    LabTestStat(
        name: 'Creatinine (mg/dL)',
        day1: '1.4 [1.5]',
        day2: '1.4 [1.5]',
        day3: '1.5 [1.5]'),
    LabTestStat(
        name: 'Lactate (mmol/L)',
        day1: '2.5 [2.0]',
        day2: '2.2 [2.3]',
        day3: '2.1 [2.2]'),
  ];
}
