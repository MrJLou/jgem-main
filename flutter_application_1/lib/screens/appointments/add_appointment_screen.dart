import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/appointment.dart';
import 'package:intl/intl.dart'; // For DateFormat.Hm()
import 'package:flutter_application_1/models/patient.dart'; // ADDED - Real Patient model
import 'package:flutter_application_1/models/user.dart'; // ADDED - For Doctor data (assuming doctors are Users)
import 'package:flutter_application_1/services/api_service.dart'; // ADDED
import 'package:flutter_application_1/screens/registration/patient_registration_screen.dart' show ReusablePatientFormFields, FormType; // Specific import
import 'dart:async'; // ADDED for Timer
import '../../models/clinic_service.dart'; // ADDED ClinicService import

class AddAppointmentScreen extends StatefulWidget {
  final List<Appointment> existingAppointments;
  final Function(Appointment) onAppointmentAdded;
  final DateTime? initialDate;

  const AddAppointmentScreen({
    super.key,
    required this.existingAppointments,
    required this.onAppointmentAdded,
    this.initialDate,
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

  // Search state variables
  final TextEditingController _patientSearchController = TextEditingController();
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
  final TextEditingController _otherPurposeController = TextEditingController();
  bool _showOtherPurposeFieldInDialog = false;

  final List<String> _dialogBloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
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
    const endMinutes = 16 * 60 + 30;   // 4:30 PM

    while (currentMinutes <= endMinutes) {
      slots.add(TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60));
      currentMinutes += 30;
    }
    return slots;
  }

