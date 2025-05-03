import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/search/search_hub_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/screens/patient/patient_queue_hub_screen.dart';
import 'package:flutter_application_1/screens/analytics/patient_analytics_screen.dart';
import 'package:flutter_application_1/screens/reports/report_hub_screen.dart';
import 'package:flutter_application_1/screens/billing/billing_hub_screen.dart';
import 'package:flutter_application_1/screens/payment/payment_hub_screen.dart';
import 'package:flutter_application_1/screens/maintenance/maintenance_hub_screen.dart';
import 'package:flutter_application_1/screens/help/help_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String accessLevel;

  DashboardScreen({required this.accessLevel});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 2; // Default to Appointment module
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = [];
  bool _isAddingAppointment = false;
  final _appointmentFormKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    // Mock data
    _appointments = [
      Appointment(
        id: '1',
        patientName: 'John Doe',
        patientId: 'PT-1001',
        date: DateTime.now(),
        time: TimeOfDay(hour: 9, minute: 0),
        doctor: 'Dr. Smith',
        status: 'Confirmed',
      ),
      Appointment(
        id: '2',
        patientName: 'Jane Smith',
        patientId: 'PT-1002',
        date: DateTime.now(),
        time: TimeOfDay(hour: 11, minute: 30),
        doctor: 'Dr. Johnson',
        status: 'Pending',
      ),
      Appointment(
        id: '3',
        patientName: 'Robert Brown',
        patientId: 'PT-1003',
        date: DateTime.now().add(Duration(days: 1)),
        time: TimeOfDay(hour: 14, minute: 0),
        doctor: 'Dr. Smith',
        status: 'Confirmed',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Record Management', 
          style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.person, color: Colors.white),
            onSelected: (value) {
              // Handle profile actions
            },
            itemBuilder: (BuildContext context) {
              return {'Profile', 'Settings', 'Logout'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[700]!, Colors.teal[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.teal),
                  ),
                  SizedBox(height: 10),
                  Text('Admin User', 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Administrator', 
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.people, 'Registration', 0),
            _buildDrawerItem(Icons.search, 'Search', 1),
            _buildDrawerItem(Icons.calendar_today, 'Appointments', 2),
            _buildDrawerItem(Icons.medical_services, 'Lab Histories', 3),
            _buildDrawerItem(Icons.people_alt, 'Patient Queue', 4),
            _buildDrawerItem(Icons.analytics, 'Patient Analytics', 5),
            _buildDrawerItem(Icons.report, 'Reports', 6),
            _buildDrawerItem(Icons.receipt, 'Billing', 7),
            _buildDrawerItem(Icons.payment, 'Payment', 8),
            _buildDrawerItem(Icons.settings, 'Maintenance', 9),
            _buildDrawerItem(Icons.help, 'Help', 10),
            _buildDrawerItem(Icons.info, 'About', 11),
          ],
        ),
      ),
      body: _buildSelectedModule(),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isAddingAppointment = true;
                  _patientNameController.clear();
                  _patientIdController.clear();
                  _doctorController.clear();
                  _notesController.clear();
                  _selectedTime = TimeOfDay.now();
                });
              },
              child: Icon(Icons.add),
              backgroundColor: Colors.teal[700],
            )
          : null,
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? Colors.teal : Colors.grey[700]),
      title: Text(title, style: TextStyle(
        color: _selectedIndex == index ? Colors.teal : Colors.black,
        fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
      )),
      selected: _selectedIndex == index,
      selectedTileColor: Colors.teal[50],
      onTap: () {
        setState(() {
          _selectedIndex = index;
          Navigator.pop(context);
        });
      },
    );
  }

