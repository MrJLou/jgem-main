import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

class PreviousDiagnosesTreatmentsScreen extends StatefulWidget {
  const PreviousDiagnosesTreatmentsScreen({super.key});

  @override
  PreviousDiagnosesTreatmentsScreenState createState() =>
      PreviousDiagnosesTreatmentsScreenState();
}

class PatientDataSource extends DataTableSource {
  List<Patient> _patients;
  final BuildContext context;
  final Function(Patient) onEdit;
  final Function(Patient) onViewHistory;

  PatientDataSource(this._patients, this.context, this.onEdit, this.onViewHistory);

  void updateData(List<Patient> newData) {
    _patients = newData;
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final patient = _patients[index];
    return DataRow(cells: [
      DataCell(Text(patient.fullName)),
      DataCell(Text(patient.allergies ?? 'N/A')),
      DataCell(Text(patient.currentMedications ?? 'N/A')),
      DataCell(Text(patient.medicalHistory ?? 'N/A')),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => onEdit(patient),
              tooltip: 'Edit Medical Info',
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.teal),
              onPressed: () => onViewHistory(patient),
              tooltip: 'View History',
            ),
          ],
        ),
      ),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _patients.length;

  @override
  int get selectedRowCount => 0;

  void sort<T>(Comparable<T> Function(Patient d) getField, bool ascending) {
    _patients.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    notifyListeners();
  }
}

class PreviousDiagnosesTreatmentsScreenState
    extends State<PreviousDiagnosesTreatmentsScreen> {
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();
  late PatientDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = PatientDataSource([], context, _showEditMedicalInfoDialog, _showHistoryDialog);
    _fetchAllPatients();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPatients);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allPatients = await ApiService.getPatients();
      allPatients.sort((a, b) => a.fullName.compareTo(b.fullName));

      if (!mounted) return;
      setState(() {
        _allPatients = allPatients;
        _filteredPatients = allPatients;
        _dataSource.updateData(_filteredPatients);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load patient data: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _allPatients.where((patient) {
        return patient.fullName.toLowerCase().contains(query) ||
            (patient.allergies?.toLowerCase() ?? '').contains(query) ||
            (patient.currentMedications?.toLowerCase() ?? '').contains(query) ||
            (patient.medicalHistory?.toLowerCase() ?? '').contains(query);
      }).toList();
      _dataSource.updateData(_filteredPatients);
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });

    _dataSource.sort<String>((p) {
      switch (columnIndex) {
        case 0:
          return p.fullName;
        case 1:
          return p.allergies ?? '';
        case 2:
          return p.currentMedications ?? '';
        case 3:
          return p.medicalHistory ?? '';
        default:
          return '';
      }
    }, ascending);
  }

  void _showEditMedicalInfoDialog(Patient patient) {
    final allergiesController = TextEditingController(text: patient.allergies);
    final medicationsController = TextEditingController(text: patient.currentMedications);
    final historyController = TextEditingController(text: patient.medicalHistory);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Medical Info for ${patient.fullName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: allergiesController,
                decoration: const InputDecoration(labelText: 'Allergies', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: medicationsController,
                decoration: const InputDecoration(labelText: 'Current Medications', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: historyController,
                decoration: const InputDecoration(labelText: 'Additional Medical History', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);

              final updatedPatient = patient.copyWith(
                allergies: allergiesController.text,
                currentMedications: medicationsController.text,
                medicalHistory: historyController.text,
                updatedAt: DateTime.now(),
              );

              try {
                await ApiService.updatePatient(updatedPatient, source: 'PreviousDiagnosesTreatmentsScreen');
                if (!mounted) return;
                navigator.pop();
                _fetchAllPatients();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Medical info updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to update info: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(Patient patient) async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final history = await ApiService.getPatientHistory(patient.id);
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading indicator

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Update History for ${patient.fullName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: history.isEmpty
                ? const Center(child: Text('No history found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      final updatedAt = DateTime.parse(record['updatedAt']);
                      final formattedDate = DateFormat.yMMMd().add_jm().format(updatedAt);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            'Field: ${record['fieldName']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Old: "${record['oldValue']}"\nNew: "${record['newValue']}"\nOn: $formattedDate by ${record['updatedByUserId'] ?? 'Unknown'} from ${record['sourceOfChange'] ?? 'Unknown'}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load history: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Patient Medical Information',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllPatients,
            tooltip: 'Refresh Patient List',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _allPatients.isEmpty
                  ? const Center(child: Text('No patients found.'))
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1600),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      labelText: 'Search Patients',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: PaginatedDataTable(
                                      header: const Text('Patient Records'),
                                      rowsPerPage: 10,
                                      showCheckboxColumn: false,
                                      sortColumnIndex: _sortColumnIndex,
                                      sortAscending: _sortAscending,
                                      columns: [
                                        DataColumn(
                                            label: const Text('Patient'),
                                            onSort: _onSort),
                                        DataColumn(
                                            label: const Text('Allergies'),
                                            onSort: _onSort),
                                        DataColumn(
                                            label: const Text('Medications'),
                                            onSort: _onSort),
                                        DataColumn(
                                            label: const Text('History'),
                                            onSort: _onSort),
                                        const DataColumn(
                                            label: Text('Actions')),
                                      ],
                                      source: _dataSource,
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

