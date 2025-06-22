import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/database_helper.dart';
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

  LabResultDataSource(this._results, this.context);

  void updateData(List<Map<String, dynamic>> newResults) {
    _results = newResults;
    notifyListeners();
  }
  @override
  DataRow getRow(int index) {
    final result = _results[index];
    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              result['id']?.toString().substring(0, 8) ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                result['patientName'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (result['patientId'] != null)
                Text(
                  'ID: ${result['patientId'].toString().substring(0, 8)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                result['date']?.split(' ')[0] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                result['date']?.split(' ')[1] ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                result['test'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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
            ],
          ),
        ),
        DataCell(Text(result['doctor'] ?? 'N/A')),
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
                onPressed: () {
                  _showResultDetails(context, result);
                },
                tooltip: 'View Details',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String? category) {
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

  void sort<T>(Comparable<T> Function(Map<String, dynamic> d) getField, bool ascending) {
    _results.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    notifyListeners();
  }
}

class PreviousLaboratoryResultsScreenState extends State<PreviousLaboratoryResultsScreen> {
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
    _dataSource = LabResultDataSource([], context);
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
      final allMedicalRecords = await _dbHelper.getAllMedicalRecords();
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
      
      // Define categories that ARE laboratory-related
      const laboratoryCategories = {
        'laboratory', 'radiology', 'hematology', 'chemistry', 
        'urinalysis', 'microbiology', 'pathology'
      };

      // 1. Process appointments to find and extract all lab-related services
      for (final appt in appointments) {
        if (!['completed', 'served', 'finished'].contains(appt.status.toLowerCase())) {
          continue;
        }

        final labServices = appt.selectedServices.where((service) {
          final category = (service['category'] as String? ?? '').toLowerCase();
          final serviceName = (service['serviceName'] ?? service['name'] ?? '').toLowerCase();

          // Prioritize structured category, fallback to keyword search in name
          return laboratoryCategories.contains(category) ||
                 serviceName.contains('lab') || serviceName.contains('test') ||
                 serviceName.contains('blood') || serviceName.contains('urine') ||
                 serviceName.contains('x-ray') || serviceName.contains('scan');
        }).toList();

        if (labServices.isNotEmpty) {
          processedAppointmentIds.add(appt.id);
          final patient = patientMap[appt.patientId];
          if (patient == null) continue;

          final doctor = doctorMap[appt.doctorId];
          final doctorName = doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor';

          for (final service in labServices) {
            final serviceName = service['serviceName'] ?? service['name'] ?? 'Laboratory Test';
            // Use the more reliable category from the service data if available
            final category = service['category'] as String? ?? _determineTestCategory(serviceName.toLowerCase(), '');
            
            transformedResults.add({
              'id': '${appt.id}_${service['id'] ?? transformedResults.length}',
              'patientName': patient.fullName,
              'patientId': patient.id,
              'date': DateFormat('yyyy-MM-dd HH:mm').format(appt.date),
              'test': serviceName,
              'testType': 'Appointment Service',
              'doctor': doctorName,
              'doctorId': appt.doctorId,
              'result': {'Status': 'Test completed during consultation'},
              'status': 'Completed',
              'notes': appt.notes ?? 'Performed during consultation',
              'category': category,
              'diagnosis': '',
              'rawLabResults': 'Service performed during appointment',
              'patient': patient,
              'doctorUser': doctor,
              'isFromAppointment': true,
            });
          }
        }
      }
      
