import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/screens/consultation/widgets/consultation_patient_list.dart';
import 'package:flutter_application_1/screens/consultation/widgets/consultation_results_form.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/queue_service.dart';

enum ConsultationStep { patientSelection, recordingResults, resultsSaved }

class ConsultationResultsScreen extends StatefulWidget {
  final String accessLevel;

  const ConsultationResultsScreen({
    super.key,
    required this.accessLevel,
  });

  @override
  ConsultationResultsScreenState createState() =>
      ConsultationResultsScreenState();
}

class ConsultationResultsScreenState extends State<ConsultationResultsScreen> {
  // State Variables
  List<ActivePatientQueueItem> _inConsultationPatients = [];
  ActivePatientQueueItem? _selectedPatientQueueItem;
  Patient? _detailedPatientForResults;
  ConsultationStep _currentStep = ConsultationStep.patientSelection;

  // Loading and User Info
  bool _isLoadingPatients = true;
  String? _currentUserId;

  // Lab Results and Consultation Data
  final TextEditingController _consultationNotesController =
      TextEditingController();
  final TextEditingController _chiefComplaintController =
      TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();
  String _consultationType = 'General Consultation';
  final Map<String, Map<String, TextEditingController>> _labResultControllers =
      {};
  final Map<String, bool> _selectedLabTests = {};
  bool _isLabTest =
      true; // Track whether we're in lab test or consultation mode

  // Button loading states
  bool _isSavingResults = false;

