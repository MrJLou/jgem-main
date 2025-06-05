import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/appointment.dart';
import 'package:intl/intl.dart'; // For DateFormat.Hm()
import 'package:flutter_application_1/models/patient.dart'; // ADDED - Real Patient model
import 'package:flutter_application_1/models/user.dart'; // ADDED - For Doctor data (assuming doctors are Users)
import 'package:flutter_application_1/services/api_service.dart'; // ADDED
import 'package:flutter_application_1/services/queue_service.dart'; // ADDED
import 'package:flutter_application_1/screens/registration/patient_registration_screen.dart' show ReusablePatientFormFields, FormType; // Specific import
import 'dart:async'; // ADDED for Timer
import '../../models/clinic_service.dart'; // ADDED ClinicService import
// Assuming you have models for Patient and Doctor
// import 'package:flutter_application_1/models/patient.dart'; 
// import 'package:flutter_application_1/models/doctor.dart'; 
// import 'package:flutter_application_1/services/appointment_database_service.dart'; // Temporarily commented out
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
  late QueueService _queueService; // ADDED

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

  // UPDATED: Available services list - will be fetched from DB
  List<ClinicService> _availableServices = []; // Changed to List<ClinicService>
  List<ClinicService> _selectedServices = []; // Changed to List<ClinicService>
  Map<String, bool> _serviceSelectionState = {}; // To track selection in the dialog for ClinicService

  double _totalPrice = 0.0;
  final TextEditingController _otherPurposeController = TextEditingController(); // For "Other" purpose in service dialog
  bool _showOtherPurposeFieldInDialog = false; // To manage visibility of "Other" field in dialog

  final List<ConsultationType> _consultationTypes = [
    ConsultationType(name: 'Consultation', durationMinutes: 30),
    ConsultationType(name: 'Follow-up', durationMinutes: 15),
    ConsultationType(name: 'Procedure A', durationMinutes: 60),
  ];

  // Placeholder data - replace with actual data fetching
  // List<Patient> _patients = []; // CHANGED - Initialize as empty, to be fetched // REMOVED
  // List<User> _doctors = []; // CHANGED - Initialize as empty, to be fetched, assuming doctors are Users

  // Blood types for the mini registration form
  final List<String> _dialogBloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
  ];

  // Helper to convert TimeOfDay to minutes from midnight for easier comparison
  int _timeOfDayToMinutes(TimeOfDay tod) => tod.hour * 60 + tod.minute;

  // Helper to check if a day is selectable (not Sunday)
  bool _isSelectable(DateTime day) {
    return day.weekday != DateTime.sunday;
  }

  // ADDED: Helper to adjust time to the nearest valid slot
  TimeOfDay _adjustTimeToNearestSlot(TimeOfDay time) {
    final slots = _generateWorkingTimeSlots();
    if (slots.isEmpty) return time; // Should not happen

    final timeInMinutes = _timeOfDayToMinutes(time);

    // Find the first slot that is >= the given time
    for (final slot in slots) {
      if (_timeOfDayToMinutes(slot) >= timeInMinutes) {
        return slot;
      }
    }
    // If past all slots (e.g., time is after 4:30 PM for today), return the last slot
    return slots.last;
  }

  // ADDED: Helper to generate time slots
  List<TimeOfDay> _generateWorkingTimeSlots() {
    final List<TimeOfDay> slots = [];
    // TimeOfDay currentTime = const TimeOfDay(hour: 7, minute: 30); // Cannot be const
    // final endTime = const TimeOfDay(hour: 16, minute: 30); // Cannot be const

    // Refined loop for generating time slots
    slots.clear();
    int currentMinutes = 7 * 60 + 30; // 7:30 AM in minutes
    final endMinutes = 16 * 60 + 30;   // 4:30 PM in minutes

    while (currentMinutes <= endMinutes) {
      slots.add(TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60));
      currentMinutes += 30;
    }
    return slots;
  }

  @override
  void initState() {
    super.initState();
    _queueService = QueueService(); // ADDED: Initialize QueueService
    // IMPORTANT: Initialize DatabaseHelper and AppointmentDatabaseService properly.
    // No longer directly using _appointmentService here, will use ApiService
    print("AddAppointmentScreen: Using ApiService for data operations.");
    
    _fetchInitialFormData(); // ADDED - New method to fetch patients and doctors
    _fetchAvailableServices(); // ADDED: Fetch clinic services

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

    final nowDateTime = DateTime.now();
    final minWorkingTime = TimeOfDay(hour: 7, minute: 30);
    final maxWorkingTime = TimeOfDay(hour: 16, minute: 30);

    if (widget.selectedDate != null) {
      _selectedDate = widget.selectedDate!;
    } else {
       // If no date is passed, _selectedDate defaults to DateTime.now()
       // Ensure date is not Sunday for initial default, if it is, advance to Monday
      if (_selectedDate.weekday == DateTime.sunday) {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      }
    }
    
    // Adjust initial _selectedTime based on working hours and selected date
    if (!_isSelectable(_selectedDate)) { // If somehow current _selectedDate is Sunday (e.g. from widget.selectedDate)
        _selectedTime = minWorkingTime; // Default to start, validation will catch Sunday
    } else {
        TimeOfDay proposedTime;
        if (DateUtils.isSameDay(_selectedDate, nowDateTime)) { // If selected date is today
            proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
            if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) { 
                proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
            }

            if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(minWorkingTime)) {
                _selectedTime = minWorkingTime;
            } else if (_timeOfDayToMinutes(proposedTime) > _timeOfDayToMinutes(maxWorkingTime)) {
                _selectedTime = maxWorkingTime; // Clamp to end for today
            } else {
                _selectedTime = proposedTime;
            }
        } else { // If selected date is a future working day
            _selectedTime = minWorkingTime; // Default to start of working day
        }
        // Ensure _selectedTime is one of the generated slots, or the closest next one
        _selectedTime = _adjustTimeToNearestSlot(_selectedTime);
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

  // ADDED: Method to fetch available clinic services
  Future<void> _fetchAvailableServices() async {
    try {
      final services = await ApiService.getAllClinicServices();
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
            content: Text('Failed to load services for appointment screen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error fetching available services for appointment screen: $e');
    }
  }

  void _clearForm() { // RE-ADDED
    setState(() {
      _selectedPatient = null;
      _selectedDoctor = null;
      _selectedConsultationType = _consultationTypes.isNotEmpty ? _consultationTypes.first : null;
      final nowDateTime = DateTime.now();
      _selectedDate = widget.selectedDate ?? nowDateTime;
      
      if (!_isSelectable(_selectedDate)) { 
         _selectedDate = _selectedDate.add(Duration(days: DateTime.monday - _selectedDate.weekday));
         if(_selectedDate.isBefore(nowDateTime) && !DateUtils.isSameDay(_selectedDate, nowDateTime)) { 
            _selectedDate = _selectedDate.add(const Duration(days: 7));
         }
      }
      
      final minWorkingTime = TimeOfDay(hour: 7, minute: 30);
      // final maxWorkingTime = TimeOfDay(hour: 16, minute: 30); // No longer directly used here for clamping

      if (DateUtils.isSameDay(_selectedDate, nowDateTime)) {
          TimeOfDay proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
          if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) {
             proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
          }
         _selectedTime = _adjustTimeToNearestSlot(proposedTime);
      } else { 
          _selectedTime = minWorkingTime; // Default to the first slot
      }

      _notesController.clear();
      _patientSearchController.clear(); // ADDED
      _patientSearchResults = []; // ADDED
      // _doctorSearchController.clear(); // REMOVED
      // _doctorSearchResults = []; // REMOVED
      _errorMessage = null;
      _formKey.currentState?.reset(); // Also reset form validation state

      // UPDATED: Clear service selection state for ClinicService
      _selectedServices.clear();
      _serviceSelectionState = { 
            for (var service in _availableServices) service.id: false
      };
      _totalPrice = 0.0;
      _otherPurposeController.clear();
      _showOtherPurposeFieldInDialog = false;
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
        // Patient conflict check removed as per previous user instructions implicitly by focusing on doctor conflicts.
        // Re-add if necessary:
        // if (existing.patientId == patientId) {
        //   return "Patient Conflict: Patient $patientId is booked from ${DateFormat.Hm().format(existingApptStart)} to ${DateFormat.Hm().format(existingApptEnd)}.";
        // }
      }
    }
    return null; // No conflict
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    DateTime initialPickerDate = _selectedDate;
    if (initialPickerDate.isBefore(now) && !DateUtils.isSameDay(initialPickerDate, now)) {
      initialPickerDate = now;
    }
    if (!_isSelectable(initialPickerDate)) { // If current initial is Sunday, start picker on Monday
        initialPickerDate = initialPickerDate.add(Duration(days: DateTime.monday - initialPickerDate.weekday));
        if(initialPickerDate.isBefore(now) && !DateUtils.isSameDay(initialPickerDate, now)) {
            initialPickerDate = initialPickerDate.add(const Duration(days: 7));
        }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialPickerDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: _isSelectable, // Disable Sundays
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Adjust time if date changed
        final minWorkingTime = TimeOfDay(hour: 7, minute: 30);
        final maxWorkingTime = TimeOfDay(hour: 16, minute: 30);
        final nowDateTime = DateTime.now();

        if (DateUtils.isSameDay(_selectedDate, nowDateTime)) {
            TimeOfDay proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
            if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) {
               proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
            }
            if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(minWorkingTime)) {
                _selectedTime = minWorkingTime;
            } else if (_timeOfDayToMinutes(proposedTime) > _timeOfDayToMinutes(maxWorkingTime)) {
                _selectedTime = maxWorkingTime;
            } else {
                _selectedTime = proposedTime;
            }
        } else { // Future working day
            _selectedTime = minWorkingTime; // Default to start of working day
        }
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
      final DateTime appointmentStartDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      if (appointmentStartDateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
        setState(() { _errorMessage = 'Cannot schedule appointments for past dates or times.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
      // --- End Past Date/Time Check ---

      // --- Working Hours and Day Validation ---
      if (!_isSelectable(_selectedDate)) { // Check for Sunday
        setState(() { _errorMessage = 'Appointments cannot be scheduled on Sundays.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      final DateTime workDayStartBoundary = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 7, 30);
      final DateTime workDayEndBoundary = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 16, 30);
      final DateTime appointmentEndDateTime = appointmentStartDateTime.add(Duration(minutes: _selectedConsultationType!.durationMinutes));

      if (appointmentStartDateTime.isBefore(workDayStartBoundary)) {
        setState(() { _errorMessage = 'Appointments must start on or after 7:30 AM.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      if (appointmentEndDateTime.isAfter(workDayEndBoundary)) {
        setState(() { _errorMessage = 'Appointments must end by 4:30 PM. Selected time or duration is too late.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error, duration: Duration(seconds: 4),));
        return;
      }
      // --- End Working Hours and Day Validation ---

      if (_selectedPatient != null) {
        bool isPatientInActiveQueueToday = await _queueService.isPatientCurrentlyActive(
          patientId: _selectedPatient!.id,
          patientName: _selectedPatient!.fullName,
        );
        if (isPatientInActiveQueueToday) {
          setState(() {
            _errorMessage = 'This patient (${_selectedPatient!.fullName}) is already in the active queue for today. Cannot schedule another appointment while they are actively in queue.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error, duration: const Duration(seconds: 5))
          );
          return;
        }
      }

      String? conflictMessage = _getConflictMessage(
          _selectedDoctor!.id,
          _selectedPatient!.id,
          _selectedDate,
          _selectedTime,
          _selectedConsultationType!.durationMinutes
      );
      if (conflictMessage != null) {
        setState(() { _errorMessage = conflictMessage; });
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      setState(() { _isLoading = true; _errorMessage = null; });

      try {
        // String currentUserId = 'user_placeholder_id'; // Not used it seems
        final List<Map<String, dynamic>> servicesToStore = _selectedServices.map((service) => {
          'id': service.id, // Store ID
          'name': service.serviceName,
          'category': service.category ?? 'Uncategorized',
          'price': service.defaultPrice ?? 0.0,
          // No need to store selectionCount from ClinicService model here for the appointment itself
        }).toList();
        // String combinedNotes = ""; // This logic for combinedNotes seems to be missing its usage
        // if (_otherPurposeController.text.trim().isNotEmpty) {
        //   combinedNotes = "Other Purpose/Details: ${_otherPurposeController.text.trim()}";
        // }

        Appointment newAppointment = Appointment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: _selectedPatient!.id,
          date: _selectedDate,
          time: _selectedTime,
          doctorId: _selectedDoctor!.id,
          consultationType: _selectedConsultationType!.name,
          durationMinutes: _selectedConsultationType!.durationMinutes,
          status: 'Scheduled',
          createdAt: DateTime.now(),
          selectedServices: servicesToStore.isNotEmpty ? servicesToStore : null,
          totalPrice: _totalPrice > 0 ? _totalPrice : null,
          paymentStatus: 'Pending',
        );
        
        widget.onAppointmentSaved?.call(newAppointment);
        _clearForm();
        
      } catch (e) {
        if (mounted) {
          setState(() { _errorMessage = 'Failed to save appointment: ${e.toString()}'; });
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false); }
      } else {
        setState(() { _errorMessage = 'Please fill all required fields correctly.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
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

    @override
    void dispose() {
      _notesController.dispose();
      _patientSearchController.dispose(); 
      _patientSearchDebounce?.cancel(); 
      _otherPurposeController.dispose(); // ADDED
      super.dispose();
    }
    
    @override
    void didUpdateWidget(covariant AddAppointmentScreen oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (widget.selectedDate != null && widget.selectedDate != _selectedDate) {
        setState(() {
          _selectedDate = widget.selectedDate!;
          if (!_isSelectable(_selectedDate)) { // If new date is Sunday
              // Optionally, show a message or automatically shift to Monday
              // For now, _submitForm will catch this.
              // Or, adjust _selectedDate to next working day if desired policy.
          }
          // Adjust time based on the new date and working hours
          final minWorkingTime = TimeOfDay(hour: 7, minute: 30);
          final maxWorkingTime = TimeOfDay(hour: 16, minute: 30);
          final nowDateTime = DateTime.now();

          if (_isSelectable(_selectedDate)) {
              if (DateUtils.isSameDay(_selectedDate, nowDateTime)) {
                  TimeOfDay proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
                  if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) {
                     proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
                  }

                  if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(minWorkingTime)) {
                      _selectedTime = minWorkingTime;
                  } else if (_timeOfDayToMinutes(proposedTime) > _timeOfDayToMinutes(maxWorkingTime)) {
                      _selectedTime = maxWorkingTime;
                  } else {
                      _selectedTime = proposedTime;
                  }
              } else { // Future working day
                  _selectedTime = minWorkingTime;
              }
          } else { // It's a Sunday
              _selectedTime = minWorkingTime; // Default, submit validation will catch
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
                      isExpanded: true, 
                      selectedItemBuilder: (BuildContext context) { 
                        return _doctors.map<Widget>((User doctor) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 0.0), 
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
                            overflow: TextOverflow.ellipsis, 
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

                    // MODIFIED: Time selection using DropdownButtonFormField
                    DropdownButtonFormField<TimeOfDay>(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        prefixIcon: const Icon(Icons.access_time_outlined, color: Colors.teal),
                      ),
                      value: _selectedTime,
                      hint: const Text('Select Time'),
                      items: _generateWorkingTimeSlots().map((TimeOfDay time) {
                        return DropdownMenuItem<TimeOfDay>(
                          value: time,
                          child: Text(time.format(context)),
                        );
                      }).toList(),
                      onChanged: (TimeOfDay? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTime = newValue;
                          });
                        }
                      },
                      validator: (value) => value == null ? 'Please select a time' : null,
                    ),
                    const SizedBox(height: 16),

                    // ADDED: Service Selection UI elements
                    Text('Services / Purpose of Visit',
                        style: TextStyle(
                            fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[700])),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.medical_services_outlined, color: Colors.teal),
                      label: Text('Select Services / Specify Purpose', style: TextStyle(color: Colors.teal[700])),
                      onPressed: _openServiceSelectionDialog, // To be implemented
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[50],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: const TextStyle(fontSize: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            side: BorderSide(color: Colors.teal.withOpacity(0.5))
                          )
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_selectedServices.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _selectedServices
                            .map((service) => Chip(
                                  avatar: Icon(Icons.check_circle_outline, size: 16, color: Colors.teal[700]),
                                  label: Text(
                                      '${service.serviceName} (₱${(service.defaultPrice ?? 0.0).toStringAsFixed(2)})'),
                                  backgroundColor: Colors.teal[100],
                                  labelStyle: TextStyle(color: Colors.teal[800], fontSize: 13),
                                  deleteIcon: Icon(Icons.cancel, size: 16, color: Colors.teal[600]),
                                  onDeleted: () {
                                    setState(() {
                                      _serviceSelectionState[service.id] = false; // Update selection state map
                                      _selectedServices.removeWhere((s) => s.id == service.id); // Remove by ID
                                      _totalPrice = _selectedServices.fold(0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    if (_otherPurposeController.text.isNotEmpty) // Display if "Other" purpose was filled
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                            "Other Purpose: ${_otherPurposeController.text}",
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700], fontSize: 13)),
                      ),
                    if (_selectedServices.isNotEmpty || _otherPurposeController.text.isNotEmpty)
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
                    const SizedBox(height: 16),
                    // END ADDED: Service Selection UI elements

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

  // ADDED: Service Selection Dialog (adapted from add_to_queue_screen.dart)
  void _openServiceSelectionDialog() {
    // Use a temporary map to manage selections within the dialog for ClinicService
    Map<String, bool> currentDialogSelectionState = Map.from(_serviceSelectionState);
    
    TextEditingController dialogOtherController = TextEditingController(text: _otherPurposeController.text);
    bool currentShowOtherField = _showOtherPurposeFieldInDialog;

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
              (groupedServices[service.category ?? 'Uncategorized'] ??= []).add(service);
            }
            List<String> categoryOrder = ['Consultation', 'Laboratory']; 
            List<String> allCategories = groupedServices.keys.toList();
            categoryOrder.addAll(allCategories.where((cat) => !categoryOrder.contains(cat) && cat != 'Uncategorized'));
            if (groupedServices.containsKey('Uncategorized')) {
                categoryOrder.add('Uncategorized'); // Add Uncategorized at the end if it exists
            }

            return AlertDialog(
              title: const Text('Select Services / Purpose of Visit'),
              contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    if (_availableServices.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No services loaded. Check connection or add services in settings."),
                      )),
                    ...categoryOrder.where((cat) => groupedServices.containsKey(cat)).expand((category) => [
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                        child: Text(category, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700], fontSize: 16)),
                      ),
                      ...groupedServices[category]!.map((service) => CheckboxListTile(
                            title: Text(
                                '${service.serviceName} (₱${NumberFormat("#,##0.00", "en_US").format(service.defaultPrice ?? 0.0)})',
                                style: const TextStyle(fontSize: 14)),
                            value: currentDialogSelectionState[service.id] ?? false,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                currentDialogSelectionState[service.id] = value!;
                                currentDialogPrice = _availableServices
                                    .where((s) => currentDialogSelectionState[s.id] == true)
                                    .fold(0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));
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
                          controller: dialogOtherController,
                          decoration: const InputDecoration(
                              labelText: 'Specify other purpose or details',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Annual Check-up, Pre-employment',
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
                      _serviceSelectionState = Map.from(currentDialogSelectionState);
                      _selectedServices = _availableServices.where((s) => _serviceSelectionState[s.id] == true).toList();
                      _totalPrice = _selectedServices.fold(0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));
                      _showOtherPurposeFieldInDialog = currentShowOtherField;
                      if (currentShowOtherField) {
                        _otherPurposeController.text = dialogOtherController.text.trim();
                      } else {
                        _otherPurposeController.clear();
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
}

// UPDATED: Dialog Patient Registration Form Widget using ReusablePatientFormFields
class _DialogPatientRegistrationForm extends StatefulWidget {
  final Function(Patient) onRegistered;
  final List<String> bloodTypes;

  const _DialogPatientRegistrationForm({super.key, required this.onRegistered, required this.bloodTypes});

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
          if (mounted) { // Check if widget is still in the tree
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Date of Birth is required.'), backgroundColor: Colors.red),
            );
          }
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
          // Ensure your Patient model can handle these or they are mapped appropriately.
          // For example, if Patient model has 'email', 'emergencyContactName', etc.
          // email: _emailController.text.trim(), 
          // emergencyContactName: _emergencyContactNameController.text.trim(),
          // emergencyContactNumber: _emergencyContactController.text.trim(),
          // medicalHistory: _medicalInfoController.text.trim(),
          // currentMedications: _currentMedicationsController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final patientId = await ApiService.createPatient(newPatient);
        final registeredPatient = newPatient.copyWith(id: patientId);
        
        widget.onRegistered(registeredPatient);

      } catch (e) {
        if (mounted) { // Check if widget is still in the tree
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) { // Check if widget is still in the tree
          setState(() => _isSaving = false);
        }
      }
    }
  }

 @override
  Widget build(BuildContext context) {
    final originalTextTheme = Theme.of(context).textTheme;
    const double dialogFontSize = 12.5; 

    final dialogTextTheme = originalTextTheme.copyWith(
      bodyLarge: originalTextTheme.bodyLarge?.copyWith(fontSize: dialogFontSize),
      bodyMedium: originalTextTheme.bodyMedium?.copyWith(fontSize: dialogFontSize), 
      labelLarge: originalTextTheme.labelLarge?.copyWith(fontSize: dialogFontSize), 
      titleMedium: originalTextTheme.titleMedium?.copyWith(fontSize: dialogFontSize + 1), 
    );

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Theme(
        data: Theme.of(context).copyWith(
          textTheme: dialogTextTheme,
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            labelStyle: TextStyle(fontSize: dialogFontSize),            
          )
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0), 
          child: Form(
            key: _formKey,
            child: Padding( 
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
                    formType: FormType.full,
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
                            textStyle: TextStyle(fontSize: dialogFontSize + 1, fontWeight: FontWeight.bold) 
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