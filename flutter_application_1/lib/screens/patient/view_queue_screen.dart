import 'package:flutter/material.dart';

class ViewQueueScreen extends StatelessWidget {
  final List<Map<String, dynamic>> queue;

  ViewQueueScreen({required this.queue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'View Queue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        // ✅ Added top padding
        padding: const EdgeInsets.only(top: 20.0),
        child: queue.isEmpty
            ? Center(
                child: Text(
                  'No patients in the queue',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 50.0, right: 50.0),
                child: Column(
                  children: [
                    // Table Header
                    _buildTableHeader(),

                    // Table Rows
                    Expanded(
                      child: ListView.builder(
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final patient = queue[index];

                          // Build status widget here
                          final statusWidget = patient['status'] == 'removed'
                              ? _buildRemovedTag()
                              : _buildDetailsButton(context, patient);

                          return _buildTableRow(patient, statusWidget);
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // 🔤 Table Header Row
  Widget _buildTableHeader() {
    final headers = [
      'Name',
      'Arrival Time',
      'Gender',
      'Age',
      'Condition',
      'Status'
    ];
    return Container(
      color: Colors.teal[700],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: headers.map((text) {
          return TableCellWidget(
            text: text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          );
        }).toList(),
      ),
    );
  }

  // 📄 Table Row per Patient
  Widget _buildTableRow(Map<String, dynamic> patient, Widget statusWidget) {
    final dataCells = [
      patient['name'],
      '11:15 AM',
      'Male',
      '42',
      'Lung Inflammation',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: patient['status'] == 'removed'
            ? Colors.grey.shade200
            : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...dataCells.map((text) => TableCellWidget(
                text: text.toString(),
                style: cellStyle,
              )),
          TableCellWidget(child: statusWidget),
        ],
      ),
    );
  }

  // 🚫 Removed Tag Pill
  Widget _buildRemovedTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('Removed'),
    );
  }

  // 👁️ Details Button
  Widget _buildDetailsButton(
      BuildContext context, Map<String, dynamic> patient) {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viewing details for ${patient['name']}'),
            backgroundColor: Colors.teal,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text('Details'),
    );
  }

  // 🧾 Reusable Cell Widget
  final TextStyle cellStyle = TextStyle(fontSize: 14);
}

// 📄 Reusable Table Cell Widget
class TableCellWidget extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final Widget? child;

  const TableCellWidget({
    Key? key,
    this.text,
    this.style,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: child ??
            Text(
              text ?? '',
              style: style,
            ),
      ),
    );
  }
}
