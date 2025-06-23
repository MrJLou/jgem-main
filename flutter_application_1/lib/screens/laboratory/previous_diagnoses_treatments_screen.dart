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

  PatientDataSource(
      this._patients, this.context, this.onEdit, this.onViewHistory);

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
    _dataSource = PatientDataSource(
        [], context, _showEditMedicalInfoDialog, _showHistoryDialog);
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
    final medicationsController =
        TextEditingController(text: patient.currentMedications);
    final historyController =
        TextEditingController(text: patient.medicalHistory);

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
                decoration: const InputDecoration(
                    labelText: 'Allergies', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: medicationsController,
                decoration: const InputDecoration(
                    labelText: 'Current Medications',
                    border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: historyController,
                decoration: const InputDecoration(
                    labelText: 'Additional Medical History',
                    border: OutlineInputBorder()),
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
                await ApiService.updatePatient(updatedPatient,
                    source: 'PreviousDiagnosesTreatmentsScreen');
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
                      final formattedDate =
                          DateFormat.yMMMd().add_jm().format(updatedAt);
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
        SnackBar(
            content: Text('Failed to load history: $e'),
            backgroundColor: Colors.red),
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
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Loading patient data...'),
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
                        onPressed: _fetchAllPatients,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _allPatients.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No patient records found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Patient medical information will appear here',
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
                            // Header section with search
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
                                      Icon(Icons.person,
                                          color: Colors.teal[700], size: 24),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Patient Records',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal[700],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_filteredPatients.length} records',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
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
                                            'Search by name, allergies, medications, or history',
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
                            // Table section
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
                                          label: const Text('Allergies',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('Medications',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          onSort: _onSort,
                                        ),
                                        DataColumn(
                                          label: const Text('History',
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
}
