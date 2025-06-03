import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter_application_1/screens/appointments/add_appointment_screen.dart'; 
import 'package:flutter_application_1/models/appointment.dart';
import 'package:flutter_application_1/services/api_service.dart'; // ADDED for ApiService
import 'package:flutter_application_1/models/patient.dart'; // ADDED
import 'package:flutter_application_1/models/active_patient_queue_item.dart'; // ADDED

class AppointmentOverviewScreen extends StatefulWidget {
  const AppointmentOverviewScreen({super.key});

  @override
  State<AppointmentOverviewScreen> createState() => _AppointmentOverviewScreenState();
}

class _AppointmentOverviewScreenState extends State<AppointmentOverviewScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = []; // For the right pane (filtered by _selectedDate)
  List<Appointment> _allCalendarAppointments = []; // Holds ALL appointments for conflict checking and filtering

  bool _isLoading = true; // Start with loading true
  String? _errorMessage;
  // bool _isDbInitialized = false; // We'll rely on ApiService, not direct DB init here

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  @override
  void initState() {
    super.initState();
    // Initialize with a few dummy appointments for UI testing
    // _simulatedAppointments = [ ... ]; // REMOVED OLD SIMULATION
    _initializeServicesAndFetch();
  }

  Future<void> _initializeServicesAndFetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all appointments for the calendar/conflict checks
      _allCalendarAppointments = await ApiService.getAllAppointments();
      // print("Fetched ${_allCalendarAppointments.length} total appointments for the calendar.");
      _filterAppointmentsForSelectedDate(); // Initial filter for the list view
      // _isDbInitialized = true; // Assuming ApiService handles DB readiness
    } catch (e) {
      print("Error initializing or fetching all appointments: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load appointments: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterAppointmentsForSelectedDate() {
    if (!mounted) return;
    setState(() {
      _appointments = _allCalendarAppointments.where((appt) =>
        DateUtils.isSameDay(appt.date, _selectedDate)
      ).toList();
      _appointments.sort((a, b) => (a.time.hour * 60 + a.time.minute).compareTo(b.time.hour * 60 + b.time.minute));
      // print("Filtered ${_appointments.length} appointments for date: ${_selectedDate.toIso8601String().substring(0,10)}");
    });
  }

  void _changeDate(Duration duration) {
    if (!mounted) return;
    setState(() {
      _selectedDate = _selectedDate.add(duration);
    });
    _filterAppointmentsForSelectedDate(); // Filter from the already fetched all appointments
  }

  bool _isPastSelectedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selectedDay.isBefore(today);
  }

  void _handleAppointmentSaved(Appointment newAppointmentFromForm) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true; // Show loading indicator while saving
      _errorMessage = null; // Clear previous errors
    });

    try {
      // Ensure the appointment from form has the correct status and other necessary defaults
      final appointmentToSave = newAppointmentFromForm.copyWith(
        status: 'Scheduled', // Ensure correct status
        // id: newAppointmentFromForm.id.isNotEmpty ? newAppointmentFromForm.id : null, // Let DB handle ID if it's new, or keep if updating
        // The ID from form is temporary (DateTime.now().millisecondsSinceEpoch.toString())
        // The database_helper's insertAppointment creates its own ID.
        // So, for a new appointment, the ID from the form is not really used by the DB insert.
        // If we were to support *updating* appointments through this form, ID handling would be critical.
        // For now, assuming new appointments.
      );

      final savedAppointmentFromDb = await ApiService.saveAppointment(appointmentToSave); 

      // Add to the master list
      // To prevent duplicates if the appointment was an update, remove old one first.
      // This assumes saveAppointment returns the appointment with a definitive ID.
      _allCalendarAppointments.removeWhere((appt) => appt.id == savedAppointmentFromDb.id);
      _allCalendarAppointments.add(savedAppointmentFromDb);
      _allCalendarAppointments.sort((a, b) {
          int dateComparison = a.date.compareTo(b.date);
          if (dateComparison != 0) return dateComparison;
          return (a.time.hour * 60 + a.time.minute).compareTo(b.time.hour * 60 + b.time.minute);
        });

      if (!DateUtils.isSameDay(_selectedDate, savedAppointmentFromDb.date)) {
        // Optional: setState(() { _selectedDate = savedAppointmentFromDb.date; });
      }
      _filterAppointmentsForSelectedDate(); 

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Appointment for P_ID: ${savedAppointmentFromDb.patientId} on ${DateFormat.yMd().format(savedAppointmentFromDb.date)} saved.'), backgroundColor: Colors.green)
        );
      }

      // ---- ADD TO ACTIVE PATIENT QUEUE ----
      try {
        Patient? patientDetails;
        try {
            patientDetails = await ApiService.getPatientById(savedAppointmentFromDb.patientId);
        } catch (e) {
            print("Could not fetch patient details for queue item: $e");
            // Continue without full patient details if fetch fails
        }

        final arrivalDateTime = DateTime(
            savedAppointmentFromDb.date.year,
            savedAppointmentFromDb.date.month,
            savedAppointmentFromDb.date.day,
            savedAppointmentFromDb.time.hour,
            savedAppointmentFromDb.time.minute,
        );

        // TODO: Determine a robust way to get queueNumber or make it nullable/default in DB for this use case.
        // For now, using a placeholder or 0 if non-nullable.
        // If queueNumber is for daily sequence, this scheduled appointment might not follow that sequence easily.
        int currentQueueNumber = 0; // Placeholder

        ActivePatientQueueItem queueItem = ActivePatientQueueItem(
          queueEntryId: 'appt_q_${DateTime.now().millisecondsSinceEpoch.toString()}', // Unique ID for queue entry
          patientId: savedAppointmentFromDb.patientId,
          patientName: patientDetails?.fullName ?? savedAppointmentFromDb.patientId, // Use fetched name or ID as fallback
          arrivalTime: arrivalDateTime,
          queueNumber: currentQueueNumber, // Placeholder or a system to assign this
          gender: patientDetails?.gender,
          age: patientDetails != null ? (DateTime.now().year - patientDetails.birthDate.year) : null, // Basic age calculation
          conditionOrPurpose: "Scheduled: ${savedAppointmentFromDb.consultationType ?? 'Appointment'}".substring(0, savedAppointmentFromDb.consultationType != null ? (savedAppointmentFromDb.consultationType!.length + 11 > 100 ? 100 : savedAppointmentFromDb.consultationType!.length + 11) : 20), // Truncate if needed
          selectedServices: null, // Appointments don't directly store multiple selected services in this model
          totalPrice: null, // Not directly available from appointment
          status: 'waiting', // Or 'scheduled_pending_check_in' etc.
          createdAt: DateTime.now(),
          addedByUserId: savedAppointmentFromDb.createdById, // Assuming createdById of appointment is the staff who scheduled it
        );

        await ApiService.addToActiveQueue(queueItem);
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Patient ${queueItem.patientName} added to today\'s queue.'), backgroundColor: Colors.blueAccent),
            );
        }
      } catch (e) {
        print("Failed to add scheduled appointment to active queue: $e");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error adding patient to queue: ${e.toString()}'), backgroundColor: Colors.orangeAccent),
            );
        }
      }
      // ---- END ADD TO ACTIVE PATIENT QUEUE ----

    } catch (e) {
      print("Error saving appointment or adding to queue: $e");
      if (mounted) {
        setState(() {
           _errorMessage = "Failed to save appointment: ${e.toString()}"; // Show error in UI
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save appointment: ${e.toString()}'), backgroundColor: Colors.red)
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


  Widget _buildStatusChip(String status) {
    Color chipColor = Colors.grey;
    IconData iconData = Icons.info_outline;

    switch (status.toLowerCase()) {
      case 'scheduled (simulated)': // Keep for old simulated data if any
      case 'scheduled':
        chipColor = Colors.blue.shade700;
        iconData = Icons.schedule_outlined;
        break;
      case 'confirmed':
        chipColor = Colors.green.shade700;
        iconData = Icons.check_circle_outline;
        break;
      case 'cancelled':
        chipColor = Colors.red.shade700;
        iconData = Icons.cancel_outlined;
        break;
      case 'completed':
        chipColor = Colors.purple.shade700;
        iconData = Icons.done_all_outlined;
        break;
    }
    return Chip(
      avatar: Icon(iconData, color: Colors.white, size: 16),
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final bool isPastDate = _isPastSelectedDate(); // No longer directly used for Add button enabling here

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Appointment Management', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        // actions: [ // Example: Add a refresh button if needed
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: _initializeServicesAndFetch,
        //     tooltip: 'Refresh Appointments',
        //   )
        // ],
      ),
      body: Row(
        children: [
          // Left Pane: Add Appointment Form
          Expanded(
            flex: 1, // Adjust flex factor as needed (e.g., 1 for smaller, 2 for larger)
            child: Material( // Wrap AddAppointmentScreen with Material for correct theming if it doesn't have its own Scaffold
              elevation: 4.0, // Optional: add elevation to visually separate panes
              child: AddAppointmentScreen(
                // Key is important if you need to forcefully re-init AddAppointmentScreen's state,
                // e.g. when _selectedDate changes and you want its internal date to reset.
                // key: ValueKey(_selectedDate), // This would re-create AddAppointmentScreen state on date change
                selectedDate: _selectedDate,
                existingAppointments: List<Appointment>.from(_allCalendarAppointments), // Pass all for conflict check
                onAppointmentSaved: _handleAppointmentSaved,
                onCancel: () {
                  // Optional: handle cancel from AddAppointmentScreen, e.g., clear selection or show message
                  // For now, AddAppointmentScreen's internal _clearForm handles it.
                },
              ),
            ),
          ),

          // Right Pane: Appointment List
          Expanded(
            flex: 2, // Adjust flex factor as needed
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header for the right pane (Appointment Schedule)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Appointment Schedule',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal[700]),
                    ),
                  ),
                  
                  // Date Navigation
                  Card(
                    elevation: 2.0,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.teal),
                            onPressed: () => _changeDate(const Duration(days: -1)),
                            tooltip: 'Previous Day',
                            splashRadius: 20,
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal[800]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.teal),
                            onPressed: () => _changeDate(const Duration(days: 1)),
                            tooltip: 'Next Day',
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Center(
                        child: Text(_errorMessage!, 
                          style: TextStyle(color: Colors.orangeAccent[700], fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Appointments List or Messages
                  Expanded(
                    child: _isLoading && _appointments.isEmpty // Show loader only if list is empty during initial load
                        ? const Center(child: CircularProgressIndicator())
                        : _appointments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_busy_outlined, size: 60, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage == null ? 'No appointments scheduled for this date.' : '', // Avoid double message if error shown
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]), 
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                    itemCount: _appointments.length,
                                    itemBuilder: (context, index) {
                                      final appointment = _appointments[index];
                                      String subtitleText = 
                                          'Time: ${appointment.time.format(context)}';
                                      if (appointment.consultationType != null && appointment.consultationType!.isNotEmpty) {
                                        subtitleText += ' (${appointment.consultationType}';
                                        if (appointment.durationMinutes != null && appointment.durationMinutes! > 0) {
                                          subtitleText += ', ${appointment.durationMinutes} mins';
                                        }
                                        subtitleText += ')';
                                      }
                                      subtitleText += '\nDoctor: ${appointment.doctorId}'; 
                                      if (appointment.notes != null && appointment.notes!.isNotEmpty) {
                                        subtitleText += '\nNotes: ${appointment.notes}';
                                      }

                                      return Card(
                                        elevation: 2.0,
                                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.teal[50],
                                            child: Text(
                                              appointment.time.hour.toString().padLeft(2, '0'), 
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700], fontSize: 16),
                                            ),
                                          ),
                                          title: Text('Patient: ${appointment.patientId}', style: const TextStyle(fontWeight: FontWeight.w600)), 
                                          subtitle: Text(subtitleText, style: TextStyle(color: Colors.grey[700], height: 1.3)),
                                          trailing: _buildStatusChip(appointment.status), 
                                          isThreeLine: subtitleText.contains('\n'), 
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                          // TODO: Add onTap to view/edit appointment details
                                        ),
                                      );
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
} 