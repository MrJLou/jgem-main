// Live queue dashboard view - main dashboard content
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/appointment.dart';
import '../../models/active_patient_queue_item.dart';
import '../../services/api_service.dart';
import '../../services/queue_service.dart';
import '../../services/database_sync_client.dart';
import 'dashboard_welcome_section.dart';
import 'dashboard_metrics_section.dart';
import 'dashboard_doctors_section.dart';
import 'dashboard_calendar_section.dart';
import 'live_queue_display_section.dart';

class LiveQueueDashboardView extends StatefulWidget {
  final QueueService queueService;
  final List<Appointment> appointments;

  const LiveQueueDashboardView(
      {super.key, required this.queueService, required this.appointments});

  @override
  LiveQueueDashboardViewState createState() => LiveQueueDashboardViewState();
}

class LiveQueueDashboardViewState extends State<LiveQueueDashboardView> {
  DateTime _calendarSelectedDate = DateTime.now();
  DateTime _calendarFocusedDay = DateTime.now();
  List<Appointment> _allAppointmentsForCalendar = [];
  List<Appointment> _dailyAppointmentsForDisplay = [];
  
  // Separate state for walk-in queue and appointments
  List<ActivePatientQueueItem> _walkInQueueItems = [];
  List<Appointment> _appointmentsForSelectedDate = [];
  bool _isLoadingQueueAndAppointments = true;
  
  Timer? _refreshTimer;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    if (kDebugMode) {
      print('DEBUG: LiveQueueDashboardView initState START');
    }
    super.initState();
    if (kDebugMode) {
      print('DEBUG: LiveQueueDashboardView initState calling _loadAppointments and _loadCombinedQueueData');
    }
    _loadAppointments().then((_) {
      _loadCombinedQueueData(_calendarSelectedDate);
    });
    