      // 2. Process medical records, skipping any linked to already-processed appointments
      for (final record in allMedicalRecords) {
        try {
          if (record['appointmentId'] != null && processedAppointmentIds.contains(record['appointmentId'])) {
            continue;
          }

          final patient = patientMap[record['patientId']];
          if (patient == null) {
            debugPrint('Patient not found for record ${record['id']}');
            continue;
          }

          final doctor = doctorMap[record['doctorId']];
          final doctorName = doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor (ID: ${record['doctorId']})';

          final recordType = (record['recordType'] as String?)?.toLowerCase() ?? '';
          final labResults = (record['labResults'] as String?)?.toLowerCase() ?? '';
          final diagnosis = (record['diagnosis'] as String?)?.toLowerCase() ?? '';
          final notes = (record['notes'] as String?)?.toLowerCase() ?? '';
          
          if (_isLaboratoryRecord(recordType, labResults, diagnosis, notes)) {
            Map<String, String> parsedResults = _parseLabResults(record['labResults'] as String?);
            String status = _determineResultStatus(record['labResults'] as String?, record['notes'] as String?);
            String category = _determineTestCategory(recordType, labResults);
            String testName = _determineTestName(recordType, labResults, diagnosis);

            transformedResults.add({
              'id': record['id'],
              'patientName': patient.fullName,
              'patientId': patient.id,
              'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(record['recordDate'] as String)),
              'test': testName,
              'testType': recordType,
              'doctor': doctorName,
              'doctorId': record['doctorId'],
              'result': parsedResults,
              'status': status,
              'notes': record['notes'] ?? 'No additional notes',
              'category': category,
              'diagnosis': record['diagnosis'] ?? '',
              'rawLabResults': record['labResults'] ?? '',
              'patient': patient,
              'doctorUser': doctor,
            });
          }
        } catch (e) {
          debugPrint('Error processing medical record ${record['id']}: $e');
        }
      }

      // Sort by date (newest first)
      transformedResults.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

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

  bool _isLaboratoryRecord(String recordType, String labResults, String diagnosis, String notes) {
    const labKeywords = [
      'lab', 'laboratory', 'test', 'blood', 'urine', 'urinalysis',
      'cbc', 'chemistry', 'hematology', 'microbiology', 'pathology',
      'x-ray', 'scan', 'imaging', 'radiology', 'ultrasound', 'ct', 'mri',
      'glucose', 'cholesterol', 'hemoglobin', 'platelet', 'culture'
    ];
    
    final combined = '$recordType $labResults $diagnosis $notes'.toLowerCase();
    return labKeywords.any((keyword) => combined.contains(keyword));
  }

  Map<String, String> _parseLabResults(String? labResults) {
    Map<String, String> parsed = {};
    
    if (labResults == null || labResults.isEmpty) {
      return {'Result': 'No result data available'};
    }

    try {
      final lines = labResults.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        if (trimmed.contains(':')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final value = parts.sublist(1).join(':').trim();
            if (key.isNotEmpty && value.isNotEmpty) {
              parsed[key] = value;
            }
          }
        } else if (trimmed.contains('=')) {
          final parts = trimmed.split('=');
          if (parts.length == 2) {
            final key = parts[0].trim();
            final value = parts[1].trim();
            if (key.isNotEmpty && value.isNotEmpty) {
              parsed[key] = value;
            }
          }
        } else if (parsed.isEmpty) {
          // If no structured data found, use the whole text as result
          parsed['Result'] = trimmed;
        }
      }
      
