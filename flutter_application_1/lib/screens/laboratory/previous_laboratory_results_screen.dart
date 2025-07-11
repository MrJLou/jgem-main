import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/clinic_service.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/database_helper.dart';
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
  final Function(String) onShowLabHistory;

  LabResultDataSource(this._results, this.context, this.onViewDetails, this.onShowLabHistory);

  void _showLabHistoryDialog(BuildContext context, String patientId) {
    // Call the callback function directly
    try {
      onShowLabHistory(patientId);
    } catch (e) {
      // Fallback - show a simple message if callback fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load lab history. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
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
    _dataSource = LabResultDataSource([], context, _showResultDetails, showLabHistoryDialog);
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

      // NOTE: We skip processing active_patient_queue items for laboratory results
      // CRITICAL: Laboratory results should ONLY come from medical_records table
      // where they were created by medtech via consultation_results_screen
      // Queue items and appointment payment processing should NOT create lab result records

      // 1. Process appointments to find and extract all lab-related services
      // CRITICAL: Only show appointments that have ACTUAL lab results entered
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
          // CRITICAL: Check if actual lab results exist for this appointment
          // Only show appointments where medtech has actually entered lab results
          final existingLabResults = await _dbHelper.getAllMedicalRecords();
          final hasActualLabResults = existingLabResults.any((record) =>
            record['appointmentId'] == appt.id &&
            record['recordType']?.toString().toLowerCase() == 'laboratory' &&
            record['labResults'] != null &&
            record['labResults'].toString().isNotEmpty &&
            record['labResults'] != '{}' && // Not an empty JSON object
            record['labResults'] != 'null' // Not string 'null'
          );

          // Only add to results if actual lab results exist
          // CRITICAL: This prevents showing appointments where payment was made but no lab results entered
          if (hasActualLabResults) {
            processedAppointmentIds.add(appt.id);
            final patient = patientMap[appt.patientId];
            if (patient == null) continue;

            final doctor = doctorMap[appt.doctorId];
            
            // Handle laboratory-only cases for appointments
            String doctorName;
            if (appt.doctorId == 'LAB-ONLY') {
              doctorName = 'Laboratory Only';
            } else if (doctor != null) {
              doctorName = 'Dr. ${doctor.fullName}';
            } else {
              doctorName = 'LAB-ONLY';
            }

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
          } else {
            // Log when we skip appointments without actual lab results
            final patient = patientMap[appt.patientId];
            debugPrint('Skipping appointment ${appt.id} for patient ${patient?.fullName ?? appt.patientId} - no actual lab results found');
          }
        }
      }

      // 2. ONLY process medical records with recordType = 'laboratory' AND actual lab results
      // CRITICAL: Filter out placeholder records created by payment processing
      try {
        final db = await _dbHelper.database;
        final labMedicalRecords = await db.query(
          'medical_records',
          where: "recordType = ? AND labResults IS NOT NULL AND labResults != '' AND labResults != '{}' AND labResults NOT LIKE '%Payment processed%' AND labResults NOT LIKE '%placeholder%'",
          whereArgs: ["laboratory"],
          orderBy: "recordDate DESC"
        );

        // Process records in groups by patient, test, and date to handle duplicates
        final recordGroups = <String, List<Map<String, Object?>>>{};
        
        for (final record in labMedicalRecords) {
          final patientId = record['patientId'] as String?;
          if (patientId == null) continue;
          
          // CRITICAL: Skip records without actual lab results or with placeholder data
          final labResultsStr = record['labResults']?.toString() ?? '';
          if (labResultsStr.isEmpty || 
              labResultsStr == '{}' ||
              labResultsStr == 'null' ||
              labResultsStr.contains('"results":{}') ||
              labResultsStr.contains('"Status":"Payment processed"') ||
              labResultsStr.contains('"Status":"Lab results completed"') ||
              labResultsStr.length < 20) { // Very short JSON strings are likely placeholders
            debugPrint('Skipping medical record ${record['id']} - placeholder or empty lab results');
            continue;
          }
          
          // Additional check: Skip if this is a duplicate from queue processing
          final queueEntryId = record['queueEntryId'] as String?;
          if (queueEntryId != null && processedQueueEntryIds.contains(queueEntryId)) {
            debugPrint('Skipping medical record ${record['id']} - already processed from queue');
            continue;
          }
          
          // Group records by patient and date to handle duplicates
          final recordDate = record['recordDate'] as String?;
          final dateKey = recordDate?.split('T')[0] ?? '';
          final groupKey = '$patientId-$dateKey';
          
          if (!recordGroups.containsKey(groupKey)) {
            recordGroups[groupKey] = [];
          }
          recordGroups[groupKey]!.add(record);
        }

        // Process each group and only keep the best record (LAB-ONLY over Laboratory Only)
        for (final group in recordGroups.values) {
          Map<String, Object?>? bestRecord;
          String bestDoctorType = '';
          bool bestHasActualData = false;
          
          // Find the best record in this group
          for (final record in group) {
            final patientId = record['patientId'] as String?;
            if (patientId == null) continue;
            
            final patient = patientMap[patientId];
            if (patient == null) continue;

            final doctorId = record['doctorId'] as String?;
            final doctor = doctorId != null ? doctorMap[doctorId] : null;
            
            // Determine doctor type for filtering
            String doctorType;
            if (doctorId == null || doctorId.isEmpty || doctorId == 'LAB-ONLY' || doctorId.toLowerCase() == 'system') {
              doctorType = 'Laboratory Only';
            } else if (doctor != null) {
              doctorType = 'Dr. Known';
            } else {
              doctorType = 'LAB-ONLY'; // This indicates medtech entry
            }
            
            // Check if this record has actual lab result data
            bool hasActualResultData = false;
            try {
              if (record['labResults'] != null && (record['labResults'] as String).isNotEmpty) {
                final labData = jsonDecode(record['labResults'] as String);
                if (labData is Map) {
                  if (labData.containsKey('results')) {
                    final resultsData = labData['results'] as Map<String, dynamic>? ?? {};
                    hasActualResultData = resultsData.isNotEmpty && 
                        !resultsData.values.every((value) => 
                            value.toString().toLowerCase().contains('payment') ||
                            value.toString().toLowerCase().contains('placeholder'));
                  } else {
                    // Check if any non-metadata fields contain actual data
                    for (final key in labData.keys) {
                      if (key != 'testName' && key != 'category' && 
                          key != 'status' && key != 'date' && key != 'queueId') {
                        final valueStr = labData[key].toString();
                        if (!valueStr.toLowerCase().contains('payment') && 
                            !valueStr.toLowerCase().contains('placeholder') &&
                            valueStr.isNotEmpty) {
                          hasActualResultData = true;
                          break;
                        }
                      }
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error parsing lab results for record ${record['id']}: $e');
              continue;
            }
            
            // Priority logic: LAB-ONLY with data > Dr. Known with data > Laboratory Only with data > anything without data
            bool shouldReplace = false;
            if (bestRecord == null) {
              shouldReplace = true;
            } else if (hasActualResultData && !bestHasActualData) {
              // Any record with actual data beats one without
              shouldReplace = true;
            } else if (hasActualResultData == bestHasActualData) {
              // Same data status, check doctor type priority
              if (doctorType == 'LAB-ONLY' && bestDoctorType != 'LAB-ONLY') {
                shouldReplace = true;
              } else if (doctorType == 'Dr. Known' && bestDoctorType == 'Laboratory Only') {
                shouldReplace = true;
              }
            }
            
            if (shouldReplace) {
              bestRecord = record;
              bestDoctorType = doctorType;
              bestHasActualData = hasActualResultData;
              debugPrint('Selected best record ${record['id']} with doctor type: $doctorType, hasData: $hasActualResultData');
            } else {
              debugPrint('Skipping record ${record['id']} - not better than current best');
            }
          }
          
          // Process the best record from this group
          if (bestRecord != null && bestHasActualData) {
            final record = bestRecord;
            final patientId = record['patientId'] as String;
            final patient = patientMap[patientId]!;
            final doctorId = record['doctorId'] as String?;
            final doctor = doctorId != null ? doctorMap[doctorId] : null;
            
            // Determine doctor display name
            String doctorDisplayName;
            if (doctorId == null || doctorId.isEmpty || doctorId == 'LAB-ONLY' || doctorId.toLowerCase() == 'system') {
              doctorDisplayName = 'Laboratory Only';
            } else if (doctor != null) {
              doctorDisplayName = 'Dr. ${doctor.fullName}';
            } else {
              doctorDisplayName = 'LAB-ONLY';
            }
            
            // Parse lab results
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
                      final resultsData = labData['results'] as Map<String, dynamic>? ?? {};
                      parsedResults = resultsData;
                      testName = labData['testName'] as String? ?? 'Laboratory Tests';
                      category = labData['category'] as String? ?? 'Laboratory';
                      status = labData['status'] as String? ?? 'Completed';
                    } else if (labData.containsKey('testName') || labData.containsKey('category')) {
                      // Structured format but results might be directly in the Map
                      testName = labData['testName'] as String? ?? 'Laboratory Tests';
                      category = labData['category'] as String? ?? 'Laboratory';
                      status = labData['status'] as String? ?? 'Completed';
                      
                      // Try to find results data
                      for (final key in labData.keys) {
                        if (key != 'testName' && key != 'category' && 
                            key != 'status' && key != 'date' && key != 'queueId') {
                          if (labData[key] is Map) {
                            final mapData = labData[key] as Map<String, dynamic>;
                            parsedResults.addAll(mapData);
                          } else if (labData[key] is String || labData[key] is num) {
                            final valueStr = labData[key].toString();
                            if (!valueStr.toLowerCase().contains('payment') && 
                                !valueStr.toLowerCase().contains('placeholder')) {
                              parsedResults[key] = valueStr;
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
                  continue; // Skip records with invalid JSON
                }
              }
            } catch (e) {
              debugPrint('Error parsing lab results JSON: $e');
              continue; // Skip records with parsing errors
            }

            // CRITICAL: Only include records with actual lab result data entered by medtech
            // Skip placeholder records created by payment processing and "Laboratory Only" records without actual data
            final hasActualResultData = parsedResults.isNotEmpty &&
                !parsedResults.values.every((value) => 
                    value.toString().toLowerCase().contains('payment') ||
                    value.toString().toLowerCase().contains('placeholder'));

            if (!hasActualResultData) {
              debugPrint('Skipping medical record ${record['id']} - no actual lab result data found');
              continue;
            }

            // CRITICAL: Skip "Laboratory Only" records - these are placeholder records
            // Only process records from actual medtech entries (LAB-ONLY) or real doctor consultations
            if (doctorDisplayName == 'Laboratory Only') {
              debugPrint('Skipping "Laboratory Only" record ${record['id']} - placeholder record');
              continue;
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
              'doctor': doctorDisplayName,
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
        }
      } catch (e) {
        debugPrint('Error processing laboratory medical records: $e');
      }

      // Sort by date (newest first) and remove any remaining duplicates
      transformedResults
          .sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      // FINAL DEDUPLICATION: Remove any remaining duplicates based on patient, test, and date
      // This ensures we only show one record per patient per test per day
      // CRITICAL: Always prioritize "LAB-ONLY" (medtech entries) over "Laboratory Only" (payment records)
      final finalResults = <Map<String, dynamic>>[];
      final seenCombinations = <String>{};
      
      for (final result in transformedResults) {
        final patientId = result['patientId'] as String;
        final testName = result['test'] as String;
        final date = (result['date'] as String).split(' ')[0]; // Just the date part
        final doctorName = result['doctor'] as String;
        
        // Create a unique key for this combination
        final key = '$patientId-$testName-$date';
        
        if (seenCombinations.contains(key)) {
          // This is a duplicate - check if we should replace the existing one
          final existingIndex = finalResults.indexWhere((existing) =>
            existing['patientId'] == patientId &&
            existing['test'] == testName &&
            (existing['date'] as String).split(' ')[0] == date
          );
          
          if (existingIndex != -1) {
            final existing = finalResults[existingIndex];
            final existingDoctor = existing['doctor'] as String;
            
            // Priority logic: LAB-ONLY > Dr. [Name] > Laboratory Only
            // This ensures medtech-entered results are always prioritized
            bool shouldReplace = false;
            
            if (doctorName == 'LAB-ONLY' && existingDoctor != 'LAB-ONLY') {
              // Always replace with LAB-ONLY (medtech entry)
              shouldReplace = true;
              debugPrint('Replacing duplicate: keeping "LAB-ONLY" over "$existingDoctor" for $testName');
            } else if (doctorName.startsWith('Dr. ') && existingDoctor == 'Laboratory Only') {
              // Replace Laboratory Only with any real doctor
              shouldReplace = true;
              debugPrint('Replacing duplicate: keeping "$doctorName" over "Laboratory Only" for $testName');
            } else if (doctorName != 'Laboratory Only' && existingDoctor == 'Laboratory Only') {
              // Replace Laboratory Only with any non-Laboratory Only
              shouldReplace = true;
              debugPrint('Replacing duplicate: keeping "$doctorName" over "Laboratory Only" for $testName');
            } else {
              // Keep the existing one
              debugPrint('Skipping duplicate: keeping existing "$existingDoctor" over "$doctorName" for $testName');
            }
            
            if (shouldReplace) {
              finalResults[existingIndex] = result;
            }
          }
        } else {
          // First occurrence of this combination
          seenCombinations.add(key);
          finalResults.add(result);
        }
      }

      debugPrint('Loaded ${transformedResults.length} initial records, ${finalResults.length} after deduplication');

      if (!mounted) return;
      setState(() {
        _allResults = finalResults;
        _filteredResults = finalResults;
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
                                _formatResultValue(entry.value),
                                style: TextStyle(
                                  color: Colors.grey[900],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: null, // Allow multiple lines
                                softWrap: true, // Enable text wrapping
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

  /// Helper method to format result values that can be strings, maps, or other types
  String _formatResultValue(dynamic value) {
    if (value == null) {
      return 'N/A';
    } else if (value is String) {
      return value;
    } else if (value is Map) {
      // If it's a map, convert it to a readable format
      if (value.isEmpty) {
        return 'No data';
      }
      final entries = <String>[];
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final val = _formatResultValue(entry.value); // Recursive call for nested values
        entries.add('$key: $val');
      }
      return entries.join('\n'); // Use newlines for better readability
    } else if (value is List) {
      // If it's a list, join the items
      if (value.isEmpty) {
        return 'No data';
      }
      return value.map((item) => _formatResultValue(item)).join(', ');
    } else {
      // For any other type, convert to string
      return value.toString();
    }
  }

  // Public method so it can be called from LabResultDataSource
  void showLabHistoryDialog(String patientId) async {
    debugPrint('=== Lab History Dialog Debug ===');
    debugPrint('Fetching lab history for patient ID: $patientId');
    
    final patientData = await _dbHelper.getPatient(patientId);
    if (patientData == null || !mounted) {
      debugPrint('Patient data not found or widget unmounted');
      return;
    }

    final patient = Patient.fromJson(patientData);
    debugPrint('Patient found: ${patient.fullName}');

    // Get all lab results for this patient by fetching fresh data from database
    try {
      // Fetch fresh lab results from database instead of using cached _allResults
      // CRITICAL: Only fetch records with actual lab results, not empty ones
      final labMedicalRecords = await _dbHelper.getLabResultsHistoryForPatient(patientId);
      
      // Filter out records without actual lab results
      final actualLabRecords = labMedicalRecords.where((record) =>
        record['labResults'] != null &&
        record['labResults'].toString().isNotEmpty &&
        record['labResults'] != '{}' &&
        record['labResults'] != 'null'
      ).toList();
      
      debugPrint('Found ${labMedicalRecords.length} total lab medical records for patient, ${actualLabRecords.length} with actual results');
      
      // Transform the database records to match the display format
      final allResults = <Map<String, dynamic>>[];
      
      for (final record in actualLabRecords) {
        debugPrint('Processing record ID: ${record['id']}, recordType: ${record['recordType']}, labResults: ${record['labResults'] != null ? 'present' : 'null'}');
        
        // Parse lab results from the database record
        Map<String, dynamic> parsedResults = {};
        String testName = 'Laboratory Tests';
        String category = 'Laboratory';
        String status = 'Completed';
        
        if (record['labResults'] != null && (record['labResults'] as String).isNotEmpty) {
          try {
            final labData = jsonDecode(record['labResults'] as String);
            if (labData is Map) {
              if (labData.containsKey('results')) {
                parsedResults = labData['results'] as Map<String, dynamic>? ?? {};
                testName = labData['testName'] as String? ?? 'Laboratory Tests';
                category = labData['category'] as String? ?? 'Laboratory';
                status = labData['status'] as String? ?? 'Completed';
              } else if (labData.containsKey('testName') || labData.containsKey('category')) {
                testName = labData['testName'] as String? ?? 'Laboratory Tests';
                category = labData['category'] as String? ?? 'Laboratory';
                status = labData['status'] as String? ?? 'Completed';
                
                // Extract results data
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
              } else {
                parsedResults = Map<String, dynamic>.from(labData);
              }
            }
          } catch (e) {
            debugPrint('Error parsing lab results in history: $e');
            parsedResults = {'Error': 'Could not parse lab results properly'};
          }
        }
        
        // Get doctor information - prioritize medtech entries over payment placeholders
        String doctorName = 'Laboratory Only';
        final doctorId = record['doctorId'] as String?;
        final recordType = record['recordType'] as String? ?? 'laboratory';
        
        // Determine doctor name with priority logic
        if (recordType.toLowerCase() == 'consultation' && 
            doctorId != null && 
            doctorId.isNotEmpty && 
            doctorId != 'LAB-ONLY' && 
            doctorId != 'null' &&
            doctorId.toLowerCase() != 'system') {
          try {
            final doctorData = await _dbHelper.getUserById(doctorId);
            if (doctorData != null) {
              doctorName = 'Dr. ${doctorData.fullName}';
            } else {
              // Doctor ID exists but doctor not found in database - likely medtech entry
              doctorName = 'LAB-ONLY';
            }
          } catch (e) {
            debugPrint('Error getting doctor info for ID $doctorId: $e');
            doctorName = 'LAB-ONLY';
          }
        } else if (recordType.toLowerCase() == 'laboratory') {
          // For laboratory records, check if it's a medtech entry or payment placeholder
          if (doctorId == null || doctorId.isEmpty || doctorId == 'LAB-ONLY' || doctorId.toLowerCase() == 'system') {
            // Check if this has actual lab data vs just payment status
            final hasActualData = parsedResults.isNotEmpty && 
                !parsedResults.values.every((value) => 
                    value.toString().toLowerCase().contains('payment') ||
                    value.toString().toLowerCase().contains('placeholder'));
            
            if (hasActualData) {
              doctorName = 'LAB-ONLY'; // Medtech entry with actual data
            } else {
              doctorName = 'Laboratory Only'; // Payment placeholder
            }
          } else {
            // Has a doctor ID but not found - likely medtech entry
            doctorName = 'LAB-ONLY';
          }
        }
        
        // CRITICAL: Skip "Laboratory Only" records without actual lab data
        // Only show records with meaningful lab results entered by medtech
        final hasActualLabData = parsedResults.isNotEmpty && 
            !parsedResults.values.every((value) => 
                value.toString().toLowerCase().contains('payment') ||
                value.toString().toLowerCase().contains('placeholder'));
        
        if (doctorName == 'Laboratory Only' && !hasActualLabData) {
          debugPrint('Skipping "Laboratory Only" record ${record['id']} - no actual lab data');
          continue; // Skip placeholder records
        }
        
        allResults.add({
          'id': record['id'],
          'patientName': patient.fullName,
          'patientId': patientId,
          'date': DateFormat('yyyy-MM-dd HH:mm').format(
            DateTime.tryParse(record['recordDate'] as String) ?? DateTime.now()
          ),
          'test': testName,
          'testType': 'Medical Record',
          'doctor': doctorName,
          'doctorId': record['doctorId'],
          'result': parsedResults.isNotEmpty ? parsedResults : {'Status': 'Results available in medical record'},
          'status': status,
          'notes': record['notes'] as String? ?? '',
          'category': category,
          'diagnosis': record['diagnosis'] as String? ?? '',
          'rawLabResults': record['labResults'] as String? ?? '',
          'isFromMedicalRecord': true,
        });
      }
      
      // Apply the same deduplication logic as the main screen
      // Group by patient, test, and date to remove duplicates
      final uniqueResults = <Map<String, dynamic>>[];
      final seenCombinations = <String>{};
      
      for (final result in allResults) {
        final testName = result['test'] as String;
        final date = (result['date'] as String).split(' ')[0]; // Just the date part
        final doctorName = result['doctor'] as String;
        
        // Create a unique key for this combination
        final key = '$patientId-$testName-$date';
        
        if (seenCombinations.contains(key)) {
          // This is a duplicate - check if we should replace the existing one
          final existingIndex = uniqueResults.indexWhere((existing) =>
            existing['test'] == testName &&
            (existing['date'] as String).split(' ')[0] == date
          );
          
          if (existingIndex != -1) {
            final existing = uniqueResults[existingIndex];
            final existingDoctor = existing['doctor'] as String;
            
            // Priority logic: LAB-ONLY > Dr. [Name] > Laboratory Only
            bool shouldReplace = false;
            
            if (doctorName == 'LAB-ONLY' && existingDoctor != 'LAB-ONLY') {
              // Always replace with LAB-ONLY (medtech entry)
              shouldReplace = true;
              debugPrint('History: Replacing duplicate: keeping "LAB-ONLY" over "$existingDoctor" for $testName');
            } else if (doctorName.startsWith('Dr. ') && existingDoctor == 'Laboratory Only') {
              // Replace Laboratory Only with any real doctor
              shouldReplace = true;
              debugPrint('History: Replacing duplicate: keeping "$doctorName" over "Laboratory Only" for $testName');
            } else if (doctorName != 'Laboratory Only' && existingDoctor == 'Laboratory Only') {
              // Replace Laboratory Only with any non-Laboratory Only
              shouldReplace = true;
              debugPrint('History: Replacing duplicate: keeping "$doctorName" over "Laboratory Only" for $testName');
            }
            
            if (shouldReplace) {
              uniqueResults[existingIndex] = result;
            }
          }
        } else {
          // First occurrence of this combination
          seenCombinations.add(key);
          uniqueResults.add(result);
        }
      }
      
      // Sort by date (newest first)
      uniqueResults.sort((a, b) {
        final aDate = a['date'] as String? ?? '';
        final bDate = b['date'] as String? ?? '';
        return bDate.compareTo(aDate); // Newest first
      });

      debugPrint('Final uniqueResults count: ${uniqueResults.length}');
      if (uniqueResults.isEmpty) {
        debugPrint('No lab results found for patient $patientId');
      } else {
        debugPrint('Lab results to display after deduplication:');
        for (int i = 0; i < uniqueResults.length; i++) {
          final result = uniqueResults[i];
          debugPrint('  $i: ${result['test']} - ${result['date']} - ${result['doctor']}');
        }
      }

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
            child: uniqueResults.isEmpty
                ? const Center(
                    child:
                        Text('No laboratory history found for this patient.'))
                : ListView.builder(
                    itemCount: uniqueResults.length,
                    itemBuilder: (context, index) {
                      final result = uniqueResults[index];
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
      debugPrint('Error in showLabHistoryDialog: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
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
    // CRITICAL: This method should ONLY update existing lab results, never create new ones
    // Only the medtech in consultation results screen should create authoritative lab records
    
    // Instead of creating a new medical record, we should update the existing one
    // if it exists, or inform the user that results should be entered in consultation screen
    
    try {
      // Check if a laboratory medical record already exists for this patient and queue
      final existingRecords = await _dbHelper.getAllMedicalRecords();
      final existingLabRecord = existingRecords.where((record) =>
        record['queueEntryId'] == queueId &&
        record['recordType']?.toString().toLowerCase() == 'laboratory'
      ).firstOrNull;
      
      if (existingLabRecord != null) {
        // Update the existing laboratory record
        await _updateMedicalRecordResult(existingLabRecord['id'], updatedResult);
        debugPrint('Updated existing laboratory record for queue: $queueId');
      } else {
        // No laboratory record exists - this should be created in consultation results screen
        debugPrint('Warning: No laboratory record exists for queue $queueId. Lab results should be entered via Consultation Results screen.');
        throw Exception('Laboratory results should be entered via the Consultation Results screen by the medical technician.');
      }
    } catch (e) {
      debugPrint('Error updating queue item result: $e');
      rethrow;
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
