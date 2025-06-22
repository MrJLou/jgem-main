import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:intl/intl.dart';

class PreviousConsultationScreen extends StatefulWidget {
  const PreviousConsultationScreen({super.key});

  @override
  PreviousConsultationScreenState createState() =>
      PreviousConsultationScreenState();
}

class ConsultationDataSource extends DataTableSource {
  List<Map<String, dynamic>> _consultations;
  final BuildContext context;

  ConsultationDataSource(this._consultations, this.context);

  void updateData(List<Map<String, dynamic>> newData) {
    _consultations = newData;
    notifyListeners();
  }
  @override
  DataRow getRow(int index) {
    final consultation = _consultations[index];
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
              consultation['id']?.toString().substring(0, 8) ?? 'N/A',
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
                consultation['patientName'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (consultation['patientId'] != null)
                Text(
                  'ID: ${consultation['patientId'].toString().substring(0, 8)}',
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
                consultation['date']?.split(' ')[0] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                consultation['date']?.split(' ')[1] ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        DataCell(Text(consultation['doctorName'] ?? 'N/A')),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                consultation['consultationType'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(consultation['category']),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  consultation['category'] ?? 'General',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(consultation['status']),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              consultation['status'] ?? 'N/A',
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
                  _showConsultationDetails(context, consultation);
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
      case 'laboratory':
        return Colors.blue;
      case 'radiology':
        return Colors.purple;
      case 'surgery':
        return Colors.red;
      case 'emergency':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'served':
        return Colors.blue;
      case 'finished':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _consultations.length;

  @override
  int get selectedRowCount => 0;

  void sort<T>(Comparable<T> Function(Map<String, dynamic> d) getField, bool ascending) {
    _consultations.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    notifyListeners();
  }
}

class PreviousConsultationScreenState extends State<PreviousConsultationScreen> {
  List<Map<String, dynamic>> _allConsultations = [];
  List<Map<String, dynamic>> _filteredConsultations = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();
  late ConsultationDataSource _dataSource;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _dataSource = ConsultationDataSource([], context);
    _fetchAllConsultations();
    _searchController.addListener(_filterConsultations);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterConsultations);
    _searchController.dispose();
    super.dispose();
  }
  void _fetchAllConsultations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all necessary data
      final patientsData = await _dbHelper.patientDbService.getPatients();
      final usersData = await _dbHelper.userDbService.getUsers();
      final allAppointments = await _dbHelper.getAllAppointments();
      final allMedicalRecords = await _dbHelper.getAllMedicalRecords();

      // Create comprehensive patient and doctor maps for quick lookup
      final patientMap = {
        for (var pMap in patientsData) Patient.fromJson(pMap).id: Patient.fromJson(pMap)
      };
      final doctorMap = {
        for (var user in usersData.where((u) => u.role.toLowerCase() == 'doctor'))
          user.id: user
      };

      final consultationRecords = <Map<String, dynamic>>[];
      final processedAppointmentIds = <String>{};

      // Define categories that are NOT consultations
      const nonConsultationCategories = {
        'laboratory', 'radiology', 'surgery', 'emergency',
        'hematology', 'chemistry', 'urinalysis', 'microbiology', 'pathology'
      };

      // 1. Process completed appointments first, using structured service data
      for (final appt in allAppointments) {
        if (!['completed', 'served', 'finished'].contains(appt.status.toLowerCase())) {
          continue;
        }

        final serviceCategories = appt.selectedServices
            .map((s) => (s['category'] as String? ?? '').toLowerCase())
            .toSet();

        // An appointment is a "consultation" if it has NO services belonging to non-consultation categories,
        // or if it has no services (which defaults to a general consultation).
        final isConsultation = serviceCategories.isEmpty || serviceCategories.every((c) => !nonConsultationCategories.contains(c));

        if (isConsultation) {
          processedAppointmentIds.add(appt.id);
          final patient = patientMap[appt.patientId];
          final doctor = doctorMap[appt.doctorId];
          if (patient == null) continue;

          final servicesText = appt.selectedServices.map((s) => s['name'] as String? ?? 'Service').join(', ');
          
          consultationRecords.add({
            'id': appt.id,
            'patientName': patient.fullName,
            'patientId': patient.id,
            'date': DateFormat('yyyy-MM-dd HH:mm').format(appt.date),
            'doctorName': doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor',
            'doctorId': appt.doctorId,
            'consultationType': appt.consultationType,
            'status': 'Completed',
            'details': appt.notes ?? 'No additional details recorded',
            'prescription': 'N/A', // This info is in medical records, not appointments
            'followUp': 'Follow up as needed',
            'services': servicesText.isNotEmpty ? servicesText : 'Consultation',
            'totalPrice': appt.totalPrice,
            'category': 'General', // Default category for this view
            'duration': appt.durationMinutes ?? 30,
            'patient': patient,
            'doctor': doctor,
            'appointmentData': appt.toMap(),
          });
        }
      }

      // 2. Process medical records, skipping those linked to already-processed appointments
      for (final record in allMedicalRecords) {
        if (record['appointmentId'] != null && processedAppointmentIds.contains(record['appointmentId'] as String)) {
          continue;
        }

        final recordType = (record['recordType'] as String?)?.toLowerCase() ?? '';

        // A medical record with type 'Consultation' is what we are looking for.
        if (recordType == 'consultation') {
          final patient = patientMap[record['patientId'] as String];
          final doctor = doctorMap[record['doctorId'] as String];
          if (patient == null) continue;

          final servicesText = (record['notes'] as String?)?.replaceFirst('Consultation for: ', '') ?? 'Consultation';
          final category = _getCategoryFromServiceString(servicesText);

          // Skip if the derived category is a non-consultation one
          if (nonConsultationCategories.contains(category.toLowerCase())) {
            continue;
          }

          final recordDate = DateTime.parse(record['recordDate'] as String);

          consultationRecords.add({
            'id': record['id'],
            'patientName': patient.fullName,
            'patientId': patient.id,
            'date': DateFormat('yyyy-MM-dd HH:mm').format(recordDate),
            'doctorName': doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor',
            'doctorId': record['doctorId'],
            'consultationType': record['recordType'] ?? 'Consultation',
            'status': 'Completed', 
            'details': record['notes'] ?? 'No additional details recorded',
            'prescription': record['diagnosis'] ?? 'No prescription recorded',
            'followUp': 'Follow up as needed',
            'services': servicesText,
            'totalPrice': null, // Not available in medical record
            'category': category,
            'duration': 30, // Default duration
            'patient': patient,
            'doctor': doctor,
            'appointmentData': null,
          });
        }
      }

      // Sort by date (newest first)
      consultationRecords.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      if (!mounted) return;

      setState(() {
        _allConsultations = consultationRecords;
        _filteredConsultations = consultationRecords;
        _dataSource.updateData(_filteredConsultations);
        _isLoading = false;
      });

      debugPrint('Loaded ${consultationRecords.length} consultation records from medical records');
    } catch (e) {
      debugPrint('Error fetching consultations: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load consultation data. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _getCategoryFromServiceString(String serviceNames) {
    final lowerCaseServiceNames = serviceNames.toLowerCase();
    
    if (lowerCaseServiceNames.contains('lab') || lowerCaseServiceNames.contains('laboratory') || 
        lowerCaseServiceNames.contains('blood') || lowerCaseServiceNames.contains('test')) {
      return 'Laboratory';
    } else if (lowerCaseServiceNames.contains('x-ray') || lowerCaseServiceNames.contains('imaging') || 
               lowerCaseServiceNames.contains('scan')) {
      return 'Radiology';
    } else if (lowerCaseServiceNames.contains('surgery') || lowerCaseServiceNames.contains('operation')) {
      return 'Surgery';
    } else if (lowerCaseServiceNames.contains('emergency') || lowerCaseServiceNames.contains('urgent')) {
      return 'Emergency';
    } else {
      return 'General';
    }
  }

  void _filterConsultations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConsultations = _allConsultations.where((consultation) {
        final patientName = (consultation['patientName'] as String?)?.toLowerCase() ?? '';
        final doctorName = (consultation['doctorName'] as String?)?.toLowerCase() ?? '';
        final consultationType = (consultation['consultationType'] as String?)?.toLowerCase() ?? '';
        final services = (consultation['services'] as String?)?.toLowerCase() ?? '';
        final category = (consultation['category'] as String?)?.toLowerCase() ?? '';
        final status = (consultation['status'] as String?)?.toLowerCase() ?? '';
        
        return patientName.contains(query) || 
               doctorName.contains(query) || 
               consultationType.contains(query) ||
               services.contains(query) ||
               category.contains(query) ||
               status.contains(query);
      }).toList();
      _dataSource.updateData(_filteredConsultations);
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
          return d['id'].toString();
        case 1:
          return d['patientName'] as String;
        case 2:
          return d['date'] as String;
        case 3:
          return d['doctorName'] as String;
        case 4:
          return d['consultationType'] as String;
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
          'Previous Consultations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        actions: [
          if (!_isLoading && _allConsultations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_filteredConsultations.length} records',
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
                  Text('Loading consultation records...'),
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
                        onPressed: _fetchAllConsultations,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _allConsultations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_services_outlined, 
                               size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No consultation records found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Completed consultations will appear here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
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
                                          Icon(Icons.medical_services, color: Colors.teal[700]),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Consultation Records',
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
                                          labelText: 'Search by Patient, Doctor, Type, or Service',
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
                                      headingRowColor: MaterialStateProperty.all(Colors.teal[50]),
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
                                          label: const Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Type/Category', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      ),
                    ),
    );
  }
}

