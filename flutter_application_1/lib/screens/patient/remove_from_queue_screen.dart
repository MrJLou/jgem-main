import 'package:flutter/material.dart';

class RemoveFromQueueScreen extends StatefulWidget {
  final List<Map<String, dynamic>> queue;

  RemoveFromQueueScreen({required this.queue});

  @override
  _RemoveFromQueueScreenState createState() => _RemoveFromQueueScreenState();
}

class _RemoveFromQueueScreenState extends State<RemoveFromQueueScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<Map<String, dynamic>> filteredQueue;

  @override
  void initState() {
    super.initState();
    filteredQueue = widget.queue;
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterList);
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredQueue = widget.queue
          .where((patient) =>
              patient['name'].toString().toLowerCase().contains(query))
          .toList();
    });
  }

  void _removePatientByName(String name) {
    bool found = false;
    setState(() {
      for (var patient in widget.queue) {
        if (patient['name'].toString().toLowerCase() ==
            name.trim().toLowerCase()) {
          patient['status'] = 'removed';
          found = true;
          break;
        }
      }
    });

    if (!found) {
      _showSnackBar(context, 'No matching patient found.', Colors.red);
    } else {
      _showSnackBar(context, 'Patient marked as removed.', Colors.teal);
      _searchController.clear();
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: Text(
          'Remove from Queue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
      ),
      body: Column(
        children: [
          // Search Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Patient Name:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.teal[200],
                      border: OutlineInputBorder(),
                      hintText: "Enter patient name",
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final input = _searchController.text.trim();
                    if (input.isEmpty) {
                      _showSnackBar(context, 'Please enter a name to remove.',
                          Colors.orange);
                      return;
                    }
                    _removePatientByName(input);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Remove'),
                ),
              ],
            ),
          ),

          // Table Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // Table Header
                  _buildTableHeader(),

                  // Table Rows
                  Expanded(
                    child: filteredQueue.isEmpty
                        ? Center(child: Text('No matching patients found'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics:
                                AlwaysScrollableScrollPhysics(), // ✅ Allows scrolling
                            itemCount: filteredQueue.length,
                            itemBuilder: (context, index) {
                              final patient = filteredQueue[index];
                              return _buildTableRow(patient);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      'Status', // ✅ New column
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
  Widget _buildTableRow(Map<String, dynamic> patient) {
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
          ...dataCells.map((text) => Expanded(
                child: TableCellWidget(
                  text: text.toString(),
                  style: cellStyle,
                ),
              )),
          // Status Cell
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // ✅ Center alignment
              children: [
                if (patient['status'] == 'removed')
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                          195, 214, 213, 213), // ✅ Red background
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Removed'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text('Details'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final TextStyle cellStyle = TextStyle(fontSize: 14);
}

class TableCellWidget extends StatelessWidget {
  final String text;
  final TextStyle style;

  const TableCellWidget({Key? key, required this.text, required this.style})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: style),
    );
  }
}
