import 'package:flutter/material.dart';

class AddToQueueScreen extends StatefulWidget {
  final List<Map<String, dynamic>> queue;

  AddToQueueScreen({required this.queue});

  @override
  _AddToQueueScreenState createState() => _AddToQueueScreenState();
}

class _AddToQueueScreenState extends State<AddToQueueScreen> {
  final TextEditingController _patientNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add to Queue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Add Patient to Queue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                ),
              ),
              SizedBox(height: 10),
              Container(
                width: 600,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(197, 252, 248, 248),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _patientNameController,
                  decoration: InputDecoration(
                    labelText: 'Patient Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final patientName = _patientNameController.text.trim();
                  if (patientName.isNotEmpty) {
                    setState(() {
                      widget.queue.add({
                        'name': patientName,
                        'arrivalTime': '11:15 AM',
                        'gender': 'Male',
                        'age': 30,
                        'condition': 'Unknown',
                        'status': 'active',
                      });
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$patientName added to queue!'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                    _patientNameController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a patient name'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(
                  'Add to Queue',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
