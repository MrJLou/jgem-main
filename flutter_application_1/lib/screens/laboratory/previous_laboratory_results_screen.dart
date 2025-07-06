import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/clinic_service.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/queue_service.dart';
import 'package:flutter_application_1/utils/string_utils.dart';
import 'package:intl/intl.dart';

class PreviousLaboratoryResultsScreen extends StatefulWidget {
  const PreviousLaboratoryResultsScreen({super.key});

  @override
  PreviousLaboratoryResultsScreenState createState() =>
      PreviousLaboratoryResultsScreenState();
}

class LabResultDataSource extends DataTableSource {
  List<Map<String, dynamic>> _results;
  final BuildContext context;
  final Function(Map<String, dynamic>) onViewDetails;

  LabResultDataSource(this._results, this.context, this.onViewDetails);

  void _showLabHistoryDialog(BuildContext context, String patientId) {
    // Get access to the dialog context's ScaffoldMessenger
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fetching patient lab history...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Call the proper method on the parent screen
    if (context
            .findAncestorStateOfType<PreviousLaboratoryResultsScreenState>() !=
        null) {
      context
          .findAncestorStateOfType<PreviousLaboratoryResultsScreenState>()!
          ._showLabHistoryDialog(patientId);
    }
  }

  void updateData(List<Map<String, dynamic>> newResults) {
    _results = newResults;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final result = _results[index];
    return DataRow(cells: [
      DataCell(Text(result['patientName'] ?? 'N/A')),
      DataCell(Text(result['test'] ?? 'N/A')),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getCategoryColor(result['category']),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            result['category'] ?? 'General',
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
      ),
      DataCell(Text(result['doctor'] ?? 'N/A')),
      DataCell(Text(result['date']?.split(' ')[0] ?? 'N/A')),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(result['status']),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            result['status'] ?? 'N/A',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.teal),
              onPressed: () => onViewDetails(result),
              tooltip: 'View Details',
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.indigo),
              onPressed: () {
                // Show patient's lab history
                _showLabHistoryDialog(context, result['patientId']);
              },
              tooltip: 'View History',
            ),
          ],
        ),
      ),
    ]);
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'hematology':
        return Colors.red;
      case 'chemistry':
      case 'laboratory':
        return Colors.blue;
      case 'urinalysis':
        return Colors.yellow[700]!;
      case 'microbiology':
        return Colors.green;
      case 'radiology':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'abnormal':
        return Colors.red;
      case 'borderline':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.black54;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _results.length;

  @override
  int get selectedRowCount => 0;

  void sort<T>(
      Comparable<T> Function(Map<String, dynamic> d) getField, bool ascending) {
    _results.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    notifyListeners();
  }
}

