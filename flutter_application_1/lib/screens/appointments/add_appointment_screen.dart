import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/appointment.dart';
import 'package:intl/intl.dart'; // For DateFormat.Hm()
import 'package:flutter_application_1/models/patient.dart'; // ADDED - Real Patient model
import 'package:flutter_application_1/models/user.dart'; // ADDED - For Doctor data (assuming doctors are Users)
import 'package:flutter_application_1/services/api_service.dart'; // ADDED
import 'package:flutter_application_1/screens/registration/patient_registration_screen.dart'
    show ReusablePatientFormFields, FormType; // Specific import
import 'dart:async'; // ADDED for Timer
import '../../models/clinic_service.dart'; // ADDED ClinicService import
// Legacy time slot imports removed - using simple work schedule system

class AddAppointmentScreen extends StatefulWidget {
  final List<Appointment>? existingAppointments;
  final Function(Appointment)? onAppointmentAdded;
  final DateTime? initialDate;
  final Patient? patient;
  final bool isDialog;

  const AddAppointmentScreen({
    super.key,
    this.existingAppointments,
    this.onAppointmentAdded,
    this.initialDate,
    this.patient,
    this.isDialog = false,
  });

  @override
  AddAppointmentScreenState createState() => AddAppointmentScreenState();
}

class AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state
  Patient? _selectedPatient;
  User? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _notesController = TextEditingController();
  
  // Added fields for patient form
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();
  String _civilStatus = 'Single';
  bool _isSeniorCitizen = false;
  final List<String> _civilStatusOptions = [
    'Single', 'Married', 'Widowed', 'Separated', 'Divorced'
  ];

  // Search state variables
  final TextEditingController _patientSearchController =
      TextEditingController();
  List<Patient> _patientSearchResults = [];
  bool _isSearchingPatient = false;
  Timer? _patientSearchDebounce;

  List<User> _doctors = [];

  bool _isLoading = false;
  String? _errorMessage;
  // Available services list
  List<ClinicService> _availableServices = [];
  List<ClinicService> _selectedServices = [];
  Map<String, bool> _serviceSelectionState = {};
  double _totalPrice = 0.0;
  bool _isLaboratoryOnly = false; // NEW: For laboratory appointments without doctor

  // Removed complex time slot management - using simple work schedule validation

  final List<String> _dialogBloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown'
  ];

  int _timeOfDayToMinutes(TimeOfDay tod) => tod.hour * 60 + tod.minute;

  bool _isSelectable(DateTime day) {
    // Disallow selection of dates in the past and Sundays.
    if (day.isBefore(DateUtils.dateOnly(DateTime.now()))) {
      return false;
    }
    return day.weekday != DateTime.sunday;
  }

  TimeOfDay _adjustTimeToNearestSlot(TimeOfDay time) {
    final slots = _generateWorkingTimeSlots();
    if (slots.isEmpty) return time;

    final timeInMinutes = _timeOfDayToMinutes(time);

    for (final slot in slots) {
      if (_timeOfDayToMinutes(slot) >= timeInMinutes) {
        return slot;
      }
    }
    return slots.last;
  }

  List<TimeOfDay> _generateWorkingTimeSlots() {
    final List<TimeOfDay> slots = [];
    slots.clear();
    int currentMinutes = 7 * 60 + 30; // 7:30 AM
    const endMinutes = 16 * 60 + 30; // 4:30 PM

    while (currentMinutes <= endMinutes) {
      slots.add(
          TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60));
      currentMinutes += 30;
    }
    return slots;
  }

  List<TimeOfDay> _generateSelectableTimeSlots() {
    final workingSlots = _generateWorkingTimeSlots();
    if (_selectedDoctor == null) {
      return workingSlots;
    }

    // Determine booked time slots for the selected doctor and date
    // Exclude cancelled appointments to make those timeslots available again
    final Set<TimeOfDay> bookedTimes = (widget.existingAppointments ?? [])
        .where((appt) =>
            appt.doctorId == _selectedDoctor!.id &&
            DateUtils.isSameDay(appt.date, _selectedDate) &&
            appt.status.toLowerCase().trim() != 'cancelled')
        .map((appt) => appt.time)
        .toSet();

    debugPrint(
        'AddAppointmentScreen: Booked times after filtering cancelled: ${bookedTimes.map((t) => t.format(context)).join(', ')}');

    return workingSlots.where((slot) => !bookedTimes.contains(slot)).toList();
  }

  @override
  void initState() {
    super.initState();
    debugPrint("AddAppointmentScreen: Using ApiService for data operations.");

    if (widget.patient != null) {
      _selectedPatient = widget.patient;
      _patientSearchController.text = widget.patient!.fullName;
    }

    _fetchInitialFormData();
    _fetchAvailableServices();

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
      final now = DateTime.now();
      if (DateUtils.isSameDay(_selectedDate, now) &&
          (_selectedTime.hour < now.hour ||
              (_selectedTime.hour == now.hour &&
                  _selectedTime.minute < now.minute))) {
        _selectedTime =
            TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
      }
    } else {
      final now = DateTime.now();
      if (DateUtils.isSameDay(_selectedDate, now) &&
          (_selectedTime.hour < now.hour ||
              (_selectedTime.hour == now.hour &&
                  _selectedTime.minute < now.minute))) {
        _selectedTime =
            TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
      }
    }

    final nowDateTime = DateTime.now();
    const minWorkingTime = TimeOfDay(hour: 7, minute: 30);
    const maxWorkingTime = TimeOfDay(hour: 16, minute: 30);

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    } else {
      if (_selectedDate.weekday == DateTime.sunday) {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      }
    }

    if (!_isSelectable(_selectedDate)) {
      _selectedTime = minWorkingTime;
    } else {
      TimeOfDay proposedTime;
      if (DateUtils.isSameDay(_selectedDate, nowDateTime)) {
        proposedTime =
            TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
        if (_timeOfDayToMinutes(proposedTime) <
            _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) {
          proposedTime = TimeOfDay.fromDateTime(
              nowDateTime.add(const Duration(minutes: 5)));
        }

        if (_timeOfDayToMinutes(proposedTime) <
            _timeOfDayToMinutes(minWorkingTime)) {
          _selectedTime = minWorkingTime;
        } else if (_timeOfDayToMinutes(proposedTime) >
            _timeOfDayToMinutes(maxWorkingTime)) {
          _selectedTime = maxWorkingTime;
        } else {
          _selectedTime = proposedTime;
        }
      } else {
        _selectedTime = minWorkingTime;
      }
      _selectedTime = _adjustTimeToNearestSlot(_selectedTime);
    }
  }

  Future<void> _fetchInitialFormData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _patientSearchResults = [];
    });
    try {
      final allUsers = await ApiService.getUsers();
      if (!mounted) return;
      
      final doctorUsers = allUsers.where((user) => user.role.toLowerCase() == 'doctor').toList();
      debugPrint('AddAppointmentScreen: Found ${doctorUsers.length} doctors: ${doctorUsers.map((d) => d.fullName).join(', ')}');
      
      setState(() {
        _doctors = doctorUsers;
      });
      
      debugPrint('AddAppointmentScreen: Doctor list set with ${_doctors.length} doctors - all available for selection');
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load patient/doctor list: ${e.toString()}";
      });
      debugPrint('AddAppointmentScreen: Error loading doctors: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  Future<void> _updateAvailableDoctorsForDate() async {
    // Allow all doctors to be selectable regardless of schedule
    // This provides flexibility for users to select doctors they've spoken to
    debugPrint('AddAppointmentScreen: All doctors available for selection - schedule validation disabled for flexibility');
  }



  Future<void> _fetchAvailableServices() async {
    try {
      final services = await ApiService.getClinicServices();
      if (!mounted) return;
      setState(() {
        _availableServices = services;
        _serviceSelectionState = {
          for (var service in _availableServices) service.id: false
        };
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load services for appointment screen: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint(
          'Error fetching available services for appointment screen: $e');
    }
  }

  void _clearForm() {
    setState(() {
      _selectedPatient = null;
      _selectedDoctor = null;
      final nowDateTime = DateTime.now();
      _selectedDate = widget.initialDate ?? nowDateTime;

      if (!_isSelectable(_selectedDate)) {
        _selectedDate = _selectedDate
            .add(Duration(days: DateTime.monday - _selectedDate.weekday));
        if (_selectedDate.isBefore(nowDateTime) &&
            !DateUtils.isSameDay(_selectedDate, nowDateTime)) {
          _selectedDate = _selectedDate.add(const Duration(days: 7));
        }
      }

      const minWorkingTime = TimeOfDay(hour: 7, minute: 30);

      if (DateUtils.isSameDay(_selectedDate, nowDateTime)) {
        TimeOfDay proposedTime =
            TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
        if (_timeOfDayToMinutes(proposedTime) <
            _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) {
          proposedTime = TimeOfDay.fromDateTime(
              nowDateTime.add(const Duration(minutes: 5)));
        }
        _selectedTime = _adjustTimeToNearestSlot(proposedTime);
      } else {
        _selectedTime = minWorkingTime;
      }

      _notesController.clear();
      _patientSearchController.clear();
      _patientSearchResults = [];
      _errorMessage = null;
      _formKey.currentState?.reset();      
      _selectedServices.clear();
      _serviceSelectionState = {
        for (var service in _availableServices) service.id: false
      };
      _totalPrice = 0.0;
      _isLaboratoryOnly = false; // Reset laboratory checkbox
    });
  }

  void _onPatientSearchChanged(String query) {
    if (_patientSearchDebounce?.isActive ?? false) {
      _patientSearchDebounce!.cancel();
    }
    _patientSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _isSearchingPatient = true;
          _patientSearchResults = [];
        });
        try {
          final results = await ApiService.searchPatients(query);
          if (!mounted) return;
          setState(() {
            _patientSearchResults = results;
          });
        } catch (e) {
          if (!mounted) return;
          debugPrint("Patient search error: $e");
        } finally {
          if (mounted) {
            setState(() {
              _isSearchingPatient = false;
            });
          }
        }
      } else {
        if (!mounted) return;
        setState(() {
          _patientSearchResults = [];
        });
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());

    // Ensure initialPickerDate is a valid selectable date
    DateTime initialPickerDate =
        _selectedDate.isBefore(today) ? today : _selectedDate;

    // If the initial date is not selectable (e.g., Sunday), find the next selectable date
    while (!_isSelectable(initialPickerDate)) {
      initialPickerDate = initialPickerDate.add(const Duration(days: 1));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialPickerDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: _isSelectable,
    );
    if (!mounted) return;
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Update available doctors when date changes
      await _updateAvailableDoctorsForDate();
    }
  }
  Future<void> _showTimePicker() async {
    if (_selectedDoctor == null && !_isLaboratoryOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor first or check "Laboratory Tests Only" to see available time slots.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Simple time slot selection - no complex time slot system
    final List<TimeOfDay> timeSlots = _isLaboratoryOnly 
        ? _generateWorkingTimeSlots() // For lab-only, show all working hours
        : _generateSelectableTimeSlots(); // For doctor appointments, check conflicts
        
    if (timeSlots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No available time slots for this day.')));
      return;
    }

    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) {
        final relevantAppointments = _isLaboratoryOnly 
            ? <Appointment>[] // No conflicts for lab-only appointments
            : (widget.existingAppointments ?? [])
                .where((appt) =>
                    appt.doctorId == _selectedDoctor!.id &&
                    DateUtils.isSameDay(appt.date, _selectedDate))
                .toList();

        if (_selectedDoctor != null) {
          debugPrint(
              'AddAppointmentScreen: Found ${relevantAppointments.length} existing appointments for doctor ${_selectedDoctor!.id} on ${_selectedDate.toString().split(' ')[0]}');
          for (final appt in relevantAppointments) {
            debugPrint(
                '  - Appointment ${appt.id}: ${appt.time.format(context)} - Status: "${appt.status}" (${appt.status.toLowerCase().trim() == 'cancelled' ? 'FILTERED OUT' : 'BLOCKING SLOT'})');
          }
        } else {
          debugPrint(
              'AddAppointmentScreen: Laboratory-only appointment - no doctor conflicts to check');
        }

        return AlertDialog(
          title: const Text('Select Time'),
          contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: timeSlots.map((time) {
                    final isBooked = _selectedDoctor != null && (widget.existingAppointments ?? []).any(
                        (bookedTime) =>
                            bookedTime.doctorId == _selectedDoctor!.id &&
                            DateUtils.isSameDay(
                                bookedTime.date, _selectedDate) &&
                            bookedTime.status.toLowerCase().trim() !=
                                'cancelled' &&
                            bookedTime.time.hour == time.hour &&
                            bookedTime.time.minute == time.minute);

                    final now = DateTime.now();
                    final isPast = DateUtils.isSameDay(_selectedDate, now) &&
                        (time.hour < now.hour ||
                            (time.hour == now.hour &&
                                time.minute < now.minute));

                    return SizedBox(
                      width: 100, // Fixed width for buttons
                      child: ElevatedButton(
                        onPressed: isBooked || isPast
                            ? null
                            : () {
                                Navigator.of(context).pop(time);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBooked
                              ? Colors.red[300]
                              : isPast
                                  ? Colors.grey[400]
                                  : Colors.teal[50],
                          disabledBackgroundColor:
                              isBooked ? Colors.red[200] : Colors.grey[300],
                          foregroundColor: isBooked
                              ? Colors.white
                              : isPast
                                  ? Colors.white70
                                  : Colors.teal[800],
                          disabledForegroundColor: Colors.white.withAlpha(50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: Text(time.format(context)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  Future<void> _openServiceSelectionDialog() async {
    final tempSelections = Map<String, bool>.from(_serviceSelectionState);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentDialogPrice = _availableServices
                .where((s) => tempSelections[s.id] == true)
                .fold(0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));

            Map<String, List<ClinicService>> groupedServices = {};
            for (var service in _availableServices) {
              (groupedServices[service.category ?? 'Uncategorized'] ??= [])
                  .add(service);
            }
            
            // Ensure 'Laboratory' appears first if _isLaboratoryOnly is checked, otherwise 'Consultation' first
            List<String> categoryOrder = _isLaboratoryOnly 
                ? ['Laboratory', 'Consultation'] 
                : ['Consultation', 'Laboratory'];
            List<String> allCategories = groupedServices.keys.toList();
            categoryOrder.addAll(
                allCategories.where((cat) => !categoryOrder.contains(cat)));

            return AlertDialog(
              title: Text(_isLaboratoryOnly 
                  ? 'Select Laboratory Tests' 
                  : 'Select Services / Purpose of Visit'),
              contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    if (_isLaboratoryOnly)
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Laboratory Tests Only mode - No doctor consultation required',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                    value: tempSelections[service.id] ?? false,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        tempSelections[service.id] = value!;
                                        currentDialogPrice = _availableServices
                                            .where((s) =>
                                                tempSelections[s.id] == true)
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
                                  )),
                              const Divider(),
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
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).pop({
                      'selections': tempSelections,
                    });
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _serviceSelectionState = result['selections'];
        _selectedServices = _availableServices
            .where((service) => _serviceSelectionState[service.id] == true)
            .toList();

        _recalculateTotalPrice();
      });
    }
  }

  Future<void> _showPatientRegistrationDialog() async {
    final newPatient = await showDialog<Patient>(
      context: context,
      builder: (BuildContext context) {
        final formKey = GlobalKey<FormState>();
        final firstNameController = TextEditingController();
        final lastNameController = TextEditingController();
        final dobController = TextEditingController();
        final contactController = TextEditingController();
        final addressController = TextEditingController();
        final allergiesController = TextEditingController();
        String selectedGender = 'Male';
        String selectedBloodType = 'A+';
        bool unknownBloodType = false;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              child: Material(
                child: Container(
                  width: MediaQuery.of(context).size.width *
                      0.7, // Make dialog wider
                  height: MediaQuery.of(context).size.height *
                      0.8, // Make dialog taller
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Register New Patient',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800],
                                ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            child: ReusablePatientFormFields(
                              formType: FormType.mini,
                              firstNameController: firstNameController,
                              lastNameController: lastNameController,
                              middleNameController: _middleNameController,
                              suffixController: _suffixController,
                              dobController: dobController,
                              contactController: contactController,
                              addressController: addressController,
                              allergiesController: allergiesController,
                              gender: selectedGender,
                              onGenderChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedGender = value;
                                  });
                                }
                              },
                              bloodType: selectedBloodType,
                              onBloodTypeChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedBloodType = value;
                                  });
                                }
                              },
                              bloodTypes: _dialogBloodTypes,
                              isEditMode: false,
                              unknownBloodType: unknownBloodType,
                              onUnknownBloodTypeChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    unknownBloodType = value;
                                    if (value) {
                                      selectedBloodType = 'Unknown';
                                    } else if (selectedBloodType == 'Unknown') {
                                      selectedBloodType = 'A+'; // Default if unchecking "Unknown"
                                    }
                                  });
                                }
                              },
                              civilStatus: _civilStatus,
                              onCivilStatusChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _civilStatus = value;
                                  });
                                }
                              },
                              isSeniorCitizen: _isSeniorCitizen,
                              onSeniorCitizenChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _isSeniorCitizen = value;
                                  });
                                }
                              },
                              civilStatusOptions: _civilStatusOptions,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setState(() {
                                        isLoading = true;
                                      });

                                      final now = DateTime.now();
                                      Patient patientToSave = Patient(
                                        id: 'temp_${now.millisecondsSinceEpoch}',
                                        fullName:
                                            '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
                                        birthDate: DateFormat('yyyy-MM-dd')
                                            .parse(dobController.text),
                                        gender: selectedGender,
                                        contactNumber:
                                            contactController.text.trim(),
                                        address: addressController.text.trim(),
                                        bloodType: selectedBloodType,
                                        allergies:
                                            allergiesController.text.trim(),
                                        createdAt: now,
                                        updatedAt: now,
                                        registrationDate: now,
                                      );

                                      try {
                                        final newPatientId =
                                            await ApiService.createPatient(
                                                patientToSave);
                                        final savedPatient = patientToSave
                                            .copyWith(id: newPatientId);

                                        if (!context.mounted) return;
                                        Navigator.of(context).pop(savedPatient);
                                      } catch (e) {
                                        debugPrint(
                                            "Error saving new patient from dialog: $e");
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Failed to save patient: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } finally {
                                        setState(() {
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Save Patient',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (newPatient != null) {
      setState(() {
        _selectedPatient = newPatient;
        _patientSearchController.text = newPatient.fullName;
        _patientSearchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Patient \'${newPatient.fullName}\' has been successfully registered.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatient == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a patient.')));
        return;
      }      if (_selectedDoctor == null && !_isLaboratoryOnly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a doctor or check "Laboratory Tests Only".')));
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });      // Check for scheduling conflicts before submission (only if doctor is selected)
      if (!_isLaboratoryOnly) {
        bool hasConflict = (widget.existingAppointments ?? []).any((appt) {
          if (appt.status == 'Cancelled' ||
              appt.doctorId != _selectedDoctor!.id) {
            return false;
          }
          return DateUtils.isSameDay(appt.date, _selectedDate) &&
              appt.time.hour == _selectedTime.hour &&
              appt.time.minute == _selectedTime.minute;
        });

        if (hasConflict) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'This time slot is already booked with the selected doctor.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }

        // Allow appointment booking without schedule validation for flexibility
        debugPrint('AddAppointmentScreen: Skipping doctor schedule validation for flexible appointment booking');
      }

      try {
        List<Map<String, dynamic>> servicesForDb = _selectedServices
            .map((s) => {
                  'id': s.id,
                  'name': s.serviceName,
                  'category': s.category,
                  'price': s.defaultPrice
                })
            .toList();        final appointmentToSave = Appointment(
          id: '', // Empty string to let the database generate the ID
          patientId: _selectedPatient!.id,
          doctorId: _isLaboratoryOnly ? 'LAB-ONLY' : _selectedDoctor!.id,
          date: _selectedDate,
          time: _selectedTime,
          status: 'Scheduled',
          consultationType: _isLaboratoryOnly 
            ? 'Laboratory Tests Only'
            : (_selectedServices.isNotEmpty
                ? _selectedServices.map((s) => s.category).toSet().join('/')
                : 'General Consultation'),
          selectedServices: servicesForDb,
          totalPrice: _totalPrice,
          createdAt: DateTime.now(),
          isWalkIn: false,
          notes: _notesController.text.trim(),
        );

        // Save the appointment and get it back with the generated ID
        final savedAppointment =
            await ApiService.saveAppointment(appointmentToSave);

        // Simplified system - no complex time slot booking needed

        // Notify parent about the new appointment
        if (widget.onAppointmentAdded != null) {
          widget.onAppointmentAdded!(savedAppointment);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Appointment saved successfully!'),
              backgroundColor: Colors.green),
        );
        _clearForm();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _recalculateTotalPrice() {
    double total = 0.0;
    for (var service in _selectedServices) {
      total += service.defaultPrice ?? 0.0;
    }
    setState(() {
      _totalPrice = total;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _patientSearchController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _patientSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Book New Appointment',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800]),
                        ),
                        if (widget.isDialog)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                          ),
                      ],
                    ),                    const SizedBox(height: 24),
                    _buildPatientSelector(),
                    const SizedBox(height: 16),
                    _buildLaboratoryCheckbox(),
                    const SizedBox(height: 16),
                    if (!_isLaboratoryOnly) _buildDoctorSelector(),
                    if (!_isLaboratoryOnly) const SizedBox(height: 16),
                    _buildDateTimePicker(),
                    const SizedBox(height: 16),
                    _buildServiceSelector(),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatientSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: _patientSearchController,
                decoration: InputDecoration(
                  labelText: 'Search for Patient',
                  hintText: 'Type patient name or ID...',
                  border: const OutlineInputBorder(),
                  prefixIcon: _isSearchingPatient
                      ? Transform.scale(
                          scale: 0.5,
                          child: const CircularProgressIndicator(),
                        )
                      : const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    tooltip: 'Register New Patient',
                    onPressed: _showPatientRegistrationDialog,
                  ),
                ),
                onChanged: (value) {
                  _onPatientSearchChanged(value);
                },
              ),
            ),
          ],
        ),
        if (_patientSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _patientSearchResults.length,
              itemBuilder: (context, index) {
                final patient = _patientSearchResults[index];
                return ListTile(
                  title: Text(patient.fullName),
                  subtitle: Text('ID: ${patient.id}'),
                  onTap: () {
                    setState(() {
                      _selectedPatient = patient;
                      _patientSearchController.text = patient.fullName;
                      _patientSearchResults = [];
                    });
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  tileColor: Colors.white,
                  hoverColor: Colors.teal.withAlpha(10),
                );
              },
            ),
          ),
        if (_selectedPatient != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Chip(
              label: Text(_selectedPatient!.fullName),
              avatar: const Icon(Icons.person),
              onDeleted: () {
                setState(() {
                  _selectedPatient = null;
                  _patientSearchController.clear();
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDoctorSelector() {
    return DropdownButtonFormField<User>(
      decoration: const InputDecoration(
        labelText: 'Select Doctor',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.medical_services_outlined),
        helperText: 'All doctors are available for flexible scheduling',
      ),
      value: _selectedDoctor,
      items: _doctors.map((User doctor) {
        return DropdownMenuItem<User>(
          value: doctor,
          child: Text('Dr. ${doctor.fullName}'),
        );
      }).toList(),
      onChanged: (User? newValue) {
        debugPrint('AddAppointmentScreen: Doctor selected: ${newValue?.fullName}');
        setState(() {
          _selectedDoctor = newValue;
        });
      },
      validator: (value) {
        if (_isLaboratoryOnly) return null;
        return value == null ? 'Please select a doctor' : null;
      },
    );
  }

  Widget _buildDateTimePicker() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(DateFormat.yMMMd().format(_selectedDate)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _showTimePicker(),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Time',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
              child: Text(_selectedTime.format(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [        Text(_isLaboratoryOnly ? 'Laboratory Tests' : 'Services / Purpose of Visit',
            style: TextStyle(
                fontWeight: FontWeight.w500, color: Colors.grey[700])),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: Icon(_isLaboratoryOnly ? Icons.science_outlined : Icons.medical_services_outlined),
          label: Text(_isLaboratoryOnly ? 'Select Laboratory Tests' : 'Select Services / Purpose'),
          onPressed: _openServiceSelectionDialog,
          style: ElevatedButton.styleFrom(
              backgroundColor: _isLaboratoryOnly ? Colors.blue[50] : Colors.teal[50],
              foregroundColor: _isLaboratoryOnly ? Colors.blue[700] : Colors.teal[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 10),
        if (_selectedServices.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,            children: _selectedServices
                .map((service) => Chip(
                      label: Text(
                          '${service.serviceName} (₱${(service.defaultPrice ?? 0.0).toStringAsFixed(2)})'),
                      backgroundColor: _isLaboratoryOnly ? Colors.blue[100] : Colors.teal[100],
                      labelStyle: TextStyle(color: _isLaboratoryOnly ? Colors.blue[800] : Colors.teal[800]),
                    ))
                .toList(),          ),
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
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isLoading
              ? null
              : (widget.isDialog
                  ? () => Navigator.of(context).pop()
                  : _clearForm),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submitForm,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_alt_outlined),
          label: const Text('Save Appointment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildLaboratoryCheckbox() {
    return Card(
      elevation: 1,
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
                    // Clear doctor selection when switching to laboratory only
                    _selectedDoctor = null;
                  }
                });
              },
              activeColor: Colors.teal[700],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laboratory Tests Only',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal[800],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check this if the patient only needs laboratory tests without doctor consultation',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
