import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
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
  final Function(Map<String, dynamic>) onViewDetails;

  LabResultDataSource(this._results, this.context, this.onViewDetails);

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

      // 3. Process medical records has been removed to prevent duplication.
      // The sources above (Queue and Appointments) are the single source of truth for services rendered.

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
                _buildDetailRow('Patient ID',
                    result['patientId']?.toString().substring(0, 8) ?? 'N/A'),

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