void _showConsultationDetails(BuildContext context, Map<String, dynamic> consultation) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          Icon(Icons.medical_services, color: Colors.teal[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consultation Details',
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCategoryColorForDialog(consultation['category']),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    consultation['category'] ?? 'General',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
              _buildDetailRow('Patient Name', consultation['patientName']),
              _buildDetailRow('Patient ID', consultation['patientId']?.toString().substring(0, 8) ?? 'N/A'),
              
              const SizedBox(height: 16),
              
              // Consultation Information Section
              _buildSectionHeader('Consultation Information'),
              _buildDetailRow('Date & Time', consultation['date']),
              _buildDetailRow('Doctor', consultation['doctorName']),
              _buildDetailRow('Consultation Type', consultation['consultationType']),
              _buildDetailRow('Duration', '${consultation['duration'] ?? 30} minutes'),
              _buildDetailRow('Status', consultation['status']),
              
              const SizedBox(height: 16),
              
              // Services Section
              if (consultation['services'] != null && consultation['services'].isNotEmpty) ...[
                _buildSectionHeader('Services Provided'),
                _buildDetailRow('Services', consultation['services']),
                const SizedBox(height: 16),
              ],
              
              // Medical Information Section
              _buildSectionHeader('Medical Information'),
              _buildDetailRow('Prescription', consultation['prescription']),
              _buildDetailRow('Follow-up Instructions', consultation['followUp']),
              _buildDetailRow('Additional Notes', consultation['details']),
              
              const SizedBox(height: 16),
              
              // Financial Information Section
              if (consultation['totalPrice'] != null) ...[
                _buildSectionHeader('Financial Information'),
                _buildDetailRow('Total Cost', 'PHP ${consultation['totalPrice'].toStringAsFixed(2)}'),
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
    case 'laboratory':
      return Colors.blue;
    case 'radiology':
      return Colors.purple;
    case 'surgery':
      return Colors.red;
    case 'emergency':
      return Colors.orange;
    default:
      return Colors.green;
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