      if (parsed.isEmpty) {
        parsed['Result'] = labResults;
      }
    } catch (e) {
      parsed['Result'] = labResults;
    }
    
    return parsed;
  }

  String _determineTestName(String recordType, String labResults, String diagnosis) {
    final combined = '$recordType $labResults $diagnosis'.toLowerCase();
    
    if (combined.contains('cbc') || combined.contains('complete blood count')) {
      return 'Complete Blood Count (CBC)';
    } else if (combined.contains('urinalysis') || combined.contains('urine test')) {
      return 'Urinalysis';
    } else if (combined.contains('blood chemistry') || combined.contains('chemistry panel')) {
      return 'Blood Chemistry Panel';
    } else if (combined.contains('x-ray')) {
      return 'X-Ray Examination';
    } else if (combined.contains('ultrasound')) {
      return 'Ultrasound';
    } else if (combined.contains('glucose')) {
      return 'Blood Glucose Test';
    } else if (combined.contains('cholesterol')) {
      return 'Cholesterol Test';
    } else if (combined.contains('culture')) {
      return 'Culture Test';
    } else if (recordType.isNotEmpty) {
      return recordType;
    } else {
      return 'Laboratory Test';
    }
  }
  void _filterResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredResults = _allResults.where((result) {
        final patientName = (result['patientName'] as String?)?.toLowerCase() ?? '';
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

  String _determineTestCategory(String recordType, String labResults) {
    final combined = '$recordType $labResults'.toLowerCase();
    
    if (combined.contains('blood') || combined.contains('cbc') || combined.contains('hemoglobin') ||
        combined.contains('wbc') || combined.contains('rbc') || combined.contains('platelet')) {
      return 'Hematology';
    } else if (combined.contains('glucose') || combined.contains('cholesterol') || 
               combined.contains('lipid') || combined.contains('chemistry') ||
               combined.contains('liver') || combined.contains('kidney')) {
      return 'Chemistry';
    } else if (combined.contains('urine') || combined.contains('urinalysis')) {
      return 'Urinalysis';
    } else if (combined.contains('culture') || combined.contains('bacteria') ||
               combined.contains('sensitivity') || combined.contains('microbiology')) {
      return 'Microbiology';
    } else if (combined.contains('x-ray') || combined.contains('imaging') ||
               combined.contains('radiology') || combined.contains('scan')) {
      return 'Radiology';
    } else {
      return 'General';
    }
  }

  String _determineResultStatus(String? labResults, String? notes) {
    final combined = '${labResults ?? ''} ${notes ?? ''}'.toLowerCase();

    if (combined.contains('cancelled') || combined.contains('canceled')) {
      return 'Cancelled';
    }
    if (combined.contains('pending')) {
      return 'Pending';
    }
    if (combined.contains('normal') || combined.contains('negative') ||
        combined.contains('within range') || combined.contains('clear')) {
      return 'Normal';
    } else if (combined.contains('abnormal') || combined.contains('positive') ||
               combined.contains('elevated') || combined.contains('high') ||
               combined.contains('low') || combined.contains('critical')) {
      return 'Abnormal';
    } else if (combined.contains('borderline') || combined.contains('slightly')) {
      return 'Borderline';
    } else {
      return 'Pending Review';
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });

    _dataSource.sort<String>((d) {
      switch (columnIndex) {
        case 0:
          return d['id'].toString();
        case 1:
          return d['patientName'] as String;
        case 2:
          return d['date'] as String;
        case 3:
          return d['test'] as String;
        case 4:
          return d['doctor'] as String;
        case 5:
          return d['status'] as String;
        default:
          return '';
      }
    }, ascending);
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
                child: Text(
                  '${_filteredResults.length} results',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAllResults,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                            'Laboratory test results will appear here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.science, color: Colors.teal[700]),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Laboratory Records',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      labelText: 'Search by Patient, Test, Doctor, or Category',
                                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                              },
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: const BorderSide(color: Colors.teal),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: PaginatedDataTable(
                                  header: null,
                                  rowsPerPage: 10,
                                  showCheckboxColumn: false,
                                  headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                                  columns: [
                                    DataColumn(
                                      label: const Text('ID', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: const Text('Patient', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: const Text('Test/Service', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: const Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    const DataColumn(
                                      label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  source: _dataSource,
                                  sortColumnIndex: _sortColumnIndex,
                                  sortAscending: _sortAscending,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

void _showResultDetails(BuildContext context, Map<String, dynamic> result) {
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                _buildDetailRow('Patient ID', result['patientId']?.toString().substring(0, 8) ?? 'N/A'),
                
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
                if (result['diagnosis'] != null && result['diagnosis'].isNotEmpty)
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