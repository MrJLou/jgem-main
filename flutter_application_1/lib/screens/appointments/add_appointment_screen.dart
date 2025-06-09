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
  late QueueService _queueService;

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
    _queueService = QueueService();
    print("AddAppointmentScreen: Using ApiService for data operations.");
    
    _fetchInitialFormData();
    _fetchAvailableServices();

    if (widget.selectedDate != null) {
      _selectedDate = widget.selectedDate!;
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

    if (widget.selectedDate != null) {
      _selectedDate = widget.selectedDate!;
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
      if (mounted) {
        setState(() {
          _doctors = allUsers.where((user) => user.role == 'doctor').toList();
        });
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

  Future<void> _fetchAvailableServices() async {
    try {
      final services = await ApiService.getAllClinicServices();
      if (mounted) {
        setState(() {
          _availableServices = services;
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

  void _clearForm() {
    setState(() {
      _selectedPatient = null;
      _selectedDoctor = null;
      final nowDateTime = DateTime.now();
      _selectedDate = widget.selectedDate ?? nowDateTime;
      
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
      _showOtherPurposeFieldInDialog = false;
    });
  }

  String? _getConflictMessage(String doctorId, String doctorName, String patientId, String patientName, DateTime date, TimeOfDay time, int durationMinutes) {
    DateTime newApptStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    DateTime newApptEnd = newApptStart.add(Duration(minutes: durationMinutes));

    for (var existing in widget.existingAppointments) {
      int existingDuration = existing.durationMinutes ?? 30; 
      DateTime existingApptStart = DateTime(existing.date.year, existing.date.month, existing.date.day, existing.time.hour, existing.time.minute);
      DateTime existingApptEnd = existingApptStart.add(Duration(minutes: existingDuration));

      bool overlap = newApptStart.isBefore(existingApptEnd) && newApptEnd.isAfter(existingApptStart);

      if (overlap) {
        if (existing.doctorId == doctorId) {
          return "Doctor Conflict: Dr. $doctorName is booked from ${DateFormat.Hm().format(existingApptStart)} to ${DateFormat.Hm().format(existingApptEnd)}.";
        }
        if (existing.patientId == patientId) {
          return "Patient Conflict: $patientName already has an appointment scheduled from ${DateFormat.Hm().format(existingApptStart)} to ${DateFormat.Hm().format(existingApptEnd)}.";
        }
      }
    }
    return null;
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    DateTime initialPickerDate = _selectedDate;
    if (initialPickerDate.isBefore(now) && !DateUtils.isSameDay(initialPickerDate, now)) {
      initialPickerDate = now;
    }
    if (!_isSelectable(initialPickerDate)) {
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
      selectableDayPredicate: _isSelectable,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        const minWorkingTime = TimeOfDay(hour: 7, minute: 30);
        const maxWorkingTime = TimeOfDay(hour: 16, minute: 30);
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
        } else {
            _selectedTime = minWorkingTime;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatient == null || _selectedDoctor == null) {
        setState(() {
          _errorMessage = 'Please select a patient and a doctor.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error
          )
        );
        return;
      }

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

      const int appointmentDurationMinutes = 30;
      if (!_isSelectable(_selectedDate)) {
        setState(() { _errorMessage = 'Appointments cannot be scheduled on Sundays.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      final DateTime workDayStartBoundary = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 7, 30);
      final DateTime workDayEndBoundary = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 16, 30);
      final DateTime appointmentEndDateTime = appointmentStartDateTime.add(const Duration(minutes: appointmentDurationMinutes));

      if (appointmentStartDateTime.isBefore(workDayStartBoundary)) {
        setState(() { _errorMessage = 'Appointments must start on or after 7:30 AM.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      if (appointmentEndDateTime.isAfter(workDayEndBoundary)) {
        setState(() { _errorMessage = 'Appointments must end by 4:30 PM. Selected time is too late for a 30-minute appointment.'; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointments must end by 4:30 PM. Selected time or duration is too late.'), backgroundColor: Colors.red, duration: Duration(seconds: 4),));
        return;
      }

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
          _selectedDoctor!.fullName,
          _selectedPatient!.id,
          _selectedPatient!.fullName,
          _selectedDate,
          _selectedTime,
          appointmentDurationMinutes
      );
      if (conflictMessage != null) {
        setState(() { _errorMessage = conflictMessage; });
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      setState(() { _isLoading = true; _errorMessage = null; });

      try {
        final List<Map<String, dynamic>> servicesToStore = _selectedServices.map((service) => {
          'id': service.id,
          'name': service.serviceName,
          'category': service.category ?? 'Uncategorized',
          'price': service.defaultPrice ?? 0.0,
        }).toList();
        
        String consultationTypeStr = _selectedServices.map((s) => s.serviceName).join(', ');
        if (consultationTypeStr.isEmpty) {
          if (_otherPurposeController.text.trim().isNotEmpty) {
            consultationTypeStr = _otherPurposeController.text.trim();
          } else {
            consultationTypeStr = 'General Consultation';
          }
        }

        Appointment newAppointment = Appointment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: _selectedPatient!.id,
          date: _selectedDate,
          time: _selectedTime,
          doctorId: _selectedDoctor!.id,
          consultationType: consultationTypeStr,
          durationMinutes: appointmentDurationMinutes,
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

    void _searchPatients(String query) async {
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
      _otherPurposeController.dispose();
      super.dispose();
    }
    
    @override
    void didUpdateWidget(covariant AddAppointmentScreen oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (widget.selectedDate != null && widget.selectedDate != _selectedDate) {
        setState(() {
          _selectedDate = widget.selectedDate!;
          const minWorkingTime = TimeOfDay(hour: 7, minute: 30);
          const maxWorkingTime = TimeOfDay(hour: 16, minute: 30);
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
              } else {
                  _selectedTime = minWorkingTime;
              }
          } else {
              _selectedTime = minWorkingTime;
          }
        });
      }
    }

  @override
  Widget build(BuildContext context) {
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
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Expanded(
                          child: TextFormField( 
                            controller: _patientSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search Patient (Name/ID)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _isSearchingPatient
                                  ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : (_patientSearchController.text.isNotEmpty 
                                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                          _patientSearchController.clear();
                                          setState(() => _patientSearchResults = []);
                                        })
                                      : null),
                            ),
                            onChanged: _searchPatients,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 0.0),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('New'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[300],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                textStyle: const TextStyle(fontSize: 14)
                            ),
                            onPressed: () => _showNewPatientDialog(context),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedPatient != null) ...[
                        Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                            child: Chip(
                                avatar: Icon(Icons.person, color: Colors.teal[700]),
                                label: Text('Selected: ${_selectedPatient!.fullName} (ID: ${_selectedPatient!.id})'),
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
                        const SizedBox(height: 8.0),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: SizedBox(
                              height: 180,
                              child: SingleChildScrollView(
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
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 48,
                                  headingRowHeight: 48,
                                  columnSpacing: 16,
                                  horizontalMargin: 8,
                                ),
                              )
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),

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
                              '${doctor.fullName} (ID: ${doctor.id})',
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
                            '${doctor.fullName} (ID: ${doctor.id})', 
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

                    DropdownButtonFormField<TimeOfDay>(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        prefixIcon: const Icon(Icons.access_time_outlined, color: Colors.teal),
                      ),
                      value: _selectedTime,
                      hint: const Text('Select Time'),
                      items: () {
                        final slots = _generateWorkingTimeSlots();
                        if (!slots.contains(_selectedTime)) {
                          slots.add(_selectedTime);
                          slots.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
                        }
                        return slots.map((TimeOfDay time) {
                          return DropdownMenuItem<TimeOfDay>(
                            value: time,
                            child: Text(time.format(context)),
                          );
                        }).toList();
                      }(),
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

                    Text('Services / Purpose of Visit',
                        style: TextStyle(
                            fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[700])),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.medical_services_outlined, color: Colors.teal),
                      label: Text('Select Services / Specify Purpose', style: TextStyle(color: Colors.teal[700])),
                      onPressed: _openServiceSelectionDialog,
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
                                      _serviceSelectionState[service.id] = false;
                                      _selectedServices.removeWhere((s) => s.id == service.id);
                                      _totalPrice = _selectedServices.fold(0.0, (sum, item) => sum + (item.defaultPrice ?? 0.0));
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    if (_otherPurposeController.text.isNotEmpty)
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

  Future<void> _showNewPatientDialog(BuildContext context) async {
    final result = await showDialog<Patient>(
        context: context,
        barrierDismissible: false, 
        builder: (BuildContext dialogContext) {
            final currentTextTheme = Theme.of(dialogContext).textTheme;
            const double dialogFontSizeFactor = 0.9;

            return AlertDialog(
                title: const Text('Register New Patient'),
                contentPadding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0),
                content: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * 0.85,
                  height: MediaQuery.of(dialogContext).size.height * 0.75,
                  child: _DialogPatientRegistrationForm(
                    bloodTypes: _dialogBloodTypes,
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

  void _openServiceSelectionDialog() {
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
                categoryOrder.add('Uncategorized');
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
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DialogPatientRegistrationForm extends StatefulWidget {
  final Function(Patient) onRegistered;
  final List<String> bloodTypes;

  const _DialogPatientRegistrationForm({required this.onRegistered, required this.bloodTypes});

  @override
  State<_DialogPatientRegistrationForm> createState() => _DialogPatientRegistrationFormState();
}

class _DialogPatientRegistrationFormState extends State<_DialogPatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
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
          if (mounted) {
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
          email: _emailController.text.trim(),
          address: _addressController.text.trim(), 
          bloodType: _bloodType, 
          allergies: _allergiesController.text.trim(),
          currentMedications: _currentMedicationsController.text.trim(),
          medicalHistory: _medicalInfoController.text.trim(),
          emergencyContactName: _emergencyContactNameController.text.trim(),
          emergencyContactNumber: _emergencyContactController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final patientId = await ApiService.createPatient(newPatient);
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
            labelStyle: const TextStyle(fontSize: dialogFontSize),            
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
                            textStyle: const TextStyle(fontSize: dialogFontSize + 1, fontWeight: FontWeight.bold) 
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