  @override
  void initState() {
    super.initState();
    debugPrint("AddAppointmentScreen: Using ApiService for data operations.");
    
    _fetchInitialFormData();
    _fetchAvailableServices();

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
      final now = DateTime.now();
      if (DateUtils.isSameDay(_selectedDate, now) && 
          (_selectedTime.hour < now.hour || (_selectedTime.hour == now.hour && _selectedTime.minute < now.minute))) {
        _selectedTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
      }
    } else {
      final now = DateTime.now();
      if (DateUtils.isSameDay(_selectedDate, now) && 
          (_selectedTime.hour < now.hour || (_selectedTime.hour == now.hour && _selectedTime.minute < now.minute))) {
         _selectedTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
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
            proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
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
      setState(() {
        _doctors = allUsers.where((user) => user.role == 'doctor').toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load patient/doctor list: ${e.toString()}";
      });
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

  Future<void> _fetchAvailableServices() async {
    try {
      final services = await ApiService.getAllClinicServices();
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
      debugPrint('Error fetching available services for appointment screen: $e');
    }
  }

  void _clearForm() {
    setState(() {
      _selectedPatient = null;
      _selectedDoctor = null;
      final nowDateTime = DateTime.now();
      _selectedDate = widget.initialDate ?? nowDateTime;
      
      if (!_isSelectable(_selectedDate)) { 
         _selectedDate = _selectedDate.add(Duration(days: DateTime.monday - _selectedDate.weekday));
         if(_selectedDate.isBefore(nowDateTime) && !DateUtils.isSameDay(_selectedDate, nowDateTime)) { 
            _selectedDate = _selectedDate.add(const Duration(days: 7));
         }
      }
      
      const minWorkingTime = TimeOfDay(hour: 7, minute: 30);

      if (DateUtils.isSameDay(_selectedDate, nowDateTime)) {
          TimeOfDay proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
          if (_timeOfDayToMinutes(proposedTime) < _timeOfDayToMinutes(TimeOfDay.fromDateTime(nowDateTime))) {
             proposedTime = TimeOfDay.fromDateTime(nowDateTime.add(const Duration(minutes: 5)));
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
      _otherPurposeController.clear();
    });
  }

  void _onPatientSearchChanged(String query) {
    if (_patientSearchDebounce?.isActive ?? false) _patientSearchDebounce!.cancel();
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
    final initialPickerDate = _selectedDate.isBefore(today) ? today : _selectedDate;

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
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    if (_selectedDoctor == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor first to see their availability.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final List<TimeOfDay> timeSlots = _generateWorkingTimeSlots();
    if (timeSlots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available time slots for this day.')));
      return;
    }

    // Determine booked time slots for the selected doctor and date
    final Set<TimeOfDay> bookedTimes = widget.existingAppointments
        .where((appt) =>
            appt.doctorId == _selectedDoctor!.id &&
            DateUtils.isSameDay(appt.date, _selectedDate))
        .map((appt) => appt.time)
        .toSet();

    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Time Slot'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                alignment: WrapAlignment.center,
                children: timeSlots.map((time) {
                  final isBooked = bookedTimes.any((bookedTime) =>
                      bookedTime.hour == time.hour &&
                      bookedTime.minute == time.minute);

                  final now = DateTime.now();
                  final nowDateOnly = DateUtils.dateOnly(now);
                  bool isPast = false;
                  if (_selectedDate.isBefore(nowDateOnly)) {
                    isPast = true;
                  } else if (DateUtils.isSameDay(_selectedDate, nowDateOnly)) {
                    final timeInMinutes = time.hour * 60 + time.minute;
                    final nowInMinutes = now.hour * 60 + now.minute;
                    if (timeInMinutes < nowInMinutes) {
                      isPast = true;
                    }
                  }

                  final bool isDisabled = isBooked || isPast;

                  return SizedBox(
                    width: 100, // Fixed width for buttons
                    child: ElevatedButton(
                      onPressed: isDisabled
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
    bool tempShowOtherField = _showOtherPurposeFieldInDialog;
    final tempOtherPurposeController =
        TextEditingController(text: _otherPurposeController.text);

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
            // Ensure 'Consultation' and 'Laboratory' appear first if they exist, then others.
            List<String> categoryOrder = ['Consultation', 'Laboratory'];
            List<String> allCategories = groupedServices.keys.toList();
            categoryOrder.addAll(
                allCategories.where((cat) => !categoryOrder.contains(cat)));

            return AlertDialog(
              title: const Text('Select Services / Purpose of Visit'),
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
                              ...groupedServices[category]!
                                  .map((service) => CheckboxListTile(
                                        title: Text(
                                            '${service.serviceName} (₱${NumberFormat("#,##0.00", "en_US").format(service.defaultPrice ?? 0.0)})',
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        value: tempSelections[service.id] ??
                                            false,
                                        onChanged: (bool? value) {
                                          setDialogState(() {
                                            tempSelections[service.id] =
                                                value!;
                                            currentDialogPrice =
                                                _availableServices
                                                    .where((s) =>
                                                        tempSelections[
                                                            s.id] ==
                                                        true)
                                                    .fold(
                                                        0.0,
                                                        (sum, item) =>
                                                            sum +
                                                            (item.defaultPrice ??
                                                                0.0));
                                          });
                                        },
                                        dense: true,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        activeColor: Colors.teal,
                                      )),
                              const Divider(),
                            ]),
                    CheckboxListTile(
                      title: const Text("Other Purpose (Specify below)",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.normal)),
                      value: tempShowOtherField,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempShowOtherField = value!;
                        });
                      },
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.teal,
                    ),
                    if (tempShowOtherField)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            bottom: 8.0,
                            top: 4.0),
                        child: TextFormField(
                          controller: tempOtherPurposeController,
                          decoration: const InputDecoration(
                              labelText: 'Specify other purpose or details',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Medical Certificate, Fit to Work',
                              isDense: true),
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
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              actions: <Widget>[
                TextButton(
                  child:
                      const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                      'showOther': tempShowOtherField,
                      'otherPurpose': tempOtherPurposeController.text,
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
        
        _showOtherPurposeFieldInDialog = result['showOther'];
        if(_showOtherPurposeFieldInDialog) {
          _otherPurposeController.text = result['otherPurpose'];
        } else {
          _otherPurposeController.clear();
        }

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
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Register New Patient'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: ReusablePatientFormFields(
                    formType: FormType.mini,
                    firstNameController: firstNameController,
                    lastNameController: lastNameController,
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
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
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
                              fullName: '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
                              birthDate: DateFormat('yyyy-MM-dd').parse(dobController.text),
                              gender: selectedGender,
                              contactNumber: contactController.text.trim(),
                              address: addressController.text.trim(),
                              bloodType: selectedBloodType,
                              allergies: allergiesController.text.trim(),
                              createdAt: now,
                              updatedAt: now,
                            );

                            try {
                              final newPatientId = await ApiService.createPatient(patientToSave);
                              final savedPatient = patientToSave.copyWith(id: newPatientId);
                              
                              if (!mounted) return;
                              Navigator.of(context).pop(savedPatient);
                            } catch (e) {
                              debugPrint("Error saving new patient from dialog: $e");
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save patient: ${e.toString()}'),
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
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Patient'),
                ),
              ],
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

  void _saveAppointment() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatient == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a patient.')));
        return;
      }
      if (_selectedDoctor == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a doctor.')));
        return;
      }

      // The conflict check is now implicitly handled by the backend during the API call.
      // The _selectTime dialog already provides client-side guidance based on locally available data.

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        List<Map<String, dynamic>> servicesForDb = _selectedServices.map((s) => {
          'id': s.id,
          'name': s.serviceName,
          'price': s.defaultPrice
        }).toList();

        final appointmentToSave = Appointment(
          id: 'temp_id', // Will be replaced by the ID from the database.
          patientId: _selectedPatient!.id,
          doctorId: _selectedDoctor!.id,
          date: _selectedDate,
          time: _selectedTime,
          status: 'Scheduled',
          consultationType: _otherPurposeController.text.isNotEmpty 
              ? _otherPurposeController.text 
              : 'General Consultation',
          selectedServices: servicesForDb,
          totalPrice: _totalPrice,
        );
        
        // Assumes ApiService.createAppointment handles the database transaction
        // and returns the ID of the newly created appointment.
        final newAppointmentId = await ApiService.createAppointment(appointmentToSave);
        // Assumes Appointment model has a copyWith method to update the ID.
        final savedAppointment = appointmentToSave.copyWith(id: newAppointmentId);

        // Use callback to notify parent and update the appointments list in the UI
        widget.onAppointmentAdded(savedAppointment);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Appointment for ${_selectedPatient!.fullName} at ${_selectedTime.format(context)} saved successfully!'),
              backgroundColor: Colors.green),
        );
        _clearForm();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Failed to save appointment: ${e.toString()}";
        });
        // The error from the backend (e.g., a scheduling conflict) will be shown here.
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
                    Text(
                      'Book New Appointment',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800]),
                    ),
                    const SizedBox(height: 24),
                    _buildPatientSelector(),
                    const SizedBox(height: 16),
                    _buildDoctorSelector(),
                    const SizedBox(height: 16),
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
              child: Autocomplete<Patient>(
                displayStringForOption: (Patient option) =>
                    '${option.fullName} (ID: ${option.id})',
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Patient>.empty();
                  }
                  return _patientSearchResults;
                },
                onSelected: (Patient selection) {
                  setState(() {
                    _selectedPatient = selection;
                    _patientSearchController.text = selection.fullName;
                  });
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  _patientSearchController.addListener(() {
                    fieldController.text = _patientSearchController.text;
                  });

                  return TextFormField(
                    controller: fieldController,
                    focusNode: fieldFocusNode,
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
                    onChanged: _onPatientSearchChanged,
                  );
                },
                optionsViewBuilder: (BuildContext context,
                    AutocompleteOnSelected<Patient> onSelected,
                    Iterable<Patient> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        height: 200.0,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Patient option = options.elementAt(index);
                            return ListTile(
                              title: Text(
                                  '${option.fullName} (ID: ${option.id})'),
                              onTap: () {
                                onSelected(option);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
      ),
      value: _selectedDoctor,
      items: _doctors.map((User doctor) {
        return DropdownMenuItem<User>(
          value: doctor,
          child: Text(doctor.fullName),
        );
      }).toList(),
      onChanged: (User? newValue) {
        setState(() {
          _selectedDoctor = newValue;
        });
      },
      validator: (value) => value == null ? 'Please select a doctor' : null,
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
            onTap: () => _selectTime(context),
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
      children: [
        Text('Services / Purpose of Visit',
            style: TextStyle(
                fontWeight: FontWeight.w500, color: Colors.grey[700])),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.medical_services_outlined),
          label: const Text('Select Services / Purpose'),
          onPressed: _openServiceSelectionDialog,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[50],
              foregroundColor: Colors.teal[700],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          '${service.serviceName} (₱${(service.defaultPrice ?? 0.0).toStringAsFixed(2)})'),
                      backgroundColor: Colors.teal[100],
                      labelStyle: TextStyle(color: Colors.teal[800]),
                    ))
                .toList(),
          ),
        if (_showOtherPurposeFieldInDialog &&
            _otherPurposeController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("Other: ${_otherPurposeController.text}",
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        if (_selectedServices.isNotEmpty ||
            (_showOtherPurposeFieldInDialog &&
                _otherPurposeController.text.isNotEmpty))
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
          onPressed: _isLoading ? null : _clearForm,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveAppointment,
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
} 