  // Services and Helpers
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _fetchInConsultationPatients();
    _initializeLabControllers();
  }

  @override
  void dispose() {
    // Dispose of all controllers to prevent memory leaks
    _consultationNotesController.dispose();
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _prescriptionController.dispose();
    for (var map in _labResultControllers.values) {
      for (var controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  // --- DATA FETCHING AND STATE MANAGEMENT ---

  Future<void> _loadCurrentUserId() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      setState(() => _currentUserId = user.id);
    }
  }

  Future<void> _fetchInConsultationPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _selectedPatientQueueItem = null;
      _currentStep = ConsultationStep.patientSelection;
      _resetResultsState();
    });

    try {
      // Get patients in consultation AND patients who have been served but need lab results
      final consultationPatients =
          await _dbHelper.getActiveQueue(statuses: ['in_consultation']);
      final servedPatients =
          await _dbHelper.getActiveQueue(statuses: ['served']);

      // Filter served patients to only include those without complete lab results
      final servedPatientsNeedingResults = <ActivePatientQueueItem>[];
      for (final patient in servedPatients) {
        if (await _patientNeedsLabResults(patient.patientId)) {
          servedPatientsNeedingResults.add(patient);
        }
      }

      // Combine both lists
      final allPatients = [
        ...consultationPatients,
        ...servedPatientsNeedingResults
      ];

      setState(() => _inConsultationPatients = allPatients);
    } catch (e, s) {
      if (kDebugMode) print('Error fetching patients: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  // Helper method to check if a patient needs lab results
  Future<bool> _patientNeedsLabResults(String? patientId) async {
    if (patientId == null) return false;

    try {
      // Get fresh patient data to check services
      final patients = await _dbHelper
          .getActiveQueue(statuses: ['in_consultation', 'served']);
      final patient =
          patients.where((p) => p.patientId == patientId).firstOrNull;

      if (patient == null) return false;

      final selectedServices = patient.selectedServices ?? [];
      final serviceNames = selectedServices
          .map((s) => (s['name'] as String? ?? '').toLowerCase())
          .toList();

      // Check if any services require lab work
      final hasLabServices = serviceNames.any((service) =>
          service.contains('lab') ||
          service.contains('blood') ||
          service.contains('glucose') ||
          service.contains('cholesterol') ||
          service.contains('cbc') ||
          service.contains('urine') ||
          service.contains('kidney') ||
          service.contains('liver'));

      if (!hasLabServices) return false;

      // Check if lab results already exist for this patient
      final existingResults = await _dbHelper.getAllMedicalRecords();
      final patientResults = existingResults
          .where((record) =>
              record['patientId'] == patientId &&
              record['recordType']?.toString().toLowerCase() == 'laboratory')
          .toList();

      // If no lab results exist, patient needs lab results
      return patientResults.isEmpty;
    } catch (e) {
      if (kDebugMode)
        print('Error checking lab results for patient $patientId: $e');
      return false; // Default to not needing results if we can't determine
    }
  }

  Future<void> _fetchPatientDetails(String? patientId) async {
    if (patientId == null || patientId.isEmpty) {
      setState(() => _detailedPatientForResults = null);
      return;
    }

    try {
      final patientDataMap = await _dbHelper.getPatient(patientId);
      if (mounted && patientDataMap != null) {
        setState(() =>
            _detailedPatientForResults = Patient.fromJson(patientDataMap));
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching patient details: $e");
    }
  }

  void _resetResultsState() {
    setState(() {
      _consultationNotesController.clear();
      _chiefComplaintController.clear();
      _diagnosisController.clear();
      _prescriptionController.clear();
      _consultationType = 'General Consultation';
      _labResultControllers.clear();
      _selectedLabTests.clear();
      _isLabTest = true;
    });
    _initializeLabControllers();
  }

  // --- CORE BUSINESS LOGIC ---

  void _saveConsultationResults() async {
    if (_selectedPatientQueueItem == null || _currentUserId == null) return;

    setState(() => _isSavingResults = true);

    try {
      final patientQueueItem = _selectedPatientQueueItem!;
      final now = DateTime.now();

      // Prepare consultation data
      Map<String, dynamic> consultationData = {
        'patientId': patientQueueItem.patientId,
        'doctorId': _currentUserId!,
        'queueEntryId': patientQueueItem.queueEntryId,
        'consultationType': _consultationType,
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'consultationNotes': _consultationNotesController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'recordType': _isLabTest ? 'Laboratory' : 'Consultation',
        'recordDate': now.toIso8601String(),
        'status': 'completed',
      };

      // Add lab results if this is a lab test
      if (_isLabTest && _labResultControllers.isNotEmpty) {
        Map<String, dynamic> labResults = {};

        for (var testCategory in _labResultControllers.keys) {
          Map<String, String> categoryResults = {};
          for (var testName in _labResultControllers[testCategory]!.keys) {
            final controller = _labResultControllers[testCategory]![testName]!;
            if (controller.text.trim().isNotEmpty) {
              categoryResults[testName] = controller.text.trim();
            }
          }
          if (categoryResults.isNotEmpty) {
            labResults[testCategory] = categoryResults;
          }
        }

        if (labResults.isNotEmpty) {
          consultationData['labResults'] = labResults;
        }
      }

      // Save to medical records
      await _dbHelper.insertMedicalRecord(consultationData);

      // Update patient queue status if needed
      await _queueService.markConsultationComplete(
        patientQueueItem.queueEntryId,
        patientQueueItem.patientId!,
        _currentUserId!,
      );

      if (mounted) {
        setState(() => _currentStep = ConsultationStep.resultsSaved);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_isLabTest ? 'Lab results' : 'Consultation notes'} saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the patient list
        _fetchInConsultationPatients();
      }
    } catch (e) {
      if (kDebugMode) print('Error saving consultation results: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingResults = false);
    }
  }

  void _initializeLabControllers() {
    // Clear any existing controllers first to prevent memory leaks
    _labResultControllers.forEach((_, controllers) {
      controllers.forEach((_, controller) => controller.dispose());
    });
    _labResultControllers.clear();

    // Initialize blood sugar controllers
    _labResultControllers['glucose'] = {
      'FBS': TextEditingController(),
      'RBS': TextEditingController(),
      'HbA1c': TextEditingController(),
      '2hPP': TextEditingController(), // 2-hour post-prandial
    };

    // Initialize lipid profile controllers
    _labResultControllers['lipid'] = {
      'Total Cholesterol': TextEditingController(),
      'HDL': TextEditingController(),
      'LDL': TextEditingController(),
      'Triglycerides': TextEditingController(),
      'VLDL': TextEditingController(),
    };

    // Initialize kidney function controllers
    _labResultControllers['kidney'] = {
      'BUN': TextEditingController(),
      'Creatinine': TextEditingController(),
      'Uric Acid': TextEditingController(),
      'Protein': TextEditingController(),
      'Albumin': TextEditingController(),
    };

    // Initialize liver function controllers
    _labResultControllers['liver'] = {
      'SGPT/ALT': TextEditingController(),
      'SGOT/AST': TextEditingController(),
      'Total Bilirubin': TextEditingController(),
      'Direct Bilirubin': TextEditingController(),
      'Indirect Bilirubin': TextEditingController(),
      'Alkaline Phosphatase': TextEditingController(),
    };

    // Initialize CBC controllers
    _labResultControllers['cbc'] = {
      'WBC': TextEditingController(),
      'RBC': TextEditingController(),
      'Hemoglobin': TextEditingController(),
      'Hematocrit': TextEditingController(),
      'Platelet Count': TextEditingController(),
      'MCV': TextEditingController(),
      'MCH': TextEditingController(),
      'MCHC': TextEditingController(),
      'RDW': TextEditingController(),
      'Neutrophils': TextEditingController(),
      'Lymphocytes': TextEditingController(),
      'Monocytes': TextEditingController(),
      'Eosinophils': TextEditingController(),
      'Basophils': TextEditingController(),
    };

    // Initialize urinalysis controllers
    _labResultControllers['urinalysis'] = {
      'Color': TextEditingController(),
      'Transparency': TextEditingController(),
      'Specific Gravity': TextEditingController(),
      'pH': TextEditingController(),
      'Protein': TextEditingController(),
      'Glucose': TextEditingController(),
      'Ketones': TextEditingController(),
      'Blood': TextEditingController(),
      'Leukocyte Esterase': TextEditingController(),
      'Nitrites': TextEditingController(),
      'WBC/hpf': TextEditingController(),
      'RBC/hpf': TextEditingController(),
      'Bacteria': TextEditingController(),
      'Epithelial Cells': TextEditingController(),
    };

    // Initialize other common tests
    _labResultControllers['other'] = {
      'ESR': TextEditingController(),
      'CRP': TextEditingController(),
      'TSH': TextEditingController(),
      'FT3': TextEditingController(),
      'FT4': TextEditingController(),
      'PSA': TextEditingController(),
    };
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_isLabTest ? 'Laboratory' : 'Consultation'} Results',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedPatientQueueItem != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchInConsultationPatients,
              tooltip: 'Refresh Patient List',
            ),
        ],
      ),
      body: _isLoadingPatients
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left panel - Patient list
                SizedBox(
                  width: 350,
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4.0),
                              topRight: Radius.circular(4.0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.people, color: Colors.teal[700]),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Patients in Consultation & Awaiting Lab Results',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ConsultationPatientList(
                            patients: _inConsultationPatients,
                            selectedPatient: _selectedPatientQueueItem,
                            onPatientSelected: (patient) {
                              setState(() {
                                _selectedPatientQueueItem = patient;
                                _currentStep =
                                    ConsultationStep.recordingResults;
                              });
                              _fetchPatientDetails(patient.patientId);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right panel - Results form
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: _buildRightPaneContent(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRightPaneContent() {
    if (_selectedPatientQueueItem == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a patient to record results',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    switch (_currentStep) {
      case ConsultationStep.patientSelection:
        return const Center(
          child: Text('Select a patient from the left panel'),
        );

      case ConsultationStep.recordingResults:
        return ConsultationResultsForm(
          patient: _selectedPatientQueueItem!,
          detailedPatient: _detailedPatientForResults,
          consultationNotesController: _consultationNotesController,
          chiefComplaintController: _chiefComplaintController,
          diagnosisController: _diagnosisController,
          prescriptionController: _prescriptionController,
          consultationType: _consultationType,
          onConsultationTypeChanged: (type) =>
              setState(() => _consultationType = type),
          onSaveResults: _saveConsultationResults,
          onBack: () => setState(() {
            _selectedPatientQueueItem = null;
            _currentStep = ConsultationStep.patientSelection;
          }),
          isLabTest: _isLabTest,
          onToggleType: (isLab) => setState(() => _isLabTest = isLab),
          labResultControllers: _labResultControllers,
          isLoading: _isSavingResults,
          accessLevel: widget.accessLevel,
        );

      case ConsultationStep.resultsSaved:
        return _buildResultsSavedContent();
    }
  }

  Widget _buildResultsSavedContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green[600],
          ),
          const SizedBox(height: 16),
          Text(
            '${_isLabTest ? 'Lab Results' : 'Consultation Notes'} Saved Successfully',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The ${_isLabTest ? 'lab results' : 'consultation notes'} for ${_selectedPatientQueueItem?.patientName} have been recorded.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _selectedPatientQueueItem = null;
                  _currentStep = ConsultationStep.patientSelection;
                  _resetResultsState();
                }),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Patient List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _fetchInConsultationPatients,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