class PreviousLaboratoryResultsScreenState
    extends State<PreviousLaboratoryResultsScreen> {
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();
  late LabResultDataSource _dataSource;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _dataSource = LabResultDataSource([], context, _showResultDetails);
    _fetchAllResults();
    _searchController.addListener(_filterResults);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterResults);
    _searchController.dispose();
    super.dispose();
  }

  void _fetchAllResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all necessary data with proper error handling
      final patientsData = await _dbHelper.patientDbService.getPatients();
      final usersData = await _dbHelper.userDbService.getUsers();
      final appointments = await _dbHelper.getAllAppointments();

      // Create comprehensive patient and doctor maps for quick lookup
      final patientMap = <String, Patient>{};
      for (var p in patientsData) {
        try {
          final patient = Patient.fromJson(p);
          patientMap[patient.id] = patient;
        } catch (e) {
          debugPrint('Error parsing patient data for ${p['id']}: $e');
        }
      }

      final doctorMap = <String, User>{};
      for (var u in usersData) {
        try {
          if (u.role.toLowerCase() == 'doctor') {
            doctorMap[u.id] = u;
          }
        } catch (e) {
          debugPrint('Error processing doctor data for ${u.id}: $e');
        }
      }

      final transformedResults = <Map<String, dynamic>>[];
      final processedAppointmentIds = <String>{};
      final processedQueueEntryIds = <String>{}; // To prevent duplicates

      // Define categories that ARE laboratory-related. This list is now the single
      // source of truth for what constitutes a laboratory service.
      const laboratoryCategories = {
        'laboratory',
        'radiology',
        'hematology',
        'chemistry',
        'urinalysis',
        'microbiology',
        'pathology'
      };

      // 1. Process Paid Items from the Active Patient Queue for real-time results
      final db = await _dbHelper.database;
      // Note: In a real-world scenario, you might query a historical table instead.
      // Here, we check the active queue for simplicity, assuming paid items remain
      // until fully processed or archived overnight.
      final paidQueueItems = await db.query(
        'active_patient_queue',
        where: "status = 'done' OR paymentStatus = 'Paid'",
      );

      for (final item in paidQueueItems) {
        final queueItem = ActivePatientQueueItem.fromJson(item);
        if (processedQueueEntryIds.contains(queueItem.queueEntryId)) continue;

        // Find all laboratory services for this queue item
        final labServices = queueItem.selectedServices?.where((service) {
          final category = (service['category'] as String? ?? '').toLowerCase();
          return laboratoryCategories.contains(category);
        }).toList();

        // If there are lab services, create a single consolidated record for them
        if (labServices != null && labServices.isNotEmpty) {
          final patient = patientMap[queueItem.patientId];
          if (patient == null) continue;

          final doctor = doctorMap[queueItem.doctorId];
          final doctorName = doctor != null
              ? 'Dr. ${doctor.fullName}'
              : (queueItem.doctorName ?? 'Attending');

          // Consolidate service names into one string
          final testNames = labServices
              .map((s) =>
                  s['serviceName'] as String? ??
                  s['name'] as String? ??
                  'Lab Test')
              .join(', ');

          // Use the category of the first lab service for display, or default to 'Laboratory'
          final displayCategory =
              labServices.first['category'] as String? ?? 'Laboratory';

          transformedResults.add({
            'id': queueItem.queueEntryId,
            'patientName': patient.fullName,
            'patientId': patient.id,
            'date':
                DateFormat('yyyy-MM-dd HH:mm').format(queueItem.arrivalTime),
            'test': testNames, // The consolidated list of tests
            'testType': 'Paid Service',
            'doctor': doctorName,
            'doctorId': queueItem.doctorId,
            'result': {
              'Status': 'Payment confirmed. Results pending or to be uploaded.'
            },
            'status': 'Completed',
            'notes': queueItem.conditionOrPurpose ??
                'Services paid via walk-in queue.',
            'category': displayCategory, // Use a representative category
            'diagnosis': '',
            'rawLabResults':
                'This service was processed through the patient queue.',
            'patient': patient,
            'doctorUser': doctor,
            'isFromAppointment': !queueItem.isWalkIn,
          });
        }

        // Mark this queue entry as processed to avoid duplicates from other sources
        processedQueueEntryIds.add(queueItem.queueEntryId);
        // If it's linked to an appointment, mark that too
        if (queueItem.originalAppointmentId != null &&
            queueItem.originalAppointmentId!.isNotEmpty) {
          processedAppointmentIds.add(queueItem.originalAppointmentId!);
        }
      }

      // 2. Process appointments to find and extract all lab-related services
      for (final appt in appointments) {
        if (processedAppointmentIds.contains(appt.id)) {
          continue; // Skip if already handled via the paid queue item logic
        }

        if (!['completed', 'served', 'finished']
            .contains(appt.status.toLowerCase())) {
          continue;
        }

        final labServices = appt.selectedServices.where((service) {
          final category = (service['category'] as String? ?? '').toLowerCase();
          return laboratoryCategories.contains(category);
        }).toList();

        if (labServices.isNotEmpty) {
          processedAppointmentIds.add(appt.id);
          final patient = patientMap[appt.patientId];
          if (patient == null) continue;

          final doctor = doctorMap[appt.doctorId];
          final doctorName =
              doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor';

          // Consolidate service names into one string
          final testNames = labServices
              .map((s) => s['serviceName'] ?? s['name'] ?? 'Laboratory Test')
              .join(', ');

          final displayCategory =
              labServices.first['category'] as String? ?? 'Laboratory';

          transformedResults.add({
            'id': appt.id,
            'patientName': patient.fullName,
            'patientId': patient.id,
            'date': DateFormat('yyyy-MM-dd HH:mm').format(appt.date),
            'test': testNames,
            'testType': 'Appointment Service',
            'doctor': doctorName,
            'doctorId': appt.doctorId,
            'result': {'Status': 'Test completed during consultation'},
            'status': 'Completed',
            'notes': appt.notes ?? 'Performed during consultation',
            'category': displayCategory,
            'diagnosis': '',
            'rawLabResults': 'Service performed during appointment',
            'patient': patient,
            'doctorUser': doctor,
            'isFromAppointment': true,
          });
        }
      }

      // 3. Also process existing medical records with recordType = 'laboratory'
      try {
        final db = await _dbHelper.database;
        final labMedicalRecords = await db.query(
          'medical_records',
          where: "recordType = ?",
          whereArgs: ["laboratory"],
          orderBy: "recordDate DESC"
        );

        for (final record in labMedicalRecords) {
          final patientId = record['patientId'] as String?;
          if (patientId == null) continue;
          
          final patient = patientMap[patientId];
          if (patient == null) continue;

          final doctorId = record['doctorId'] as String?;
          final doctor = doctorId != null ? doctorMap[doctorId] : null;
          
          // Try to parse lab results
          Map<String, dynamic> parsedResults = {};
          String testName = 'Laboratory Tests';
          String category = 'Laboratory';
          String status = 'Completed';
          
          try {
            if (record['labResults'] != null && (record['labResults'] as String).isNotEmpty) {
              try {
                final labData = jsonDecode(record['labResults'] as String);
                
                // Handle both old and new format of lab results
                if (labData is Map) {
                  if (labData.containsKey('results')) {
                    // New structured format with results key
                    parsedResults = labData['results'] as Map<String, dynamic>? ?? {};
                    testName = labData['testName'] as String? ?? 'Laboratory Tests';
                    category = labData['category'] as String? ?? 'Laboratory';
                    status = labData['status'] as String? ?? 'Completed';
                  } else if (labData.containsKey('testName') || labData.containsKey('category')) {
                    // Structured format but results might be directly in the Map
                    // This handles cases where 'results' key might be missing
                    testName = labData['testName'] as String? ?? 'Laboratory Tests';
                    category = labData['category'] as String? ?? 'Laboratory';
                    status = labData['status'] as String? ?? 'Completed';
                    
                    // Try to find results data
                    if (labData.keys.any((key) => key != 'testName' && key != 'category' && 
                                               key != 'status' && key != 'date' && key != 'queueId')) {
                      // Extract all fields that might contain results
                      for (final key in labData.keys) {
                        if (key != 'testName' && key != 'category' && 
                            key != 'status' && key != 'date' && key != 'queueId') {
                          if (labData[key] is Map) {
                            parsedResults.addAll(labData[key] as Map<String, dynamic>);
                          } else if (labData[key] is String || labData[key] is num) {
                            parsedResults[key] = labData[key].toString();
                          }
                        }
                      }
                    }
                  } else {
                    // Old direct format - assume the entire map is result values
                    parsedResults = Map<String, dynamic>.from(labData);
                  }
                }
              } catch (e) {
                debugPrint('JSON parsing error in lab results: $e');
                // Fallback for invalid JSON
                parsedResults = {'Error': 'Could not parse lab results properly'};
              }
            }
          } catch (e) {
            debugPrint('Error parsing lab results JSON: $e');
          }

          transformedResults.add({
            'id': record['id'],
            'patientName': patient.fullName,
            'patientId': patientId,
            'date': DateFormat('yyyy-MM-dd HH:mm').format(
              DateTime.tryParse(record['recordDate'] as String) ?? DateTime.now()
            ),
            'test': testName, // Use parsed test name
            'testType': 'Medical Record',
            'doctor': doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor',
            'doctorId': doctorId,
            'result': parsedResults.isNotEmpty ? parsedResults : {'Status': 'Results available in medical record'},
            'status': status, // Use parsed status
            'notes': record['notes'] as String? ?? '',
            'category': category, // Use parsed category
            'diagnosis': record['diagnosis'] as String? ?? '',
            'rawLabResults': record['labResults'] as String? ?? '',
            'patient': patient,
            'doctorUser': doctor,
            'isFromMedicalRecord': true,
          });
        }
      } catch (e) {
        debugPrint('Error processing laboratory medical records: $e');
      }

      // Sort by date (newest first)
      transformedResults
          .sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      if (!mounted) return;
      setState(() {
        _allResults = transformedResults;
        _filteredResults = transformedResults;
        _dataSource.updateData(_filteredResults);
        _isLoading = false;
      });

      debugPrint('Loaded ${transformedResults.length} laboratory records');
    } catch (e) {
      debugPrint('Error fetching laboratory results: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load laboratory data. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _filterResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredResults = _allResults.where((result) {
        final patientName =
            (result['patientName'] as String?)?.toLowerCase() ?? '';
        final testName = (result['test'] as String?)?.toLowerCase() ?? '';
        final doctorName = (result['doctor'] as String?)?.toLowerCase() ?? '';
        final category = (result['category'] as String?)?.toLowerCase() ?? '';
        final status = (result['status'] as String?)?.toLowerCase() ?? '';
        final diagnosis = (result['diagnosis'] as String?)?.toLowerCase() ?? '';
        final notes = (result['notes'] as String?)?.toLowerCase() ?? '';

        return patientName.contains(query) ||
            testName.contains(query) ||
            doctorName.contains(query) ||
            category.contains(query) ||
            status.contains(query) ||
            diagnosis.contains(query) ||
            notes.contains(query);
      }).toList();
      _dataSource.updateData(_filteredResults);
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });

    _dataSource.sort<String>((d) {
      switch (columnIndex) {
        case 0:
          return d['patientName'] as String;
        case 1:
          return d['test'] as String;
        case 2:
          return d['category'] as String;
        case 3:
          return d['doctor'] as String;
        case 4:
          return d['date'] as String;
        case 5:
          return d['status'] as String;
        default:
          return '';
      }
    }, ascending);
  }

  void _showResultDetails(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.science, color: Colors.teal[700]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['test'],
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColorForDialog(result['category']),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          result['category'] ?? 'General',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColorForDialog(result['status']),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          result['status'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Information Section
                _buildSectionHeader('Patient Information'),
                _buildDetailRow('Patient Name', result['patientName']),
                _buildDetailRow(
                    'Patient ID',
                    StringUtils.formatIdForDisplay(
                        result['patientId']?.toString())),

                const SizedBox(height: 16),

                // Test Information Section
                _buildSectionHeader('Test Information'),
                _buildDetailRow('Test Name', result['test']),
                _buildDetailRow('Test Type', result['testType'] ?? 'N/A'),
                _buildDetailRow('Date & Time', result['date']),
                _buildDetailRow('Requesting Doctor', result['doctor']),
                _buildDetailRow('Status', result['status']),

                const SizedBox(height: 16),

                // Results Section
                _buildSectionHeader('Test Results'),
                ...(result['result'] as Map<String, dynamic>).entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${entry.key}:',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: Colors.grey[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                const SizedBox(height: 16),

                // Additional Information Section
                _buildSectionHeader('Additional Information'),
                if (result['diagnosis'] != null &&
                    result['diagnosis'].isNotEmpty)
                  _buildDetailRow('Diagnosis', result['diagnosis']),
                _buildDetailRow('Notes', result['notes']),

                if (result['isFromAppointment'] == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This test was performed during a consultation appointment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: Colors.teal[700])),
          ),
        ],
      ),
    );
  }

  // Adding missing method
  void _showLabHistoryDialog(String patientId) async {
    final patientData = await _dbHelper.getPatient(patientId);
    if (patientData == null || !mounted) return;

    final patient = Patient.fromJson(patientData);

    // Get all lab results for this patient
    try {
      final allResults =
          _allResults.where((r) => r['patientId'] == patientId).toList();
      allResults.sort((a, b) {
        final aDate = a['date'] as String? ?? '';
        final bDate = b['date'] as String? ?? '';
        return bDate.compareTo(aDate); // Newest first
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lab History for ${patient.fullName}'),
          content: Container(
            width: 600 < MediaQuery.of(context).size.width * 0.9
                ? 600
                : MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(8),
            child: allResults.isEmpty
                ? const Center(
                    child:
                        Text('No laboratory history found for this patient.'))
                : ListView.builder(
                    itemCount: allResults.length,
                    itemBuilder: (context, index) {
                      final result = allResults[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(result['test'] ?? 'Unknown Test'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Date: ${result['date']?.split(' ')[0] ?? 'N/A'}'),
                              Text('Doctor: ${result['doctor'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  result['status'] ?? 'N/A',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor:
                                    _getStatusColorForDialog(result['status']),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEditResultDialog(result);
                                },
                                tooltip: 'Edit Result',
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showResultDetails(result);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading lab history: $e')),
      );
    }
  }

  void _showEditResultDialog(Map<String, dynamic> result) {
    final testController = TextEditingController(text: result['test'] ?? '');
    final notesController = TextEditingController(text: result['notes'] ?? '');
    final diagnosisController =
        TextEditingController(text: result['diagnosis'] ?? '');

    // Extract current result values - handle both new and old formats with enhanced parsing
    Map<String, dynamic> currentResults = {};
    if (result['result'] is Map<String, dynamic>) {
      // Direct results or already processed
      currentResults = result['result'] as Map<String, dynamic>;
    } else if (result['rawLabResults'] != null) {
      // Try to parse from raw JSON
      try {
        final rawData = result['rawLabResults'];
        final parsedData = rawData is String ? jsonDecode(rawData) : rawData;
        
        if (parsedData is Map) {
          if (parsedData.containsKey('results')) {
            // New structured format
            currentResults = parsedData['results'] as Map<String, dynamic>? ?? {};
          } else if (parsedData.containsKey('testName') || parsedData.containsKey('category')) {
            // Structured format but results might be directly in the Map
            // Look for fields that might contain test results
            for (final key in parsedData.keys) {
              if (key != 'testName' && key != 'category' && 
                  key != 'status' && key != 'date' && key != 'queueId') {
                if (parsedData[key] is Map) {
                  currentResults.addAll(parsedData[key] as Map<String, dynamic>);
                } else if (parsedData[key] is String || parsedData[key] is num) {
                  currentResults[key] = parsedData[key].toString();
                }
              }
            }
          } else {
            // Old format - assume the entire map contains results
            currentResults = Map<String, dynamic>.from(parsedData);
          }
        }
      } catch (e) {
        debugPrint('Error parsing raw lab results: $e');
      }
    }
    
    final resultControllers = <String, TextEditingController>{};

    for (final entry in currentResults.entries) {
      resultControllers[entry.key] =
          TextEditingController(text: entry.value?.toString() ?? '');
    }

    String selectedStatus = result['status'] ?? 'Pending';
    String selectedCategory = result['category'] ?? 'Laboratory';

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                title: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.teal[700]),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Edit Laboratory Result',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information Section
                        _buildSectionHeader('Basic Information'),
                        TextField(
                          controller: testController,
                          decoration: const InputDecoration(
                            labelText: 'Test Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            'Laboratory',
                            'Hematology',
                            'Chemistry',
                            'Urinalysis',
                            'Microbiology',
                            'Radiology',
                            'Pathology'
                          ]
                              .map((category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Status Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            'Pending',
                            'Completed',
                            'Normal',
                            'Abnormal',
                            'Borderline',
                            'Cancelled'
                          ]
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Test Results Section
                        _buildSectionHeader('Test Results'),
                        ...resultControllers.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: entry.value,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Enter ${entry.key.toLowerCase()}',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        resultControllers.remove(entry.key);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            )),

                        // Add new result field button
                        TextButton.icon(
                          onPressed: () {
                            final key =
                                'New Field ${resultControllers.length + 1}';
                            setState(() {
                              resultControllers[key] = TextEditingController();
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Result Field'),
                        ),

                        const SizedBox(height: 16),

                        // Additional Information Section
                        _buildSectionHeader('Additional Information'),
                        TextField(
                          controller: diagnosisController,
                          decoration: const InputDecoration(
                            labelText: 'Diagnosis',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _saveEditedResult(
                        result,
                        testController.text,
                        selectedCategory,
                        selectedStatus,
                        resultControllers,
                        diagnosisController.text,
                        notesController.text,
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                    ),
                    child: const Text('Save Changes',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ));
  }

  Future<void> _saveEditedResult(
    Map<String, dynamic> originalResult,
    String testName,
    String category,
    String status,
    Map<String, TextEditingController> resultControllers,
    String diagnosis,
    String notes,
  ) async {
    try {
      // Prepare updated results map
      final updatedResults = <String, dynamic>{};
      for (final entry in resultControllers.entries) {
        if (entry.value.text.isNotEmpty) {
          updatedResults[entry.key] = entry.value.text;
        }
      }

      // Create updated result map
      final updatedResult = Map<String, dynamic>.from(originalResult);
      updatedResult['test'] = testName;
      updatedResult['category'] = category;
      updatedResult['status'] = status;
      updatedResult['result'] = updatedResults;
      updatedResult['diagnosis'] = diagnosis; // Already non-null from controller
      updatedResult['notes'] = notes; // Already non-null from controller
      updatedResult['treatment'] = ''; // Add required fields with empty strings
      updatedResult['prescription'] = ''; // Add required fields with empty strings
      updatedResult['updatedAt'] = DateTime.now().toIso8601String();

      // Update in database - this depends on the data source
      // For queue items
      if (originalResult['id'] != null &&
          originalResult['id'].toString().startsWith('entry-')) {
        // This is a queue item - update the queue
        await _updateQueueItemResult(originalResult['id'], updatedResult);
      } else {
        // This is from appointments or medical records - update accordingly
        await _updateMedicalRecordResult(originalResult['id'], updatedResult);
      }

      // Update local data
      final index =
          _allResults.indexWhere((r) => r['id'] == originalResult['id']);
      if (index != -1) {
        setState(() {
          _allResults[index] = updatedResult;
          _filterResults(); // Refresh filtered results
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laboratory result updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating result: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateQueueItemResult(
      String queueId, Map<String, dynamic> updatedResult) async {
    // Update the queue item with new laboratory results
    // Create a medical record entry for the updated results
    final now = DateTime.now();
    
    // Extract the service ID if available
    String? serviceId;
    if (updatedResult['category'] != null) {
      try {
        // Look up service by category
        final services = await _dbHelper.getClinicServices();
        final matchingService = services.firstWhere(
          (service) => service.category?.toLowerCase() == updatedResult['category'].toString().toLowerCase(),
          orElse: () => ClinicService(
            id: '', 
            serviceName: ''
          ),
        );
        serviceId = matchingService.id.isNotEmpty ? matchingService.id : null;
      } catch (e) {
        debugPrint('Error finding service ID for category: ${e.toString()}');
      }
    }
    
    final medicalRecord = {
      'id': 'lab-result-${now.millisecondsSinceEpoch}',
      'patientId': updatedResult['patientId'],
      'appointmentId': null, // Set to null as it's from lab, not appointment
      'serviceId': serviceId, // Use the matched service ID if found
      'recordType': 'laboratory', // Use lowercase to match existing records
      'recordDate': now.toIso8601String(),
      'doctorId': updatedResult['doctorId'] ?? 'system', // Ensure doctorId is present
      'diagnosis': updatedResult['diagnosis'] ?? '',
      'treatment': '', // Empty string for optional text fields
      'prescription': '', // Empty string for optional text fields
      'notes': updatedResult['notes'] ?? '',
      'labResults': jsonEncode({
        'testName': updatedResult['test'] ?? 'Laboratory Test',
        'category': updatedResult['category'] ?? 'Laboratory',
        'status': updatedResult['status'] ?? 'Completed',
        'results': updatedResult['result'] ?? {},
        'date': updatedResult['date'] ?? now.toIso8601String(),
        'queueId': queueId, // Store queue ID reference for traceability
      }),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _dbHelper.insertMedicalRecord(medicalRecord);
    
    // Now mark the laboratory test as completed in the queue
    // This will update the queue item status to 'done' only if it's already paid
    final queueService = QueueService();
    if (queueId.startsWith('entry-')) {
      // Extract the actual queue entry ID if necessary
      final actualQueueId = queueId.startsWith('entry-') ? queueId : queueId;
      
      try {
        final success = await queueService.markLabResultCompleted(actualQueueId);
        if (success) {
          debugPrint('Successfully marked lab results as completed and updated queue status');
        } else {
          debugPrint('Failed to update queue status after completing lab results');
        }
      } catch (e) {
        debugPrint('Error updating queue status after lab result completion: $e');
      }
    }
  }

  Future<void> _updateMedicalRecordResult(
      String recordId, Map<String, dynamic> updatedResult) async {
    // Update existing medical record
    final now = DateTime.now();
    
    // Extract the service ID if available
    String? serviceId;
    if (updatedResult['category'] != null) {
      try {
        // Look up service by category
        final services = await _dbHelper.getClinicServices();
        final matchingService = services.firstWhere(
          (service) => service.category?.toLowerCase() == updatedResult['category'].toString().toLowerCase(),
          orElse: () => ClinicService(
            id: '', 
            serviceName: ''
          ),
        );
        serviceId = matchingService.id.isNotEmpty ? matchingService.id : null;
      } catch (e) {
        debugPrint('Error finding service ID for category: ${e.toString()}');
      }
    }
    
    // For updating records, we need to ensure all required fields are present
    // and follow the same format as insertMedicalRecord to avoid SQL errors
    final medicalRecord = {
      'id': recordId,
      'serviceId': serviceId, // Link to appropriate service if found
      'recordType': 'laboratory', // Use lowercase to match existing records
      'notes': updatedResult['notes'] ?? '',
      'diagnosis': updatedResult['diagnosis'] ?? '',
      'treatment': '', // Add empty string for optional text fields to match schema
      'prescription': '', // Add empty string for optional text fields to match schema
      'labResults': jsonEncode({
        'testName': updatedResult['test'] ?? 'Laboratory Test',
        'category': updatedResult['category'] ?? 'Laboratory',
        'status': updatedResult['status'] ?? 'Completed',
        'results': updatedResult['result'] ?? {},
        'date': updatedResult['date'] ?? now.toIso8601String(),
        'queueId': updatedResult['id'], // Store queue ID in the JSON data instead of as a column
      }), // Store structured lab result data with consistent format
      'updatedAt': now.toIso8601String(),
    };

    await _dbHelper.updateMedicalRecord(medicalRecord);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Laboratory Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        actions: [
          if (!_isLoading && _allResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredResults.length} records',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Loading laboratory results...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAllResults,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _allResults.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No laboratory results found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Completed laboratory tests will appear here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.science,
                                          color: Colors.teal[700], size: 24),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Laboratory Records',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width > 600
                                            ? 400
                                            : double.infinity,
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Search by patient, test, doctor, or status...',
                                        prefixIcon: const Icon(Icons.search,
                                            color: Colors.teal),
                                        suffixIcon: _searchController
                                                .text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  _searchController.clear();
                                                },
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          borderSide: const BorderSide(
                                              color: Colors.teal, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: PaginatedDataTable(
                                      header: null,
                                      rowsPerPage: 8,
                                      showCheckboxColumn: false,
                                      headingRowColor: WidgetStateProperty.all(
                                          Colors.grey[50]),
                                      dataRowMaxHeight: 50,
                                      columnSpacing: 16,
                                      horizontalMargin: 12,
                                      dividerThickness: 1,
                                      columns: [
                                        DataColumn(
                                          label: const Text('Patient',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Test',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Category',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Doctor',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Date',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Status',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        const DataColumn(
                                          label: Text('Actions',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                        ),
                                      ],
                                      source: _dataSource,
                                      sortColumnIndex: _sortColumnIndex,
                                      sortAscending: _sortAscending,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Color _getCategoryColorForDialog(String? category) {
    switch (category?.toLowerCase()) {
      case 'hematology':
        return Colors.red;
      case 'chemistry':
        return Colors.blue;
      case 'urinalysis':
        return Colors.yellow[700]!;
      case 'microbiology':
        return Colors.green;
      case 'radiology':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColorForDialog(String? status) {
    switch (status?.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'abnormal':
        return Colors.red;
      case 'borderline':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.black54;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.teal,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}