Widget _buildSelectedModule() {
  switch (_selectedIndex) {
    case 1:
      return SearchHubScreen();
    case 2:
      return _buildAppointmentModule();
    case 4: // Patient Queue module
      return PatientQueueHubScreen(); // Connect the Patient Queue Hub
    case 5:
      return PatientAnalyticsScreen();
    case 6: // Report module
      return ReportHubScreen(); // Connect the Report Hub Screen
    case 7: // Billing module
      return BillingHubScreen(); // Connect the Billing Hub Screen
    case 8: // Payment module
      return PaymentHubScreen(); // Connect the Payment Hub Screen
    case 9: // Maintenance module
      return MaintenanceHubScreen(); // Connect the Maintenance Hub Screen
    case 10: // Help module
      return HelpScreen();
    default:
      return Center(
        child: Text(
          'Module under development',
          style: TextStyle(color: Colors.teal[700], fontSize: 18),
        ),
      );
  }
}

  Widget _buildAppointmentModule() {
    final filteredAppointments = _appointments
        .where((appt) =>
            appt.date.year == _selectedDate.year &&
            appt.date.month == _selectedDate.month &&
            appt.date.day == _selectedDate.day)
        .toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appointment Schedule',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDatePicker(),
                icon: Icon(Icons.calendar_today),
                label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
              ),
            ],
          ),
        ),
        if (_isAddingAppointment) _buildAddAppointmentForm(),
        Expanded(
          child: filteredAppointments.isEmpty
              ? Center(child: Text('No appointments for selected date'))
              : ListView.builder(
                  itemCount: filteredAppointments.length,
                  itemBuilder: (context, index) {
                    final appointment = filteredAppointments[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(appointment.patientName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${appointment.patientId}'),
                            Text(
                                'Time: ${appointment.time.format(context)} with ${appointment.doctor}'),
                            Text('Status: ${appointment.status}'),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: Text('Edit'),
                              value: 'edit',
                            ),
                            PopupMenuItem(
                              child: Text('Cancel'),
                              value: 'cancel',
                            ),
                            PopupMenuItem(
                              child: Text('Complete'),
                              value: 'complete',
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              setState(() {
                                _isAddingAppointment = true;
                                _patientNameController.text =
                                    appointment.patientName;
                                _patientIdController.text =
                                    appointment.patientId;
                                _doctorController.text = appointment.doctor;
                                _selectedTime = appointment.time;
                                _selectedDate = appointment.date;
                                // Remove the old appointment
                                _appointments.remove(appointment);
                              });
                            } else if (value == 'cancel') {
                              setState(() {
                                _appointments.remove(appointment);
                              });
                            } else if (value == 'complete') {
                              setState(() {
                                _appointments[_appointments
                                        .indexOf(appointment)] =
                                    appointment.copyWith(status: 'Completed');
                              });
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddAppointmentForm() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _appointmentFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _patientNameController.text.isEmpty
                    ? 'Add New Appointment'
                    : 'Edit Appointment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _patientNameController,
                decoration: InputDecoration(
                  labelText: 'Patient Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter patient name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _patientIdController,
                decoration: InputDecoration(
                  labelText: 'Patient ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter patient ID';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _doctorController,
                decoration: InputDecoration(
                  labelText: 'Doctor',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter doctor name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isAddingAppointment = false;
                      });
                    },
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_appointmentFormKey.currentState!.validate()) {
                        setState(() {
                          _appointments.add(Appointment(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            patientName: _patientNameController.text,
                            patientId: _patientIdController.text,
                            date: _selectedDate,
                            time: _selectedTime,
                            doctor: _doctorController.text,
                            status: 'Confirmed',
                          ));
                          _isAddingAppointment = false;
                        });
                      }
                    },
                    child: Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
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

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}

class Appointment {
  final String id;
  final String patientName;
  final String patientId;
  final DateTime date;
  final TimeOfDay time;
  final String doctor;
  final String status;

  Appointment({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.date,
    required this.time,
    required this.doctor,
    required this.status,
  });

  Appointment copyWith({
    String? id,
    String? patientName,
    String? patientId,
    DateTime? date,
    TimeOfDay? time,
    String? doctor,
    String? status,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      time: time ?? this.time,
      doctor: doctor ?? this.doctor,
      status: status ?? this.status,
    );
  }
}