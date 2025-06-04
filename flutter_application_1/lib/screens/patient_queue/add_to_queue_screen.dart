import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting price
import '../../services/real_time_sync_service.dart';
import '../../services/queue_service.dart';
import '../../services/database_helper.dart';
import '../../services/appointment_database_service.dart';
import '../../models/active_patient_queue_item.dart';
import '../../models/patient.dart'; // Assuming Patient model might be used, though not directly in snippet
import '../../models/appointment.dart';

// Define Service data structure
class ServiceItem {
  final String name;
  final String category;
  final double price;
  bool isSelected; // To track selection in the dialog

  ServiceItem({
    required this.name,
    required this.category,
    required this.price,
    this.isSelected = false,
  });
}

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
  // final TextEditingController _conditionController = TextEditingController(); // Replaced
  final TextEditingController _otherConditionController =
      TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  late AppointmentDatabaseService _appointmentDbService;
  bool _isAddingToQueue = false;

  // Predefined services
  final List<ServiceItem> _availableServices = [
    ServiceItem(name: 'Consultation', category: 'Consultation', price: 500.0),
    ServiceItem(name: 'Chest X-ray', category: 'Laboratory', price: 350.0),
    ServiceItem(name: 'ECG', category: 'Laboratory', price: 650.0),
    ServiceItem(
        name: 'Fasting Blood Sugar', category: 'Laboratory', price: 150.0),
    ServiceItem(
        name: 'Total Cholesterol', category: 'Laboratory', price: 250.0),
    ServiceItem(name: 'Triglycerides', category: 'Laboratory', price: 250.0),
    ServiceItem(
        name: 'High Density Lipoprotein (HDL)',
        category: 'Laboratory',
        price: 250.0),
    ServiceItem(
        name: 'Low Density Lipoprotein (LDL)',
        category: 'Laboratory',
        price: 200.0), // Corrected HDL to LDL based on common tests
    ServiceItem(name: 'Blood Uric Acid', category: 'Laboratory', price: 200.0),
    ServiceItem(name: 'Creatinine', category: 'Laboratory', price: 200.0),
  ];

  List<ServiceItem> _selectedServices = [];
  double _totalPrice = 0.0;
  bool _showOtherConditionField = false;

  @override
  void initState() {
    super.initState();
    _appointmentDbService = AppointmentDatabaseService(_dbHelper);
    _fetchAvailableServices();
  }

  Future<void> _fetchAvailableServices() async {
    // Implementation of _fetchAvailableServices method
  }

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
      if (_selectedServices.isEmpty &&
          _otherConditionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Please select at least one service or specify a purpose.'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      final enteredPatientName = _patientNameController.text.trim();
      final enteredPatientId = _patientIdController.text.trim();

      // Call the new method in QueueService (you need to implement this in QueueService)
      bool alreadyInQueue = await widget.queueService.isPatientCurrentlyActive(
        patientId: enteredPatientId.isNotEmpty ? enteredPatientId : null,
        patientName: enteredPatientName,
      );

      if (alreadyInQueue) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$enteredPatientName is already in the active queue (waiting or in consultation).'),
            backgroundColor: Colors.orange[700],
          ),
        );
        return; // Stop further execution
      }

      // --- NEW CHECK: Patient has appointment today? ---
      String? patientIdForAppointmentCheck;
      if (enteredPatientId.isNotEmpty) {
        patientIdForAppointmentCheck = enteredPatientId;
      } else {
        // If ID wasn't entered, try to get it from a potential DB match (if user confirms use of DB data later)
        // This part is tricky because patient data confirmation happens *after* this check ideally.
        // For now, we'll rely on `enteredPatientId` or the ID confirmed from DB if we adjust flow later.
        // Let's prioritize checking if enteredPatientId exists.
        // If not, this check might be skipped or be less effective if only name is available.
      }
      
      // Attempt to get patientId from registeredPatientData if not directly entered.
      // This logic depends on how you want to sequence the user interactions (DB match dialog vs. appointment check dialog)
      // For this iteration, let's assume we first check based on entered ID, then later refine if needed.
      final preliminaryRegisteredPatientData = await _dbHelper.findRegisteredPatient(
          patientId: enteredPatientId.isNotEmpty ? enteredPatientId : null,
          fullName: enteredPatientName,
      );

      if (preliminaryRegisteredPatientData != null && preliminaryRegisteredPatientData['id'] != null) {
          patientIdForAppointmentCheck = preliminaryRegisteredPatientData['id'] as String;
      }


      if (patientIdForAppointmentCheck != null && patientIdForAppointmentCheck.isNotEmpty) {
        final List<Appointment> patientAppointments = await _appointmentDbService.getPatientAppointments(patientIdForAppointmentCheck);
        final DateTime today = DateTime.now();
        final todaysAppointments = patientAppointments.where((appt) {
          return appt.date.year == today.year &&
                 appt.date.month == today.month &&
                 appt.date.day == today.day &&
                 (appt.status.toLowerCase() == 'scheduled' || appt.status.toLowerCase() == 'confirmed' || appt.status.toLowerCase() == 'in consultation');
        }).toList();

        if (todaysAppointments.isNotEmpty) {
          // ignore: use_build_context_synchronously
          bool? proceedDespiteAppointment = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              String appointmentsSummary = todaysAppointments
                  .map((a) => "${a.consultationType ?? 'Appointment'} at ${a.time.format(dialogContext)}")
                  .join(", ");
              return AlertDialog(
                title: const Text('Existing Appointment Found'),
                content: Text(
                    '$enteredPatientName has the following appointment(s) scheduled for today: $appointmentsSummary. Do you still want to add them to the walk-in queue?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  ElevatedButton(
                    child: const Text('Yes, Add to Queue'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              );
            },
          );

          if (proceedDespiteAppointment != true) {
            return; // User chose not to proceed
          }
        }
      }
      // --- END NEW CHECK ---

      setState(() {
        _isAddingToQueue = true;
      });

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
                  title: const Text('Registered Patient Found'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        const Text(
                            'A registered patient matching the details was found:'),
                        const SizedBox(height: 10),
                        Text('DB ID: ${dbPatientId ?? 'N/A'}'),
                        Text('DB Name: ${dbFullName ?? 'N/A'}'),
                        Text('DB Gender: ${dbGender ?? 'N/A'}'),
                        Text('DB BirthDate: ${dbBirthDate ?? 'N/A'}'),
                        Text(
                            'Calculated Age: ${calculatedAge?.toString() ?? 'N/A'}'),
                        const SizedBox(height: 15),
                        const Text('Do you want to use these details for the queue?'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('No, Use My Input'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    ElevatedButton(
                      child: const Text('Yes, Use DB Details'),
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

          String conditionSummary =
              _selectedServices.map((s) => s.name).join(', ');
          if (_showOtherConditionField &&
              _otherConditionController.text.trim().isNotEmpty) {
            if (conditionSummary.isNotEmpty) {
              conditionSummary +=
                  "; Other: ${_otherConditionController.text.trim()}";
            } else {
              conditionSummary = _otherConditionController.text.trim();
            }
          }
          if (conditionSummary.isEmpty) conditionSummary = "Not specified";

          final List<Map<String, dynamic>> servicesForQueue = _selectedServices
              .map((service) => {
                    'name': service.name,
                    'category': service.category,
                    'price': service.price,
                  })
              .toList();

          final newPatientQueueData = {
            'name': finalPatientNameToUse,
            'patientId':
                finalPatientIdToUse.isNotEmpty ? finalPatientIdToUse : null,
            'arrivalTime': now.toIso8601String(),
            'addedTime': now.toIso8601String(),
            'gender': finalGenderToUse,
            'age': finalAgeToUse,
            // 'condition': _conditionController.text.trim().isEmpty // Replaced
            //     ? 'General consultation'
            //     : _conditionController.text.trim(),
            'condition': conditionSummary,
            'status': 'waiting',
            'selectedServices': servicesForQueue, // Added
            'totalPrice': _totalPrice, // Added
          };

          await widget.queueService.addPatientDataToQueue(newPatientQueueData);
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
          // _conditionController.clear(); // Removed
          _otherConditionController.clear();
          setState(() {
            _selectedServices
                .forEach((s) => s.isSelected = false); // Reset selection states
            _selectedServices.clear();
            _totalPrice = 0.0;
            _showOtherConditionField = false;
          }); // Trigger rebuild to update queue list display
        } else {
          // Patient not found in the database
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Patient Not Registered'),
              content: Text(
                  'The patient \'$enteredPatientName\' (ID: ${enteredPatientId.isEmpty ? 'N/A' : enteredPatientId}) is not found in the database. Please register the patient first.'),
              actions: [
                TextButton(
                  child: const Text('OK'),
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

  // Method to open the service selection dialog
  void _openServiceSelectionDialog() {
    // Reset isSelected state for all available services before opening dialog
    for (var service in _availableServices) {
      service.isSelected = _selectedServices.any((selected) => selected.name == service.name);
    }
    // Preserve the current "Other" text and selection state for the dialog
    // In add_to_queue_screen, this is _otherConditionController
    TextEditingController dialogOtherController = TextEditingController(text: _otherConditionController.text); 
    // In add_to_queue_screen, this is _showOtherConditionField
    bool currentShowOtherField = _showOtherConditionField; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentDialogPrice = _availableServices
                .where((s) => s.isSelected)
                .fold(0, (sum, item) => sum + item.price);

            Map<String, List<ServiceItem>> groupedServices = {};
            for (var service in _availableServices) {
              (groupedServices[service.category] ??= []).add(service);
            }
            List<String> categoryOrder = ['Consultation', 'Laboratory'];

            return AlertDialog(
              title: const Text('Select Services / Purpose of Visit'),
              contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    ...categoryOrder.where((cat) => groupedServices.containsKey(cat)).expand((category) => [
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                        child: Text(category, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700], fontSize: 16)),
                      ),
                      ...groupedServices[category]!.map((service) => CheckboxListTile(
                            title: Text(
                                '${service.name} (₱${NumberFormat("#,##0.00", "en_US").format(service.price)})',
                                style: const TextStyle(fontSize: 14)),
                            value: service.isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                service.isSelected = value!;
                                currentDialogPrice = _availableServices
                                    .where((s) => s.isSelected)
                                    .fold(0, (sum, item) => sum + item.price);
                              });
                            },
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.teal,
                          )),
                      const Divider(),
                    ]),
                    
                    CheckboxListTile(
                      title: const Text("Other Purpose (Specify below)",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                      value: currentShowOtherField,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          currentShowOtherField = value!;
                        });
                      },
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.teal,
                    ),
                    if (currentShowOtherField)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 4.0),
                        child: TextFormField(
                          controller: dialogOtherController, // Use dialogOtherController here
                          decoration: const InputDecoration(
                              labelText: 'Specify other purpose or details',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Medical Certificate, Fit to Work',
                              isDense: true
                          ),
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total Estimated: ₱${NumberFormat("#,##0.00", "en_US").format(currentDialogPrice)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green[700]),
                      ),
                    ),
                     const SizedBox(height: 10),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  child: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedServices = _availableServices.where((s) => s.isSelected).toList();
                      _totalPrice = _selectedServices.fold(0, (sum, item) => sum + item.price);
                      _showOtherConditionField = currentShowOtherField; // Update state variable
                      if (currentShowOtherField) {
                        _otherConditionController.text = dialogOtherController.text.trim(); // Update state controller
                      } else {
                        _otherConditionController.clear(); // Clear state controller
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
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
      body: Padding(
        // Added overall padding for the Row
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Pane: Input Form
            Expanded(
              flex: 1, // Adjust flex as needed, e.g., 1 for 50% or 2 for 66%
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    right: 8.0), // Add some space between panes
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
                              Text(
                                  'Patient Details (Must be a Registered Patient)',
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
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Patient name is required'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _patientIdController,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Patient ID (Registered - Optional)',
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
                                          prefixIcon:
                                              Icon(Icons.person_outline)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // TextFormField( // This is replaced
                              //   controller: _conditionController,
                              //   decoration: const InputDecoration(
                              //       labelText: 'Condition/Purpose of Visit',
                              //       border: OutlineInputBorder(),
                              //       prefixIcon: Icon(Icons.medical_services),
                              //       hintText:
                              //           'Enter medical condition or reason for visit'),
                              //   maxLines: 2,
                              // ),

                              // New Service Selection UI
                              Text('Services / Purpose of Visit',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700])),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.medical_services_outlined),
                                label: const Text('Select Services / Purpose'),
                                onPressed: _openServiceSelectionDialog,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[50],
                                    foregroundColor: Colors.teal[700],
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    textStyle: const TextStyle(fontSize: 15)),
                              ),
                              const SizedBox(height: 10),
                              if (_selectedServices.isNotEmpty)
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: _selectedServices
                                      .map((service) => Chip(
                                            label: Text(
                                                '${service.name} (₱${service.price.toStringAsFixed(2)})'),
                                            backgroundColor: Colors.teal[100],
                                            labelStyle: TextStyle(
                                                color: Colors.teal[800]),
                                          ))
                                      .toList(),
                                ),
                              if (_showOtherConditionField &&
                                  _otherConditionController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                      "Other: ${_otherConditionController.text}",
                                      style: const TextStyle(
                                          fontStyle: FontStyle.italic)),
                                ),
                              if (_selectedServices.isNotEmpty ||
                                  (_showOtherConditionField &&
                                      _otherConditionController
                                          .text.isNotEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    'Total Estimated Price: ₱${_totalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700]),
                                  ),
                                ),
                              // End New Service Selection UI
                            ],
                          ), // End child column
                        ), // End Padding
                      ), // End Card
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: _isAddingToQueue
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ))
                            : const Icon(Icons.person_add_alt_1),
                        label: Text(
                            _isAddingToQueue
                                ? 'Verifying & Adding...'
                                : 'Verify & Add to Queue',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        onPressed: _isAddingToQueue ? null : _addPatientToQueue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<List<ActivePatientQueueItem>>(
                        stream: Stream.periodic(const Duration(seconds: 5))
                            .asyncMap((_) => widget.queueService
                                .getActiveQueueItems(
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
                                Icon(Icons.info_outline,
                                    color: Colors.teal[700]),
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
                    ],
                  ),
                ),
              ),
            ),

            // Right Pane: Live Queue Table
            Expanded(
              flex: 1, // Adjust flex as needed
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 8.0), // Add some space between panes
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Live Queue Status',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[800])),
                    const SizedBox(height: 10),
                    Expanded(
                      // Make the table take available vertical space
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.teal[300]!, width: 1.5),
                          borderRadius: BorderRadius.circular(12.0),
                          color: Colors.white, // Background for the table area
                        ),
                        padding: const EdgeInsets.all(
                            8.0), // Padding inside the border
                        child: _buildQueueTable(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            Expanded(
              // Allow ListView to scroll within its parent Column/Container
              child: ListView.builder(
                // shrinkWrap: true, // Not needed if parent is Expanded
                // physics: const NeverScrollableScrollPhysics(), // Not needed if parent is Expanded
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  return _buildQueueTableRow(queue[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQueueTableHeader() {
    final headers = [
      'Queue No.',
      'Name',
      'Patient ID',
      'Arrival',
      'Purpose',
      'Status'
    ];
    return Container(
      color: Colors.teal[600], // Header background
      // Apply rounded corners only to top-left and top-right if inside the bordered container
      // Or remove this specific background if the outer container's border is enough.
      // For simplicity, keeping it as is, but for perfect clipping, might need ClipRRect.
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: headers.map((text) {
          return Expanded(
            flex: (text == 'Name')
                ? 3
                : (text == 'Patient ID'
                    ? 2
                    : (text == 'Purpose')
                        ? 3
                        : 1),
            child: Text(text,
                style: const TextStyle(
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

    // Access conditionOrPurpose, which should now be part of the ActivePatientQueueItem model
    // and populated by your QueueService.
    String purposeText = item.conditionOrPurpose ?? 'Not specified';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(
          vertical: 8, horizontal: 8), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white, // Row background
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade200)), // Lighter border
      ),
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text(item.queueNumber.toString(),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 3,
              child: Text(
                item.patientName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              )),
          Expanded(
              flex: 2,
              child: Text(item.patientId ?? 'N/A',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 1,
              child: Text(arrivalDisplayTime,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 3,
              child: Tooltip(
                message: purposeText,
                child: Text(
                  purposeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              )),
          Expanded(
              flex: 1,
              child: Text(_getDisplayStatus(item.status),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
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

  // Helper to get display-friendly status string
  static String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return 'Waiting';
      case 'in_consultation':
        return 'In Consultation'; // Changed
      case 'served':
        return 'Served';
      case 'removed':
        return 'Removed';
      default:
        return status; // Fallback to the original status if unknown
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    // _conditionController.dispose(); // Removed
    _otherConditionController.dispose();
    super.dispose();
  }
}