    // Set up periodic refresh every 10 seconds for better responsiveness
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadCombinedQueueData(_calendarSelectedDate);
      }
    });
    
    // Set up sync listener for real-time updates
    _setupSyncListener();
    
    if (kDebugMode) {
      print('DEBUG: LiveQueueDashboardView initState END');
    }
  }

  /// Setup sync listener for real-time updates
  void _setupSyncListener() {
    _syncSubscription = DatabaseSyncClient.syncUpdates.listen((updateEvent) {
      if (!mounted) return;
      
      // Handle different types of sync events
      switch (updateEvent['type']) {
        case 'remote_change_applied':
        case 'database_change':
          final change = updateEvent['change'] as Map<String, dynamic>?;
          if (change != null && (change['table'] == 'active_patient_queue' || 
                                change['table'] == 'appointments')) {
            // Refresh data on queue/appointment updates
            _loadCombinedQueueData(_calendarSelectedDate);
          }
          break;
          
        case 'queue_change_immediate':
        case 'force_queue_refresh':
          // Immediate queue refresh
          _loadCombinedQueueData(_calendarSelectedDate);
          break;
          
        case 'appointment_change_immediate':
          // Immediate appointment refresh
          _loadAppointments().then((_) => _loadCombinedQueueData(_calendarSelectedDate));
          break;
          
        case 'ui_refresh_requested':
          // Periodic UI refresh from sync client
          _loadCombinedQueueData(_calendarSelectedDate);
          break;
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    if (kDebugMode) {
      print('DEBUG: LiveQueueDashboardView _loadAppointments START');
    }
    try {
      final appointments = await ApiService.getAllAppointments();
      if (mounted) {
        setState(() {
          _allAppointmentsForCalendar = appointments;
          _filterDailyAppointments();
          if (kDebugMode) {
            print('DEBUG: LiveQueueDashboardView _loadAppointments SUCCESS - Loaded ${appointments.length} appointments.');
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: LiveQueueDashboardView _loadAppointments ERROR: $e');
      }
      if (mounted) {
        setState(() {
          _allAppointmentsForCalendar = [];
        });
      }
    }
  }

  Future<void> _loadCombinedQueueData(DateTime selectedDateForQueue) async {
    if (kDebugMode) {
      print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData START for date: ${DateFormat.yMd().format(selectedDateForQueue)}');
    }
    if (!mounted) {
      if (kDebugMode) {
        print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData NOT MOUNTED, returning');
      }
      return;
    }
    setState(() {
      _isLoadingQueueAndAppointments = true;
    });    try {
      final now = DateTime.now();
      final isToday = selectedDateForQueue.year == now.year &&
                      selectedDateForQueue.month == now.month &&
                      selectedDateForQueue.day == now.day;
      
      // Load walk-in patients (for today - active patients only)
      List<ActivePatientQueueItem> walkInQueueItems = [];
      if (isToday) {
        // Get active queue items only (served patients are now removed from active queue)
        final allActiveItems = await widget.queueService.getActiveQueueItems(statuses: ['waiting', 'in_consultation']);
        walkInQueueItems = allActiveItems.where((item) => 
          item.originalAppointmentId == null || 
          item.originalAppointmentId!.isEmpty ||
          item.originalAppointmentId!.trim().isEmpty
        ).toList();
        if (kDebugMode) {
          print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData Fetched ${walkInQueueItems.length} walk-in items for today (active patients only).');
        }
      }
      
      // Load appointments for the selected date (exclude completed and cancelled from active view)
      final appointmentsForSelectedDate = _allAppointmentsForCalendar.where((appt) {
        final appointmentDate = DateTime(appt.date.year, appt.date.month, appt.date.day);
        final selectedDate = DateTime(selectedDateForQueue.year, selectedDateForQueue.month, selectedDateForQueue.day);
        final dateMatches = appointmentDate.isAtSameMomentAs(selectedDate);
        
        // Only show active appointments in the live dashboard (not completed, cancelled, or served)
        final isActiveStatus = appt.status.toLowerCase() != 'completed' && 
                              appt.status.toLowerCase() != 'cancelled' &&
                              appt.status.toLowerCase() != 'served';
        
        // ADDED: Exclude walk-ins from the 'Scheduled Appointments' list
        final isNotWalkIn = appt.consultationType.toLowerCase() != 'walk-in';

        return dateMatches && isActiveStatus && isNotWalkIn;
      }).toList();

      // Sort appointments by time
      appointmentsForSelectedDate.sort((a, b) {
        final aTime = a.time.hour * 60 + a.time.minute;
        final bTime = b.time.hour * 60 + b.time.minute;
        return aTime.compareTo(bTime);
      });

      // Sort walk-in queue items
      walkInQueueItems.sort((a, b) {
        if (a.queueNumber != b.queueNumber) {
          return a.queueNumber.compareTo(b.queueNumber);
        }
        return a.arrivalTime.compareTo(b.arrivalTime);
      });

      if (mounted) {
        setState(() {
          _walkInQueueItems = walkInQueueItems;
          _appointmentsForSelectedDate = appointmentsForSelectedDate;
          _isLoadingQueueAndAppointments = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: LiveQueueDashboardView _loadCombinedQueueData ERROR: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingQueueAndAppointments = false;
        });
      }
    }
  }

  void _filterDailyAppointments() {
    if (!mounted) return;
    setState(() {
      _dailyAppointmentsForDisplay = _allAppointmentsForCalendar
          .where((appt) => isSameDay(appt.date, _calendarSelectedDate))
          .toList();
      _dailyAppointmentsForDisplay.sort((a, b) {
        final aTime = a.time.hour * 60 + a.time.minute;
        final bTime = b.time.hour * 60 + b.time.minute;
        return aTime.compareTo(bTime);
      });
    });
  }

  Future<void> _activateAndCallScheduledPatient(String appointmentId) async {
    if (!mounted) return;
    
    try {
      final originalAppointment = _allAppointmentsForCalendar.firstWhere(
        (appt) => appt.id == appointmentId,
      );

      // Get patient details for better display name
      String patientDisplayName = 'PT: ${originalAppointment.patientId}';
      try {
        final patientDetails = await ApiService.getPatientById(originalAppointment.patientId);
        patientDisplayName = patientDetails.fullName;
      } catch (e) {
        if (kDebugMode) {
          print('DEBUG: Could not fetch patient details for ${originalAppointment.patientId}: $e');
        }
      }

      // Create a new active queue item for the scheduled appointment
      final newQueueItem = ActivePatientQueueItem(
        queueEntryId: 'active_${DateTime.now().millisecondsSinceEpoch}',
        patientId: originalAppointment.patientId,
        patientName: patientDisplayName, 
        arrivalTime: DateTime.now(),
        queueNumber: 0, 
        status: 'in_consultation',
        paymentStatus: originalAppointment.paymentStatus ?? 'Pending',
        conditionOrPurpose: originalAppointment.consultationType,
        selectedServices: originalAppointment.selectedServices,
        totalPrice: originalAppointment.totalPrice,
        createdAt: DateTime.now(),
        originalAppointmentId: originalAppointment.id,
      );

      // Add to active queue and update appointment status
      bool addedToActiveQueue = await widget.queueService.addPatientToQueue(newQueueItem); 

      if (addedToActiveQueue) {
        // Update the appointment status to "In Consultation"
        await ApiService.updateAppointmentStatus(appointmentId, 'In Consultation');          // Update the local appointment list immediately
          setState(() {
            final appointmentIndex = _allAppointmentsForCalendar.indexWhere((appt) => appt.id == appointmentId);
            if (appointmentIndex != -1) {
              _allAppointmentsForCalendar[appointmentIndex] = _allAppointmentsForCalendar[appointmentIndex].copyWith(status: 'In Consultation');
            }
            
            final selectedDateIndex = _appointmentsForSelectedDate.indexWhere((appt) => appt.id == appointmentId);
            if (selectedDateIndex != -1) {
              _appointmentsForSelectedDate[selectedDateIndex] = _appointmentsForSelectedDate[selectedDateIndex].copyWith(status: 'In Consultation');
            }
            
            // Refresh appointments display
            _filterDailyAppointments();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newQueueItem.patientName} is now In Consultation.'),
                backgroundColor: Colors.green,
              ),
            );
            // Reload data to get updated appointment status and queue
            _loadAppointments().then((_) => _loadCombinedQueueData(_calendarSelectedDate));
          }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to activate scheduled appointment.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          print("Error activating scheduled patient: $e");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateQueueItemStatus(ActivePatientQueueItem item, String newStatus) async {
    if (!mounted) return;
    setState(() {
      _isLoadingQueueAndAppointments = true;
    });

    try {
      bool success = await widget.queueService.updatePatientStatusInQueue(item.queueEntryId, newStatus);      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${item.patientName}'s status updated to ${_getDisplayStatus(newStatus)}."),
              backgroundColor: Colors.green,
            ),
          );
          // Reload both appointments and queue data to reflect changes
          _loadAppointments().then((_) => _loadCombinedQueueData(_calendarSelectedDate));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to update status for ${item.patientName}."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          print("Error updating queue item status: $e");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating status: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQueueAndAppointments = false;
        });
      }
    }
  }

  String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting': return 'Waiting';
      case 'in_consultation': return 'In Consultation';
      case 'served': return 'Served';
      case 'removed': return 'Removed';
      case 'scheduled': return 'Scheduled (Today)';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting': return Colors.orange.shade700;
      case 'in_consultation': return Colors.blue.shade700;
      case 'served': return Colors.green.shade700;
      case 'removed': return Colors.red.shade700;
      case 'scheduled': return Colors.purple.shade400;
      default: return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DashboardWelcomeSection(),
                const DashboardMetricsSection(),
                const DashboardDoctorsSection(),
                const SizedBox(height: 16),
                LiveQueueDisplaySection(
                  calendarSelectedDate: _calendarSelectedDate,
                  isLoadingQueueAndAppointments: _isLoadingQueueAndAppointments,
                  walkInQueueItems: _walkInQueueItems,
                  appointmentsForSelectedDate: _appointmentsForSelectedDate,
                  onActivateAppointment: _activateAndCallScheduledPatient,
                  onUpdateQueueItemStatus: _updateQueueItemStatus,
                  getDisplayStatus: _getDisplayStatus,
                  getStatusColor: _getStatusColor,
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[50],
            child: SingleChildScrollView(
              child: DashboardCalendarSection(
                calendarSelectedDate: _calendarSelectedDate,
                calendarFocusedDay: _calendarFocusedDay,
                allAppointmentsForCalendar: _allAppointmentsForCalendar,
                dailyAppointmentsForDisplay: _dailyAppointmentsForDisplay,
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_calendarSelectedDate, selectedDay)) {
                    setState(() {
                      _calendarSelectedDate = selectedDay;
                      _calendarFocusedDay = focusedDay;
                      _filterDailyAppointments();
                      _loadCombinedQueueData(selectedDay);
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _calendarFocusedDay = focusedDay;
                  });
                },
                onMonthSelected: (monthIndex) {
                  setState(() {
                    _calendarSelectedDate = DateTime(
                        _calendarSelectedDate.year,
                        monthIndex + 1,
                        _calendarSelectedDate.day);
                    _calendarFocusedDay = _calendarSelectedDate;
                    _filterDailyAppointments();
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
