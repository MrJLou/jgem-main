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
        DataCell(Text(consultation['id']?.toString() ?? 'N/A')),
        DataCell(Text(consultation['patientName'] ?? 'N/A')),
        DataCell(Text(consultation['date'] ?? 'N/A')),
        DataCell(Text(consultation['doctorName'] ?? 'N/A')),
        DataCell(Text(consultation['consultationType'] ?? 'N/A')),
        DataCell(Text(consultation['status'] ?? 'N/A')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () {
              _showConsultationDetails(context, consultation);
            },
          ),
        ),
      ],
    );
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
      final appointments = await _dbHelper.getAllAppointments();
      final patients = await _dbHelper.patientDbService.getPatients();
      final users = await _dbHelper.userDbService.getUsers();

      final patientMap = {
        for (var p in patients) p['id']: Patient.fromJson(p)
      };
      final doctorMap = {
        for (var u in users.where((u) => u.role == 'doctor')) u.id: u
      };

      final consultationRecords = appointments.where((appt) {
        final status = appt.status.toLowerCase();
        return status == 'completed' || status == 'served';
      }).map((appt) {
        final patient = patientMap[appt.patientId];
        final doctor = doctorMap[appt.doctorId];
        return {
          'id': appt.id,
          'patientName': patient?.fullName ?? 'Unknown Patient',
          'date': DateFormat('yyyy-MM-dd').format(appt.date),
          'doctorName': doctor?.fullName ?? 'Unknown Doctor',
          'consultationType': appt.consultationType,
          'status': appt.status,
          'details': appt.notes,
          'prescription': appt.notes ?? 'No prescription noted',
          'followUp': 'As needed',
          'services': appt.selectedServices.map((s) => s['name'] ?? 'Unknown Service').join(', '),
          'totalPrice': appt.totalPrice,
          'patient': patient,
          'doctor': doctor,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _allConsultations = consultationRecords;
        _filteredConsultations = consultationRecords;
        _dataSource.updateData(_filteredConsultations);
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

  void _filterConsultations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConsultations = _allConsultations.where((consultation) {
        final patientName = (consultation['patientName'] as String?)?.toLowerCase() ?? '';
        final doctorName = (consultation['doctorName'] as String?)?.toLowerCase() ?? '';
        final consultationType = (consultation['consultationType'] as String?)?.toLowerCase() ?? '';
        return patientName.contains(query) || doctorName.contains(query) || consultationType.contains(query);
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
        title: const Text('Past Consultations'),
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
                              labelText: 'Search by Patient, Doctor, or Type',
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
                              header: const Text('Consultation Records'),
                              rowsPerPage: 10,
                              columns: [
                                DataColumn(label: const Text('ID'), onSort: _onSort),
                                DataColumn(label: const Text('Patient'), onSort: _onSort),
                                DataColumn(label: const Text('Date'), onSort: _onSort),
                                DataColumn(label: const Text('Doctor'), onSort: _onSort),
                                DataColumn(label: const Text('Type'), onSort: _onSort),
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

void _showConsultationDetails(BuildContext context, Map<String, dynamic> consultation) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.medical_services, color: Color(0xFF1ABC9C)),
          SizedBox(width: 10),
          Text(
            'Consultation Details',
            style: TextStyle(color: Color(0xFF1ABC9C)),
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
              _buildDetailRow('Patient', consultation['patientName']),
              _buildDetailRow('Date', consultation['date']),
              _buildDetailRow('Doctor', consultation['doctorName']),
              _buildDetailRow('Type', consultation['consultationType']),
              if (consultation['services'] != null && consultation['services'].isNotEmpty)
                _buildDetailRow('Services', consultation['services']),
              _buildDetailRow('Prescription', consultation['prescription']),
              _buildDetailRow('Follow-up', consultation['followUp']),
              _buildDetailRow('Status', consultation['status']),
              if (consultation['totalPrice'] != null)
                _buildDetailRow('Total Cost', 'PHP ${consultation['totalPrice'].toStringAsFixed(2)}'),
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
