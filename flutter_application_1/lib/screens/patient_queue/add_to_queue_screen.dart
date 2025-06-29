import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting price
import 'dart:async';
import '../../services/api_service.dart'; // Added ApiService import
import '../../models/clinic_service.dart'; // Added ClinicService import
import '../../models/user.dart'; // ADDED for doctors
import '../../services/queue_service.dart';
import '../../services/database_helper.dart';
import '../../services/appointment_database_service.dart';
import '../../services/database_sync_client.dart'; // Added for sync updates
import '../../models/active_patient_queue_item.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';

// Define Service data structure
// class ServiceItem { // Removed ServiceItem class
//   final String name;
//   final String category;
//   final double price;
//   bool isSelected; // To track selection in the dialog

//   ServiceItem({
//     required this.name,
//     required this.category,
//     required this.price,
//     this.isSelected = false,
//   });
// }

class AddToQueueScreen extends StatefulWidget {
  final QueueService queueService;

  const AddToQueueScreen({super.key, required this.queueService});

  @override
  AddToQueueScreenState createState() => AddToQueueScreenState();
}

class AddToQueueScreenState extends State<AddToQueueScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  // final TextEditingController _conditionController = TextEditingController(); // Replaced
  final TextEditingController _otherConditionController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  late AppointmentDatabaseService _appointmentDbService;
  bool _isAddingToQueue = false;

  Timer? _patientSearchDebounce;

  // Predefined services - Will be fetched from DB
  List<ClinicService> _availableServices = []; // Changed to List<ClinicService>
  List<ClinicService> _selectedServices = []; // Changed to List<ClinicService>
  Map<String, bool> _serviceSelectionState =
      {}; // To track selection in the dialog

  // ADDED - Doctor selection state
  List<User> _doctors = [];
  User? _selectedDoctor;  double _totalPrice = 0.0;
  bool _isLaboratoryOnly = false; // NEW: For laboratory queue entries without doctor

  List<Patient>? _searchResults;
  bool _isLoading = false;
  
  // Sync subscription for real-time updates
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _appointmentDbService = AppointmentDatabaseService(_dbHelper);
    _fetchAvailableServices();
    _fetchDoctors(); // ADDED
    _setupSyncListener();
  }
  
  void _setupSyncListener() {
    _syncSubscription = DatabaseSyncClient.syncUpdates.listen((updateEvent) {
      if (!mounted) return;
      
      // Handle queue changes to refresh the queue table
      switch (updateEvent['type']) {
        case 'queue_change_immediate':
        case 'force_queue_refresh':
        case 'remote_change_applied':
          final change = updateEvent['change'] as Map<String, dynamic>?;
          if (change != null && change['table'] == 'active_patient_queue') {
            setState(() {
              // This will trigger a rebuild and refresh the queue table
            });
          }
          break;
      }
    });
  }

  Future<void> _fetchAvailableServices() async {
    try {
      final services = await ApiService.getClinicServices();
      if (mounted) {
        setState(() {
          _availableServices = services;
          // Initialize selection state for the dialog
          _serviceSelectionState = {
            for (var service in _availableServices) service.id: false
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print('Error fetching available services: $e');
      }
    }
  }

  // ADDED - Fetch doctors
  Future<void> _fetchDoctors() async {
    try {
      if (kDebugMode) {
        print('Starting to fetch doctors...');
      }
      final allUsers = await ApiService.getUsers();
      if (kDebugMode) {
        print('Fetched ${allUsers.length} total users');
        for (var user in allUsers) {
          print('User: ${user.fullName}, Role: ${user.role}');
        }
      }
      if (mounted) {
        setState(() {
          _doctors = allUsers.where((user) => user.role == 'doctor').toList();
          if (kDebugMode) {
            print('Filtered ${_doctors.length} doctors');
            for (var doctor in _doctors) {
              print('Doctor: ${doctor.fullName}');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load doctors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print('Error fetching doctors: $e');
      }
    }
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
      if (kDebugMode) {
        print('Error parsing birthDateString for age calculation: $e');
      }
      return null;
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      debugPrint('Searching for patients with query: "$query"');
      final results = await PatientService.searchPatients(query);
      debugPrint('Found ${results.length} patients');
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching patients: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searchResults = [];
        });
      }
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching patients: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _onPatientSearchChanged(String query) {
    if (_patientSearchDebounce?.isActive ?? false) {
      _patientSearchDebounce!.cancel();
    }
    _patientSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPatients(query);
    });
  }

  Future<void> _addPatientToQueue() async {
    if (_formKey.currentState!.validate()) {      if (_selectedServices.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Please select at least one service.'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }// ADDED - Doctor validation (unless laboratory only)
      if (_selectedDoctor == null && !_isLaboratoryOnly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a doctor or check "Laboratory Tests Only".'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      final enteredPatientName = _searchController.text.trim();
      final enteredPatientId = _patientIdController.text.trim();

      // Call the new method in QueueService (you need to implement this in QueueService)
      bool alreadyInQueue = await widget.queueService.isPatientCurrentlyActive(
        patientId: enteredPatientId.isNotEmpty ? enteredPatientId : null,
        patientName: enteredPatientName,
      );

      if (!mounted) return;
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
      }

      final Map<String, dynamic>? preliminaryRegisteredPatientData =
          await _dbHelper.findRegisteredPatient(
        patientId: enteredPatientId.isNotEmpty ? enteredPatientId : null,
        fullName: enteredPatientName,
      );

      if (preliminaryRegisteredPatientData != null) {
        final patient = Patient.fromJson(preliminaryRegisteredPatientData);
        if (patient.id.isNotEmpty) {
          patientIdForAppointmentCheck = patient.id;
        }
      }

      if (patientIdForAppointmentCheck != null &&
          patientIdForAppointmentCheck.isNotEmpty) {
        final List<Appointment> patientAppointments =
            await _appointmentDbService
                .getPatientAppointments(patientIdForAppointmentCheck);
        if (!mounted) return;
        final DateTime today = DateTime.now();
        final todaysAppointments = patientAppointments.where((appt) {
          return appt.date.year == today.year &&
              appt.date.month == today.month &&
              appt.date.day == today.day &&
              (appt.status.toLowerCase() == 'scheduled' ||
                  appt.status.toLowerCase() == 'confirmed' ||
                  appt.status.toLowerCase() == 'in consultation');
        }).toList();

        if (todaysAppointments.isNotEmpty) {
          if (!mounted) return;
          bool? proceedDespiteAppointment = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              String appointmentsSummary = todaysAppointments
                  .map((a) =>
                      "${a.consultationType} at ${a.time.format(dialogContext)}")
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
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Yes, Add to Queue'),
                  ),
                ],
              );
            },
          );

          if (!mounted) return;
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
        final Map<String, dynamic>? registeredPatientData =
            await _dbHelper.findRegisteredPatient(
          patientId: enteredPatientId.isNotEmpty ? enteredPatientId : null,
          fullName: enteredPatientName,
        );

        if (registeredPatientData != null) {
          final registeredPatient = Patient.fromJson(registeredPatientData);
          // Patient found in the database
          final calculatedAge =
              _calculateAge(registeredPatient.birthDate.toIso8601String());

          if (!mounted) return;
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
                        Text('DB ID: ${registeredPatient.id}'),
                        Text('DB Name: ${registeredPatient.fullName}'),
                        Text('DB Gender: ${registeredPatient.gender}'),
                        Text(
                            'DB BirthDate: ${DateFormat.yMMMd().format(registeredPatient.birthDate)}'),
                        Text(
                            'Calculated Age: ${calculatedAge?.toString() ?? 'N/A'}'),
                        const SizedBox(height: 15),
                        const Text(
                            'Do you want to use these details for the queue?'),
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

          if (!mounted) return;
          String finalPatientIdToUse;
          String finalPatientNameToUse;
          int? finalAgeToUse;
          String? finalGenderToUse;

          if (confirmUseDbData) {
            finalPatientIdToUse = registeredPatient.id;
            finalPatientNameToUse = registeredPatient.fullName;
            finalAgeToUse = calculatedAge;
            finalGenderToUse = registeredPatient.gender;

            // Update controllers to reflect DB data being used
            _patientIdController.text = finalPatientIdToUse;
            _searchController.text = finalPatientNameToUse;
            _ageController.text = finalAgeToUse?.toString() ?? '';
            _genderController.text = finalGenderToUse;
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
          final now = DateTime.now();          String conditionSummary =
              _selectedServices.map((s) => s.serviceName).join(', ');
          if (conditionSummary.isEmpty) {
            conditionSummary = "General Consultation";
          }

          final List<Map<String, dynamic>> servicesForDb = _selectedServices
              .map((service) => {
                    'id': service.id,
                    'name': service.serviceName,
                    'category': service.category ?? 'Uncategorized',
                    'price': service.defaultPrice ?? 0.0,
                  })
              .toList();          // Walk-in patients are added ONLY to the queue and do NOT create appointment records.
          // This keeps walk-ins completely separate from scheduled appointments.
          // Queue and appointments are now completely independent systems.
          final addedPatient = await widget.queueService.addPatientDataToQueue({
            'patientName': finalPatientNameToUse,
            'patientId':
                finalPatientIdToUse.isNotEmpty ? finalPatientIdToUse : null,
            'arrivalTime': now.toIso8601String(),
            'status': 'waiting',
            'gender': finalGenderToUse,
            'age': finalAgeToUse,
            'conditionOrPurpose': conditionSummary,
            'selectedServices': servicesForDb,
            'totalPrice': _totalPrice,
            'isWalkIn': true,
            'originalAppointmentId': null, // Explicitly null for walk-ins
            'doctorId': _isLaboratoryOnly ? null : _selectedDoctor?.id,
            'doctorName': _isLaboratoryOnly ? 'Laboratory Only' : _selectedDoctor?.fullName,
            'isLaboratoryOnly': _isLaboratoryOnly, // NEW: Flag for laboratory-only entries
          });

          // Log the queue addition for debugging
          if (kDebugMode) {
            print('Patient added to queue only (not appointments): ${addedPatient.patientName}');
          }

          // ---- Increment service usage count ----
          if (_selectedServices.isNotEmpty) {
            final List<String> selectedServiceIds =
                _selectedServices.map((s) => s.id).toList();
            try {
              await ApiService.incrementServiceUsage(selectedServiceIds);
              if (kDebugMode) {
                print(
                    'Successfully incremented usage for services: $selectedServiceIds');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error incrementing service usage: $e');
              }
              // Optionally show a non-blocking warning to the user or log more formally
            }
          }
          // ---- End Increment service usage count ----

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$finalPatientNameToUse added to queue!'),
              backgroundColor: Colors.teal,
              duration: const Duration(seconds: 3),
            ),
          );
          _formKey.currentState!.reset();
          _searchController.clear();
          _patientIdController.clear();
          _ageController.clear();
          _genderController.clear();
          // _conditionController.clear(); // Removed
          _otherConditionController.clear();          setState(() {
            _selectedDoctor = null; // ADDED
            // _selectedServices // Reset selection states - handled by _serviceSelectionState
            //     .forEach((s) => s.isSelected = false);
            _selectedServices.clear();
            _serviceSelectionState = {
              // Reset selection states
              for (var service in _availableServices)
                service.id: _selectedServices.any((s) => s.id == service.id)            };
            _totalPrice = 0.0;
            _isLaboratoryOnly = false; // Reset laboratory checkbox
            _searchResults = null;
          });// Trigger rebuild to update queue list display
        } else {
          // Patient not found in the database
          if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error processing queue addition: $e'),
              backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isAddingToQueue = false;
          });
        }
      }
    }
  }
  // Method to open the service selection dialog
  void _openServiceSelectionDialog() {
    // Reset isSelected state for all available services before opening dialog
    // Use a temporary map to manage selections within the dialog
    Map<String, bool> currentDialogSelectionState =
        Map.from(_serviceSelectionState);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentDialogPrice = _availableServices
                .where((s) => currentDialogSelectionState[s.id] == true)
                .fold(0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));

            Map<String, List<ClinicService>> groupedServices = {};
            for (var service in _availableServices) {
              (groupedServices[service.category ?? 'Uncategorized'] ??= [])
                  .add(service);
            }
            // Ensure 'Consultation' and 'Laboratory' appear first if they exist, then others.
            List<String> categoryOrder = ['Consultation', 'Laboratory'];
            List<String> allCategories = groupedServices.keys.toList();
            categoryOrder.addAll(
                allCategories.where((cat) => !categoryOrder.contains(cat)));            return AlertDialog(
              title: Text(_isLaboratoryOnly ? 'Select Laboratory Tests' : 'Select Services / Purpose of Visit'),
              contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    if (_availableServices.isEmpty)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            "No services available. Please add services in settings."),
                      )),
                    ...categoryOrder
                        .where((cat) => groupedServices.containsKey(cat))
                        .expand((category) => [
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 10.0, bottom: 4.0),
                                child: Text(category,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[700],
                                        fontSize: 16)),
                              ),
                              ...groupedServices[category]!.map((service) =>
                                  CheckboxListTile(
                                    title: Text(
                                        '${service.serviceName} (₱${NumberFormat("#,##0.00", "en_US").format(service.defaultPrice ?? 0.0)})',
                                        style: const TextStyle(fontSize: 14)),
                                    value: currentDialogSelectionState[
                                            service.id] ??
                                        false,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        currentDialogSelectionState[
                                            service.id] = value!;
                                        currentDialogPrice = _availableServices
                                            .where((s) =>
                                                currentDialogSelectionState[
                                                    s.id] ==
                                                true)
                                            .fold(
                                                0.0,
                                                (sum, item) =>
                                                    sum +
                                                    (item.defaultPrice ?? 0.0));
                                      });
                                    },
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: Colors.teal,
                                  )),                              const Divider(),
                            ]),
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
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),                  onPressed: () {
                    setState(() {
                      _serviceSelectionState =
                          Map.from(currentDialogSelectionState);
                      _selectedServices = _availableServices
                          .where((s) => _serviceSelectionState[s.id] == true)
                          .toList();                      _totalPrice = _selectedServices.fold(
                          0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));
                      _otherConditionController.clear(); // Clear the controller
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Confirm'),
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
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(26),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search Patient by Name or ID',
                                    hintText:
                                        'Type patient name or ID to search...',
                                    prefixIcon: _isLoading
                                        ? Transform.scale(
                                            scale: 0.5,
                                            child:
                                                const CircularProgressIndicator(),
                                          )
                                        : const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    suffixIcon: _searchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(() {
                                                _searchController.clear();
                                                _searchResults = null;
                                                _patientIdController.clear();
                                                _ageController.clear();
                                                _genderController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: _onPatientSearchChanged,
                                ),
                                if (_searchResults != null &&
                                    _searchResults!.isNotEmpty)
                                  _buildSearchResultsList(),
                                if (_searchResults != null &&
                                    _searchResults!.isEmpty &&
                                    _searchController.text.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      'No patients found matching "${_searchController.text}"',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _patientIdController,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Patient ID (Registered - Optional)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge),
                                  hintText: 'Enter patient ID if known'),
                            ),
                            const SizedBox(height: 16),                            DropdownButtonFormField<User>(
                              decoration: const InputDecoration(
                                labelText: 'Assign Doctor *',
                                border: OutlineInputBorder(),
                                prefixIcon:
                                    Icon(Icons.medical_services_outlined),
                              ),
                              value: _selectedDoctor,
                              hint: const Text('Select a Doctor'),
                              isExpanded: true,
                              items: _doctors.map((User doctor) {
                                return DropdownMenuItem<User>(
                                  value: doctor,
                                  child: Text(
                                    'Dr. ${doctor.fullName}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _isLaboratoryOnly ? null : (User? newValue) {
                                setState(() {
                                  _selectedDoctor = newValue;
                                });
                              },
                              validator: (value) => (!_isLaboratoryOnly && value == null)
                                  ? 'Please select a doctor or check "Laboratory Tests Only"'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            // Laboratory Only Checkbox
                            Card(
                              elevation: 1,
                              color: Colors.blue[50],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _isLaboratoryOnly,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _isLaboratoryOnly = value ?? false;
                                          if (_isLaboratoryOnly) {
                                            _selectedDoctor = null; // Clear doctor selection
                                          }
                                        });
                                      },
                                      activeColor: Colors.blue[600],
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Laboratory Tests Only',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue[800],
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Check this for laboratory tests without doctor consultation',
                                            style: TextStyle(
                                              color: Colors.blue[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.biotech,
                                      color: Colors.blue[600],
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
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
                            const SizedBox(height: 16),                            // New Service Selection UI
                            Text(_isLaboratoryOnly ? 'Laboratory Tests' : 'Services / Purpose of Visit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700])),
                            const SizedBox(height: 8),                            ElevatedButton.icon(
                              icon: const Icon(Icons.medical_services_outlined),
                              label: Text(_isLaboratoryOnly ? 'Select Laboratory Tests' : 'Select Services / Purpose'),
                              onPressed: _openServiceSelectionDialog,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[50],
                                  foregroundColor: Colors.teal[700],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 15)),
                            ),
                            const SizedBox(height: 10),                            if (_selectedServices.isNotEmpty)
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: _selectedServices
                                    .map((service) => Chip(
                                          label: Text(
                                              '${service.serviceName} (₱${(service.defaultPrice ?? 0.0).toStringAsFixed(2)})'),
                                          backgroundColor: Colors.teal[100],
                                          labelStyle: TextStyle(
                                              color: Colors.teal[800]),
                                        ))
                                    .toList(),
                              ),
                            if (_selectedServices.isNotEmpty)
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
                        ),
                      ),
                      const SizedBox(height: 20),
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
                        stream: Stream.periodic(const Duration(seconds: 30))
                            .asyncMap((_) => widget.queueService
                                .getActiveQueueItems(
                                    statuses: ['waiting', 'in_consultation'])),
                        initialData: const [],
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

  Widget _buildSearchResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(40),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.teal[700], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Found ${_searchResults!.length} patient(s)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults!.length,
              itemBuilder: (context, index) {
                final patient = _searchResults![index];
                final age = _calculateAge(patient.birthDate.toIso8601String());

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.teal[100],
                    child: Icon(
                      Icons.person,
                      color: Colors.teal[700],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${patient.id}'),
                      if (age != null)
                        Text('Age: $age • Gender: ${patient.gender}'),
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.teal[600],
                  ),
                  onTap: () {
                    setState(() {
                      _searchController.text = patient.fullName;
                      _patientIdController.text = patient.id;
                      _ageController.text = age?.toString() ?? '';
                      _genderController.text = patient.gender;
                      _searchResults = null;
                    });
                  },
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  dense: false,
                  tileColor: Colors.white,
                  hoverColor: Colors.teal.withAlpha(20),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTable() {
    return StreamBuilder<List<ActivePatientQueueItem>>(
      stream: Stream.periodic(const Duration(seconds: 30)).asyncMap(
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
      'Doctor', // ADDED
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
                ? 2
                : (text == 'Patient ID'
                    ? 2
                    : (text == 'Purpose')
                        ? 2
                        : (text == 'Doctor')
                            ? 2
                            : (text == 'Status')
                                ? 2
                                : 1), // ADDED
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
    String doctorText = item.doctorName ?? 'N/A'; // ADDED

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
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 2,
              child: Text(
                item.patientName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              )),
          Expanded(
              flex: 2,
              child: Text(item.patientId ?? 'N/A',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13))),
          Expanded(
              // ADDED Doctor column
              flex: 2,
              child: Tooltip(
                message: "Dr. $doctorText",
                child: Text(
                  "Dr. $doctorText",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          Expanded(
              flex: 1,
              child: Text(arrivalDisplayTime,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 2,
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
    _patientSearchDebounce?.cancel();
    _syncSubscription?.cancel();
    _patientIdController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    // _conditionController.dispose(); // Removed
    _otherConditionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
