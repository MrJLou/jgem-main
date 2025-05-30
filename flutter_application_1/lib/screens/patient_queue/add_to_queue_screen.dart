import 'package:flutter/material.dart';
import '../../services/real_time_sync_service.dart';
import '../../services/queue_service.dart';
import '../../services/database_helper.dart';
import '../../models/active_patient_queue_item.dart';
import '../../models/patient.dart';

class AddToQueueScreen extends StatefulWidget {
  final QueueService queueService;

  const AddToQueueScreen({Key? key, required this.queueService})
      : super(key: key);

  @override
  _AddToQueueScreenState createState() => _AddToQueueScreenState();
}

class _AddToQueueScreenState extends State<AddToQueueScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isAddingToQueue = false;

  int? _calculateAge(String birthDateString) {
    if (birthDateString.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(birthDateString);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age > 0
          ? age
          : 0; // Return 0 if age is negative (e.g. birthdate in future)
    } catch (e) {
      print('Error parsing birthDateString for age calculation: $e');
      return null;
    }
  }

  Future<void> _addPatientToQueue() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isAddingToQueue = true;
      });

      final enteredPatientName = _patientNameController.text.trim();
      final enteredPatientId = _patientIdController.text.trim();

      try {
        final registeredPatientData = await _dbHelper.findRegisteredPatient(
          patientId: enteredPatientId.isNotEmpty ? enteredPatientId : null,
          fullName: enteredPatientName,
        );

        if (registeredPatientData != null) {
          // Patient found in the database
          final dbPatientId = registeredPatientData['id'] as String?;
          final dbFullName = registeredPatientData['fullName'] as String?;
          final dbBirthDate = registeredPatientData['birthDate'] as String?;
          final dbGender = registeredPatientData['gender'] as String?;

          final calculatedAge =
              dbBirthDate != null ? _calculateAge(dbBirthDate) : null;

          bool confirmUseDbData = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text('Registered Patient Found'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Text(
                            'A registered patient matching the details was found:'),
                        SizedBox(height: 10),
                        Text('DB ID: ${dbPatientId ?? 'N/A'}'),
                        Text('DB Name: ${dbFullName ?? 'N/A'}'),
                        Text('DB Gender: ${dbGender ?? 'N/A'}'),
                        Text('DB BirthDate: ${dbBirthDate ?? 'N/A'}'),
                        Text(
                            'Calculated Age: ${calculatedAge?.toString() ?? 'N/A'}'),
                        SizedBox(height: 15),
                        Text('Do you want to use these details for the queue?'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: Text('No, Use My Input'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    ElevatedButton(
                      child: Text('Yes, Use DB Details'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ) ??
              false;

          String finalPatientIdToUse;
          String finalPatientNameToUse;
          int? finalAgeToUse;
          String? finalGenderToUse;

          if (confirmUseDbData) {
            finalPatientIdToUse = dbPatientId ??
                enteredPatientId; // Fallback just in case, but should be dbPatientId
            finalPatientNameToUse = dbFullName ?? enteredPatientName;
            finalAgeToUse = calculatedAge ??
                (_ageController.text.isNotEmpty
                    ? int.tryParse(_ageController.text)
                    : null);
            finalGenderToUse = dbGender ?? _genderController.text.trim();

            // Update controllers to reflect DB data being used
            _patientIdController.text = finalPatientIdToUse;
            _patientNameController.text = finalPatientNameToUse;
            _ageController.text = finalAgeToUse?.toString() ?? '';
            _genderController.text = finalGenderToUse ?? '';
          } else {
            // User chose to use their manually entered data, even if a DB match was found.
            // Or if they pressed 'No' or dismissed a dialog confirming override.
            finalPatientIdToUse = enteredPatientId;
            finalPatientNameToUse = enteredPatientName;
            finalAgeToUse = _ageController.text.isNotEmpty
                ? int.tryParse(_ageController.text)
                : null;
            finalGenderToUse = _genderController.text.trim().isEmpty
                ? null
                : _genderController.text.trim();
          }

          // Proceed to add to queue with final chosen/confirmed details
          final now = DateTime.now();
          final newPatientQueueData = {
            'name': finalPatientNameToUse,
            'patientId':
                finalPatientIdToUse.isNotEmpty ? finalPatientIdToUse : null,
            'arrivalTime': now.toIso8601String(),
            'addedTime': now.toIso8601String(),
            'gender': finalGenderToUse,
            'age': finalAgeToUse,
            'condition': _conditionController.text.trim().isEmpty
                ? 'General consultation'
                : _conditionController.text.trim(),
            'status': 'waiting',
          };

          await widget.queueService.addToQueue(newPatientQueueData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$finalPatientNameToUse added to queue!'),
              backgroundColor: Colors.teal,
              duration: const Duration(seconds: 3),
            ),
          );
          _formKey.currentState!.reset();
          _patientNameController.clear();
          _patientIdController.clear();
          _ageController.clear();
          _genderController.clear();
          _conditionController.clear();
          setState(() {}); // Trigger rebuild to update queue list display
        } else {
          // Patient not found in the database
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Patient Not Registered'),
              content: Text(
                  'The patient \'$enteredPatientName\' (ID: ${enteredPatientId.isEmpty ? 'N/A' : enteredPatientId}) is not found in the database. Please register the patient first.'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error processing queue addition: $e'),
              backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isAddingToQueue = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Add to Queue',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Add Patient to Today\'s Queue',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800]),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient Details (Must be a Registered Patient)',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[700])),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _patientNameController,
                        decoration: const InputDecoration(
                            labelText: 'Patient Name (Registered) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person)),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Patient name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _patientIdController,
                        decoration: const InputDecoration(
                            labelText: 'Patient ID (Registered - Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge),
                            hintText: 'Enter patient ID if known'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              enabled:
                                  false, // Age will be auto-filled or from manual override if no DB match
                              decoration: const InputDecoration(
                                  labelText: 'Age (from DB)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.cake)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _genderController,
                              enabled:
                                  false, // Gender will be auto-filled or from manual override if no DB match
                              decoration: const InputDecoration(
                                  labelText: 'Gender (from DB)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _conditionController,
                        decoration: const InputDecoration(
                            labelText: 'Condition/Purpose of Visit',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medical_services),
                            hintText:
                                'Enter medical condition or reason for visit'),
                        maxLines: 2,
                      ),
                    ],
                  ), // End child column
                ), // End Padding
              ), // End Card
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: _isAddingToQueue
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ))
                    : Icon(Icons.person_add_alt_1),
                label: Text(
                    _isAddingToQueue
                        ? 'Verifying & Adding...'
                        : 'Verify & Add to Queue',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                onPressed: _isAddingToQueue ? null : _addPatientToQueue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<ActivePatientQueueItem>>(
                stream: Stream.periodic(const Duration(seconds: 5)).asyncMap(
                    (_) => widget.queueService.getActiveQueueItems(
                        statuses: ['waiting', 'in_consultation'])),
                initialData: [],
                builder: (context, snapshot) {
                  int queueSize = 0;
                  if (snapshot.hasData) {
                    queueSize = snapshot.data!.length;
                  }
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal[200]!)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal[700]),
                        const SizedBox(width: 8),
                        Text(
                            'Current Active Queue (Waiting/Consult): $queueSize patients',
                            style: TextStyle(
                                color: Colors.teal[700],
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Live Queue Status',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800])),
              const SizedBox(height: 10),
              _buildQueueTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueTable() {
    return StreamBuilder<List<ActivePatientQueueItem>>(
      stream: Stream.periodic(const Duration(seconds: 2)).asyncMap(
          (_) => widget.queueService.getActiveQueueItems(
              statuses: ['waiting', 'in_consultation']) // Fetch active items
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading queue: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('Queue is currently empty.',
                  style: TextStyle(fontSize: 16)));
        }
        final queue = snapshot.data!;
        return Column(
          children: [
            _buildQueueTableHeader(),
            ListView.builder(
              shrinkWrap: true, // Important for ListView inside Column
              physics:
                  const NeverScrollableScrollPhysics(), // Disable scrolling for inner ListView
              itemCount: queue.length,
              itemBuilder: (context, index) {
                return _buildQueueTableRow(queue[index]);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildQueueTableHeader() {
    final headers = ['Name', 'Patient ID', 'Arrival', 'Status'];
    return Container(
      color: Colors.teal[600],
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: headers.map((text) {
          return Expanded(
            flex: (text == 'Name' || text == 'Patient ID')
                ? 2
                : 1, // Give more space to Name/ID
            child: Text(text,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                textAlign: TextAlign.center),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQueueTableRow(ActivePatientQueueItem item) {
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(item.patientName, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child:
                  Text(item.patientId ?? 'N/A', textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text(arrivalDisplayTime, textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text(item.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(item.status)))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange.shade700;
      case 'in_consultation':
        return Colors.blue.shade700;
      case 'served':
        return Colors.green.shade700;
      case 'removed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _conditionController.dispose();
    super.dispose();
  }
}
