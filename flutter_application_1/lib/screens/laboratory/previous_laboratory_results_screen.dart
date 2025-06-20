import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/patient.dart';
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
        DataCell(Text(result['id']?.toString() ?? 'N/A')),
        DataCell(Text(result['patientName'] ?? 'N/A')),
        DataCell(Text(result['date'] ?? 'N/A')),
        DataCell(Text(result['test'] ?? 'N/A')),
        DataCell(Text(result['doctor'] ?? 'N/A')),
        DataCell(Text(result['status'] ?? 'N/A')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () {
              _showResultDetails(context, result);
            },
          ),
        ),
      ],
    );
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
      final allMedicalRecords = await _dbHelper.getAllMedicalRecords();
      final patientsData = await _dbHelper.patientDbService.getPatients();
      final usersData = await _dbHelper.userDbService.getUsers();

      final patientMap = {
        for (var p in patientsData)
          p['id']: Patient.fromJson(p)
      };
      final doctorMap = {
        for (var u in usersData.where((u) => u.role == 'doctor')) u.id: u
      };

      final labRecords = allMedicalRecords.where((record) {
        final recordType = (record['recordType'] as String?)?.toLowerCase() ?? '';
        final labResults =
            (record['labResults'] as String?)?.toLowerCase() ?? '';
        final category =
            _determineTestCategory(recordType, labResults);
        return category != 'General' ||
            recordType.contains('lab') ||
            labResults.contains('pending');
      }).toList();

      final transformedResults = <Map<String, dynamic>>[];
      for (final record in labRecords) {
        final patient = patientMap[record['patientId']];
        if (patient == null) continue;

        final doctor = doctorMap[record['doctorId']];
        final doctorName =
            doctor != null ? 'Dr. ${doctor.fullName}' : 'Unknown Doctor';

        Map<String, String> parsedResults = {};
        try {
          final labText = record['labResults'] as String? ?? '';
          if (labText.isNotEmpty) {
            final lines = labText.split('\n');
            for (final line in lines) {
              if (line.contains(':')) {
                final parts = line.split(':');
                if (parts.length >= 2) {
                  parsedResults[parts[0].trim()] =
                      parts.sublist(1).join(':').trim();
                }
              }
            }
            if (parsedResults.isEmpty) {
              parsedResults['Result'] = labText;
            }
          } else {
            parsedResults['Result'] = 'No result data';
          }
        } catch (e) {
          parsedResults['Result'] =
              record['labResults'] as String? ?? 'Error parsing results';
        }

        String status = _determineResultStatus(
            record['labResults'] as String?, record['notes'] as String?);
        String category = _determineTestCategory(
            record['recordType'] as String, record['labResults'] as String);

        transformedResults.add({
          'id': record['id'],
          'patientName': patient.fullName,
          'date': DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(record['recordDate'] as String)),
          'test': record['recordType'] as String,
          'doctor': doctorName,
          'result': parsedResults,
          'status': status,
          'notes': record['notes'] ?? 'No additional notes',
          'category': category,
          'diagnosis': record['diagnosis'] ?? '',
        });
      }

      transformedResults
          .sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      if (!mounted) return;
      setState(() {
        _allResults = transformedResults;
        _filteredResults = transformedResults;
        _dataSource.updateData(_filteredResults);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _filterResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredResults = _allResults.where((result) {
        final patientName = (result['patientName'] as String?)?.toLowerCase() ?? '';
        final testName = (result['test'] as String?)?.toLowerCase() ?? '';
        final doctorName = (result['doctor'] as String?)?.toLowerCase() ?? '';
        return patientName.contains(query) || testName.contains(query) || doctorName.contains(query);
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
        title: const Text('All Laboratory Results'),
        backgroundColor: Colors.teal[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search by Patient, Test, or Doctor',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: PaginatedDataTable(
                              header: const Text('Laboratory Records'),
                              rowsPerPage: 10,
                              columns: [
                                DataColumn(label: const Text('ID'), onSort: _onSort),
                                DataColumn(label: const Text('Patient'), onSort: _onSort),
                                DataColumn(label: const Text('Date'), onSort: _onSort),
                                DataColumn(label: const Text('Test'), onSort: _onSort),
                                DataColumn(label: const Text('Requesting Doctor'), onSort: _onSort),
                                DataColumn(label: const Text('Status'), onSort: _onSort),
                                const DataColumn(label: Text('Actions')),
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
            const Icon(Icons.science, color: Color(0xFF1ABC9C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['test'],
                    style: const TextStyle(color: Color(0xFF1ABC9C)),
                  ),
                  Text(
                    result['category'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Patient', result['patientName']),
                _buildDetailRow('Date', result['date']),
                _buildDetailRow('Doctor', result['doctor']),
                _buildDetailRow('Status', result['status']),
                _buildDetailRow('Notes', result['notes']),
                const SizedBox(height: 16),
                const Text(
                  'Test Results',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1ABC9C),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...(result['result'] as Map<String, dynamic>).entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Close', style: TextStyle(color: Color(0xFF1ABC9C))),
          )
        ],
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