import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/appointment.dart';
import 'package:intl/intl.dart'; // For DateFormat.Hm()
import 'package:flutter_application_1/models/patient.dart'; // ADDED - Real Patient model
import 'package:flutter_application_1/models/user.dart'; // ADDED - For Doctor data (assuming doctors are Users)
import 'package:flutter_application_1/services/api_service.dart'; // ADDED
import 'package:flutter_application_1/screens/registration/patient_registration_screen.dart' show ReusablePatientFormFields, FormType; // Specific import
import 'dart:async'; // ADDED for Timer
// Assuming you have models for Patient and Doctor
// import 'package:flutter_application_1/models/patient.dart'; 
// import 'package:flutter_application_1/models/doctor.dart'; 
// import 'package:flutter_application_1/services/appointment_database_service.dart'; // Temporarily commented out
// import 'package:flutter_application_1/services/database_helper.dart'; // Temporarily commented out
// import 'package:flutter_application_1/services/auth_service.dart'; // For getting current user ID

// Define ConsultationType for clarity
class ConsultationType {
  final String name;
  final int durationMinutes;
  ConsultationType({required this.name, required this.durationMinutes});

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ConsultationType &&
        runtimeType == other.runtimeType &&
        name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class AddAppointmentScreen extends StatefulWidget {
  final List<Appointment> existingAppointments;
  final DateTime? selectedDate;
  final Function(Appointment appointment)? onAppointmentSaved;
  final VoidCallback? onCancel;

  const AddAppointmentScreen({
    super.key,
    required this.existingAppointments,
    this.selectedDate,
    this.onAppointmentSaved,
    this.onCancel,
  });

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  // late AppointmentDatabaseService _appointmentService; // Temporarily commented out
  // late AuthService _authService; // For getting current user ID - Uncomment if you use it

  // Form state
  Patient? _selectedPatient;
  User? _selectedDoctor; // CHANGED to User, assuming doctors are users
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  ConsultationType? _selectedConsultationType;
  final TextEditingController _notesController = TextEditingController();

  // Search state variables - ADDED
  final TextEditingController _patientSearchController = TextEditingController();
  List<Patient> _patientSearchResults = [];
  bool _isSearchingPatient = false;
  Timer? _patientSearchDebounce;

  // final TextEditingController _doctorSearchController = TextEditingController(); // REMOVED
  // List<User> _doctorSearchResults = []; // REMOVED
  // bool _isSearchingDoctor = false; // REMOVED
  // Timer? _doctorSearchDebounce; // REMOVED
  List<User> _doctors = []; // RE-ADDED: For dropdown

  bool _isLoading = false;
  String? _errorMessage;

  final List<ConsultationType> _consultationTypes = [
    ConsultationType(name: 'Consultation', durationMinutes: 30),
    ConsultationType(name: 'Follow-up', durationMinutes: 15),
    ConsultationType(name: 'Procedure A', durationMinutes: 60),
  ];

  // Placeholder data - replace with actual data fetching
  List<Patient> _patients = []; // CHANGED - Initialize as empty, to be fetched
  // List<User> _doctors = []; // CHANGED - Initialize as empty, to be fetched, assuming doctors are Users

  // Blood types for the mini registration form
  final List<String> _dialogBloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
  ];

