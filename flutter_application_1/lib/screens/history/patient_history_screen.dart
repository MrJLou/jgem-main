import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/appointment.dart';
import 'package:flutter_application_1/models/medical_record.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class PatientHistoryScreen extends StatefulWidget {
  final Patient patient;

  const PatientHistoryScreen({super.key, required this.patient});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  late Future<List<dynamic>> _historyFuture;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchPatientHistory();
    _setupSyncListener();
  }

  void _setupSyncListener() {
    _syncSubscription = DatabaseSyncClient.syncUpdates.listen((updateEvent) {
      if (!mounted) return;
      
      // Handle patient history and appointment changes
      switch (updateEvent['type']) {
        case 'remote_change_applied':
        case 'database_change':
          final change = updateEvent['change'] as Map<String, dynamic>?;
          if (change != null && (change['table'] == 'patient_history' || 
                                change['table'] == 'appointments' ||
                                change['table'] == 'medical_records')) {
            // Refresh history when related data changes
            _refreshHistory();
          }
          break;
        case 'ui_refresh_requested':
          // Periodic refresh for history updates
          if (DateTime.now().millisecondsSinceEpoch % 60000 < 2000) {
            _refreshHistory();
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _refreshHistory() {
    if (mounted) {
      setState(() {
        _historyFuture = _fetchPatientHistory();
      });
    }
  }

  Future<List<dynamic>> _fetchPatientHistory() async {
    final appointments = await ApiService.getPatientAppointments(widget.patient.id);
    final medicalRecords = await ApiService.getPatientMedicalRecords(widget.patient.id);

    List<dynamic> history = [];
    history.addAll(appointments);
    history.addAll(medicalRecords);

    history.sort((a, b) {
      DateTime dateA = a is Appointment ? a.date : (a as MedicalRecord).recordDate;
      DateTime dateB = b is Appointment ? b.date : (b as MedicalRecord).recordDate;
      return dateB.compareTo(dateA);
    });

    return history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History for ${widget.patient.fullName}'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshHistory,
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No history found for this patient.'));
          }

          final history = snapshot.data!;

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              if (item is Appointment) {
                return _buildAppointmentCard(item);
              } else if (item is MedicalRecord) {
                return _buildMedicalRecordCard(item);
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text('Consultation - ${DateFormat.yMMMd().format(appointment.date)}'),
        subtitle: Text(appointment.consultationType),
        trailing: Text(appointment.status),
      ),
    );
  }

  Widget _buildMedicalRecordCard(MedicalRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: const Icon(Icons.science_outlined),
        title: Text('${record.recordType} - ${DateFormat.yMMMd().format(record.recordDate)}'),
        subtitle: Text(record.diagnosis ?? 'No diagnosis'),
      ),
    );
  }
} 