  @override
  void initState() {
    super.initState();
    // IMPORTANT: Initialize DatabaseHelper and AppointmentDatabaseService properly.
    // No longer directly using _appointmentService here, will use ApiService
    print("AddAppointmentScreen: Using ApiService for data operations.");
    
    _fetchInitialFormData(); // ADDED - New method to fetch patients and doctors

    // Default to the first consultation type if available
    if (_consultationTypes.isNotEmpty) {
      _selectedConsultationType = _consultationTypes.first;
    }
    if (widget.selectedDate != null) {
      _selectedDate = widget.selectedDate!;
      // If the passed date is today, ensure selected time is not in the past
      final now = DateTime.now();
      if (DateUtils.isSameDay(_selectedDate, now) && 
          (_selectedTime.hour < now.hour || (_selectedTime.hour == now.hour && _selectedTime.minute < now.minute))) {
        _selectedTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))); // Default to 5 mins ahead
      }
    } else {
       // If no date is passed, and default selected date is today, ensure time is not in the past
      final now = DateTime.now();
      if (DateUtils.isSameDay(_selectedDate, now) && 
          (_selectedTime.hour < now.hour || (_selectedTime.hour == now.hour && _selectedTime.minute < now.minute))) {
         _selectedTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
      }
    }
  }

  // Example: Future<void> _fetchInitialData() async { ... }
  Future<void> _fetchInitialFormData() async { // ADDED
    setState(() {
      _isLoading = true; // Use existing isLoading or add a specific one for form data
      _errorMessage = null;
      _patientSearchResults = [];
      // _doctorSearchResults = []; // REMOVED
    });
    try {
      // Fetch doctors for the dropdown
      final allUsers = await ApiService.getUsers();
      if (mounted) {
        setState(() {
          _doctors = allUsers.where((user) => user.role == 'doctor').toList();
        });
      }

      if (_consultationTypes.isNotEmpty && _selectedConsultationType == null) {
          _selectedConsultationType = _consultationTypes.first;
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load patient/doctor list: ${e.toString()}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() { // RE-ADDED
    setState(() {
      _selectedPatient = null;
      _selectedDoctor = null;
      _selectedConsultationType = _consultationTypes.isNotEmpty ? _consultationTypes.first : null;
      // Reset date and time carefully, considering widget.selectedDate
      final now = DateTime.now();
      _selectedDate = widget.selectedDate ?? now;
      
      TimeOfDay initialTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
      if (DateUtils.isSameDay(_selectedDate, now)) {
          if (initialTime.hour < now.hour || (initialTime.hour == now.hour && initialTime.minute < now.minute)) {
            initialTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
          }
      } else if (_selectedDate.isBefore(now)) {
        // If for some reason the date is past, reset to today
        _selectedDate = now;
        initialTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
      }
       _selectedTime = initialTime;

      _notesController.clear();
      _patientSearchController.clear(); // ADDED
      _patientSearchResults = []; // ADDED
      // _doctorSearchController.clear(); // REMOVED
      // _doctorSearchResults = []; // REMOVED
      _errorMessage = null;
      _formKey.currentState?.reset(); // Also reset form validation state
    });
  }

  String? _getConflictMessage(String doctorId, String patientId, DateTime date, TimeOfDay time, int durationMinutes) {
    DateTime newApptStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    DateTime newApptEnd = newApptStart.add(Duration(minutes: durationMinutes));

    for (var existing in widget.existingAppointments) {
      // Assume a default duration for existing simulated appointments if not set (e.g., 30 mins)
      // When your Appointment model has durationMinutes, use: existing.durationMinutes ?? 30
      int existingDuration = existing.durationMinutes ?? 30; 
      DateTime existingApptStart = DateTime(existing.date.year, existing.date.month, existing.date.day, existing.time.hour, existing.time.minute);
      DateTime existingApptEnd = existingApptStart.add(Duration(minutes: existingDuration));

      // Check for time overlap
      bool overlap = newApptStart.isBefore(existingApptEnd) && newApptEnd.isAfter(existingApptStart);

      if (overlap) {
        if (existing.doctorId == doctorId) {
          return "Doctor Conflict: Dr. $doctorId is booked from ${DateFormat.Hm().format(existingApptStart)} to ${DateFormat.Hm().format(existingApptEnd)}.";
        }
        if (existing.patientId == patientId) {
          return "Patient Conflict: You (Patient $patientId) are booked from ${DateFormat.Hm().format(existingApptStart)} to ${DateFormat.Hm().format(existingApptEnd)}.";
        }
      }
    }
    return null; // No conflict
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialPickerDate = _selectedDate.isBefore(now) ? now : _selectedDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialPickerDate, 
      firstDate: DateTime(now.year, now.month, now.day), // Prevent selecting past dates
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // If date changed to today, check if current _selectedTime is in the past
        final currentTime = DateTime.now();
        if (DateUtils.isSameDay(_selectedDate, currentTime) && 
            (_selectedTime.hour < currentTime.hour || 
             (_selectedTime.hour == currentTime.hour && _selectedTime.minute < currentTime.minute))) {
          _selectedTime = TimeOfDay.fromDateTime(currentTime.add(const Duration(minutes: 5)));
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatient == null || _selectedDoctor == null || _selectedConsultationType == null) {
        setState(() {
          _errorMessage = 'Please select a patient, a doctor, and a consultation type.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error
          )
        );
        return;
      }

      // --- Past Date/Time Check ---
      final DateTime now = DateTime.now();
      final DateTime appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (appointmentDateTime.isBefore(now.subtract(const Duration(minutes: 1)))) { // Allow for a tiny buffer e.g. 1 minute
        setState(() {
          _errorMessage = 'Cannot schedule appointments for past dates or times.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error
          )
        );
        return;
      }
      // --- End Past Date/Time Check ---

      String? conflictMessage = _getConflictMessage(
          _selectedDoctor!.id, 
          _selectedPatient!.id, 
          _selectedDate, 
          _selectedTime, 
          _selectedConsultationType!.durationMinutes
      );
      if (conflictMessage != null) {
        setState(() {
          _errorMessage = conflictMessage;
        });
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error
          )
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        String currentUserId = 'user_placeholder_id'; 
        Appointment newAppointment = Appointment(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID, DB might override
          patientId: _selectedPatient!.id,
          date: _selectedDate,
          time: _selectedTime,
          doctorId: _selectedDoctor!.id, // Use User's ID
          consultationType: _selectedConsultationType!.name,
          durationMinutes: _selectedConsultationType!.durationMinutes,
          status: 'Scheduled', // CHANGED - Real status
          notes: _notesController.text.trim(),
          createdById: currentUserId, // Placeholder, replace with actual logged-in user ID
          createdAt: DateTime.now(),
        );

        // print("Attempting to save appointment: ${newAppointment.toJson()}");
        // Actual save is now handled by the parent AppointmentOverviewScreen's _handleAppointmentSaved method,
        // which will call ApiService.saveAppointment.
        // This screen just prepares the Appointment object and passes it up.
        
        // Simulate preparation and pass to parent - no async delay here anymore for the actual save
        widget.onAppointmentSaved?.call(newAppointment);
        _clearForm(); // Clear form after successfully preparing and passing up

        // No SnackBar here for success, parent will handle it after actual save.
        
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to (simulated) save appointment: ${e.toString()}';
          });
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error
            )
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      // Form validation failed (e.g. empty fields)
      setState(() {
          _errorMessage = 'Please fill all required fields correctly.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error
        )
      );
    }
  }

  void _searchPatients(String query) async { // ADDED
    if (_patientSearchDebounce?.isActive ?? false) _patientSearchDebounce!.cancel();
    _patientSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 2) {
        if (mounted) {
          setState(() {
            _patientSearchResults = [];
            _isSearchingPatient = false;
          });
        }
        return;
      }
      if (mounted) setState(() => _isSearchingPatient = true);
      try {
        final results = await ApiService.searchPatients(query);
        if (mounted) {
          setState(() {
            _patientSearchResults = results;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _patientSearchResults = [];
            // Optionally show an error specific to search
             print("Patient search error: $e");
          });
        }
      } finally {
        if (mounted) setState(() => _isSearchingPatient = false);
      }
    });
  }

  // void _searchDoctors(String query) async { ... } // REMOVED entire method

  @override
  void dispose() {
    _notesController.dispose();
    _patientSearchController.dispose(); 
    _patientSearchDebounce?.cancel(); 
    // _doctorSearchController.dispose(); // REMOVED
    // _doctorSearchDebounce?.cancel(); // REMOVED
    super.dispose();
  }
  
  @override
  void didUpdateWidget(covariant AddAppointmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != null && widget.selectedDate != _selectedDate) {
      setState(() {
        _selectedDate = widget.selectedDate!;
        // If date changed to today, check if current _selectedTime is in the past
        final currentTime = DateTime.now();
        if (DateUtils.isSameDay(_selectedDate, currentTime) && 
            (_selectedTime.hour < currentTime.hour || 
             (_selectedTime.hour == currentTime.hour && _selectedTime.minute < currentTime.minute))) {
          _selectedTime = TimeOfDay.fromDateTime(currentTime.add(const Duration(minutes: 5)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // REMOVED Scaffold and AppBar
    return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Schedule New Appointment',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.5))
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Patient Selection Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Expanded(
                          child: TextFormField( 
                            controller: _patientSearchController, // Use controller
                            decoration: InputDecoration(
                              labelText: 'Search Patient (Name/ID)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _isSearchingPatient // Show loading indicator in search field
                                  ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : (_patientSearchController.text.isNotEmpty 
                                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                          _patientSearchController.clear();
                                          setState(() => _patientSearchResults = []);
                                        })
                                      : null),
                            ),
                            onChanged: _searchPatients, // Call search method
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 0.0), // Align with TextFormField
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('New'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[300],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // Adjusted padding
                                textStyle: const TextStyle(fontSize: 14)
                            ),
                            onPressed: () => _showNewPatientDialog(context), // UPDATED
                          ),
                        ),
                      ],
                    ),
                    if (_selectedPatient != null) ...[
                        Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                            child: Chip(
                                avatar: Icon(Icons.person, color: Colors.teal[700]),
                                label: Text('Selected: ${_selectedPatient!.fullName}'),
                                onDeleted: () {
                                    setState(() {
                                        _selectedPatient = null;
                                        _patientSearchController.clear(); 
                                        _patientSearchResults = [];
                                    });
                                },
                            ),
                        ),
                    ] else if (_patientSearchResults.isNotEmpty) ...[ 
                        const SizedBox(height: 8.0), // Added for spacing
                        Container( // Added Container for border
                          decoration: BoxDecoration( // Added BoxDecoration for border
                            border: Border.all(color: Colors.grey.shade400), // Added border
                            borderRadius: BorderRadius.circular(8.0), // Optional: match border radius of other elements
                          ),
                          child: SizedBox(
                              height: 180, // Adjusted height slightly for table headers
                              child: SingleChildScrollView( // Ensure DataTable itself is scrollable if content overflows
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Patient ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('DoB', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _patientSearchResults.map((patient) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(patient.fullName), onTap: () {
                                          setState(() {
                                            _selectedPatient = patient;
                                            _patientSearchController.clear();
                                            _patientSearchResults = [];
                                          });
                                        }),
                                        DataCell(Text(patient.id), onTap: () {
                                          setState(() {
                                            _selectedPatient = patient;
                                            _patientSearchController.clear();
                                            _patientSearchResults = [];
                                          });
                                        }),
                                        DataCell(Text(DateFormat.yMd().format(patient.birthDate)), onTap: () {
                                          setState(() {
                                            _selectedPatient = patient;
                                            _patientSearchController.clear();
                                            _patientSearchResults = [];
                                          });
                                        }),
                                      ],
                                    );
                                  }).toList(),
                                  dataRowMinHeight: 40, // Adjusted min height for rows
                                  dataRowMaxHeight: 48, // Adjusted max height for rows
                                  headingRowHeight: 48, // Adjusted height for header row
                                  columnSpacing: 16, // Spacing between columns
                                  horizontalMargin: 8, // Margin at the start and end of the table
                                ),
                              )
                          ),
                        ),
                    ] else if (_isSearchingPatient) ...[ 
                        // const Padding(
                        //   padding: EdgeInsets.all(8.0),
                        //   child: Center(child: CircularProgressIndicator()),
                        // )
                    ],
                    const SizedBox(height: 16),

                    // Doctor Selection Row - REVERTED to DropdownButtonFormField
                    DropdownButtonFormField<User>(
                      decoration: InputDecoration(
                        labelText: 'Doctor',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        prefixIcon: const Icon(Icons.medical_services_outlined),
                      ),
                      value: _selectedDoctor,
                      hint: const Text('Select Doctor'),
                      isExpanded: true, // Allow the dropdown to expand and enable ellipsis for long text
                      selectedItemBuilder: (BuildContext context) { // Custom builder for the selected item
                        return _doctors.map<Widget>((User doctor) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 0.0), // Adjust padding if needed
                            child: Text(
                              doctor.fullName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: _doctors.map((User doctor) {
                        return DropdownMenuItem<User>(
                          value: doctor,
                          child: Text(
                            doctor.fullName, 
                            overflow: TextOverflow.ellipsis, // Handle overflow in the list as well
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (User? newValue) {
                        setState(() {
                          _selectedDoctor = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a doctor' : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<ConsultationType>(
                      decoration: InputDecoration(
                        labelText: 'Consultation Type', 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        prefixIcon: const Icon(Icons.category_outlined)
                      ),
                      value: _selectedConsultationType,
                      hint: const Text('Select Consultation Type'),
                      items: _consultationTypes.map((ConsultationType type) {
                        return DropdownMenuItem<ConsultationType>(
                          value: type,
                          child: Text("${type.name} (${type.durationMinutes} mins)"),
                        );
                      }).toList(),
                      onChanged: (ConsultationType? newValue) {
                        setState(() {
                          _selectedConsultationType = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a consultation type' : null,
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(Icons.calendar_today_outlined, color: Colors.teal),
                      title: Text('Date: ${DateFormat.yMMMMd().format(_selectedDate)}'),
                      trailing: const Icon(Icons.edit_outlined, color: Colors.teal, size: 20),
                      onTap: () => _pickDate(context),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                       shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(Icons.access_time_outlined, color: Colors.teal),
                      title: Text('Time: ${_selectedTime.format(context)}'),
                      trailing: const Icon(Icons.edit_outlined, color: Colors.teal, size: 20),
                      onTap: () => _pickTime(context),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        prefixIcon: const Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)) : const Icon(Icons.schedule_send_outlined),
                        label: Text(_isLoading ? 'Scheduling...' : 'Schedule Appointment'),
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        onPressed: () {
                          _clearForm();
                          widget.onCancel?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
  }

  Future<void> _showNewPatientDialog(BuildContext context) async { // UPDATED to _showNewPatientDialog
    final result = await showDialog<Patient>(
        context: context,
        barrierDismissible: false, 
        builder: (BuildContext dialogContext) {
            // Determine a slightly smaller font size for the dialog content
            final currentTextTheme = Theme.of(dialogContext).textTheme;
            const double dialogFontSizeFactor = 0.9; // Example: 90% of original

            return AlertDialog(
                title: const Text('Register New Patient'),
                contentPadding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0), // Adjust padding
                content: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * 0.85, // Slightly wider for more fields
                  height: MediaQuery.of(dialogContext).size.height * 0.75, // Potentially taller
                  child: _DialogPatientRegistrationForm( // UPDATED Widget name
                    bloodTypes: _dialogBloodTypes, // Pass blood types
                    onRegistered: (newPatient) {
                        Navigator.of(dialogContext).pop(newPatient);
                    },
                  ),
                ),
                actions: [
                    TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                ],
            );
        });

    if (result is Patient) {
      setState(() {
        _selectedPatient = result; 
        _patientSearchController.clear(); 
        _patientSearchResults = []; 
        _errorMessage = null; 
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New patient ${result.fullName} registered and selected.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result == true) { 
        await _fetchInitialFormData(); 
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Patient list refreshed after dialog action.'), backgroundColor: Colors.blue),
        );
    }
  }
}

// UPDATED: Dialog Patient Registration Form Widget using ReusablePatientFormFields
class _DialogPatientRegistrationForm extends StatefulWidget {
  final Function(Patient) onRegistered;
  final List<String> bloodTypes;

  const _DialogPatientRegistrationForm({required this.onRegistered, required this.bloodTypes});

  @override
  State<_DialogPatientRegistrationForm> createState() => _DialogPatientRegistrationFormState();
}

class _DialogPatientRegistrationFormState extends State<_DialogPatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  // All controllers for the full form
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _addressController = TextEditingController(); 
  final TextEditingController _emergencyContactNameController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _currentMedicationsController = TextEditingController();
  final TextEditingController _medicalInfoController = TextEditingController();
  
  String _gender = 'Male'; 
  String _bloodType = 'A+'; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.bloodTypes.isNotEmpty) {
      _bloodType = widget.bloodTypes.first; 
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactController.dispose();
    _allergiesController.dispose();
    _currentMedicationsController.dispose();
    _medicalInfoController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        if (_dobController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date of Birth is required.'), backgroundColor: Colors.red),
          );
          setState(() => _isSaving = false);
          return;
        }

        final newPatient = Patient(
          id: '', 
          fullName: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          birthDate: DateFormat('yyyy-MM-dd').parse(_dobController.text), 
          gender: _gender,
          contactNumber: _contactController.text.trim(),
          address: _addressController.text.trim(), 
          bloodType: _bloodType, 
          allergies: _allergiesController.text.trim(),
          // Adding data from new controllers
          // Patient model doesn't have direct fields for all of these, adjust as per your Patient model
          // For example, email, emergency contacts, medical history, current medications
          // might be part of a larger notes field or structured data if your Patient model supports it.
          // For now, I'll assume they map to existing optional fields or are for future expansion.
          // Ensure your Patient model can handle these or they are mapped appropriately.
          // email: _emailController.text.trim(), // If Patient model has email
          // emergencyContactName: _emergencyContactNameController.text.trim(), // if model supports
          // emergencyContactNumber: _emergencyContactController.text.trim(), // if model supports
          // medicalHistory: _medicalInfoController.text.trim(), // if model supports
          // currentMedications: _currentMedicationsController.text.trim(), // if model supports
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Assuming Patient model has been updated or these fields are optional / map to notes
        // Example: If patient has `otherMedicalInfo` field for notes
        // final otherInfo = "Medications: ${_currentMedicationsController.text.trim()}\nHistory: ${_medicalInfoController.text.trim()}";
        // final patientToSave = newPatient.copyWith(otherMedicalInfo: otherInfo);

        final patientId = await ApiService.createPatient(newPatient); // Pass newPatient or patientToSave
        final registeredPatient = newPatient.copyWith(id: patientId);
        
        widget.onRegistered(registeredPatient);

      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

 @override
  Widget build(BuildContext context) {
    // Define a custom TextTheme with smaller fonts for the dialog
    final originalTextTheme = Theme.of(context).textTheme;
    const double dialogFontSize = 12.5; // Smaller font size

    final dialogTextTheme = originalTextTheme.copyWith(
      bodyLarge: originalTextTheme.bodyLarge?.copyWith(fontSize: dialogFontSize),
      bodyMedium: originalTextTheme.bodyMedium?.copyWith(fontSize: dialogFontSize), // Input text style
      labelLarge: originalTextTheme.labelLarge?.copyWith(fontSize: dialogFontSize), // InputDecoration labelStyle
      titleMedium: originalTextTheme.titleMedium?.copyWith(fontSize: dialogFontSize + 1), // For Dropdown items if needed
    );

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Theme(
        data: Theme.of(context).copyWith(
          textTheme: dialogTextTheme,
          // Also adjust input decoration theme for smaller content padding if necessary
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            labelStyle: TextStyle(fontSize: dialogFontSize),            
            // Example: Reduce padding if fields look too tall with smaller font
            // contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            // isDense: true, 
          )
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0), // No padding for SingleChildScrollView itself
          child: Form(
            key: _formKey,
            child: Padding( // Add padding around the form content instead
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ReusablePatientFormFields(
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    dobController: _dobController,
                    contactController: _contactController,
                    emailController: _emailController,
                    addressController: _addressController, 
                    emergencyContactNameController: _emergencyContactNameController,
                    emergencyContactController: _emergencyContactController,
                    allergiesController: _allergiesController,
                    currentMedicationsController: _currentMedicationsController,
                    medicalInfoController: _medicalInfoController,
                    gender: _gender,
                    onGenderChanged: (value) {
                      if (value != null) setState(() => _gender = value);
                    },
                    bloodType: _bloodType,
                    onBloodTypeChanged: (value) {
                      if (value != null) setState(() => _bloodType = value);
                    },
                    bloodTypes: widget.bloodTypes, 
                    isEditMode: false, 
                    formType: FormType.full, // Use FormType.full to show all fields
                  ),
                  const SizedBox(height: 24),
                  _isSaving
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.app_registration),
                          label: const Text('Register Patient'),
                          onPressed: _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            textStyle: TextStyle(fontSize: dialogFontSize + 1, fontWeight: FontWeight.bold) // Adjust button font size too
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 