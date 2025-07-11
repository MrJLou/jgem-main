import 'dart:convert';

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
    
    // For medtech users, ensure we're always in lab test mode
    final isMedtech = widget.accessLevel.toLowerCase() == 'medtech';
    if (isMedtech) {
      _isLabTest = true;
    }
    
    _loadCurrentUserId();
    _fetchInProgressPatients();
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

  Future<void> _fetchInProgressPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _selectedPatientQueueItem = null;
      _currentStep = ConsultationStep.patientSelection;
      _resetResultsState();
    });

    try {
      // Get patients who are in progress and may need lab results
      final inProgressPatients =
          await _dbHelper.getActiveQueue(statuses: ['in_progress']);
      final servedPatients =
          await _dbHelper.getActiveQueue(statuses: ['served']);

      // Filter served patients to only include those without complete lab results
      final servedPatientsNeedingResults = <ActivePatientQueueItem>[];
      for (final patient in servedPatients) {
        if (await _patientNeedsLabResults(patient.patientId)) {
          servedPatientsNeedingResults.add(patient);
        }
      }

      // Filter in-progress patients to only include those needing lab results
      final inProgressPatientsNeedingResults = <ActivePatientQueueItem>[];
      for (final patient in inProgressPatients) {
        if (await _patientNeedsLabResults(patient.patientId)) {
          inProgressPatientsNeedingResults.add(patient);
        }
      }

      // Combine all lists and remove duplicates by queueEntryId
      final allPatients = [
        ...inProgressPatientsNeedingResults,
        ...servedPatientsNeedingResults
      ];

      // Remove duplicates based on queueEntryId to ensure no patient appears twice
      final uniquePatients = <String, ActivePatientQueueItem>{};
      for (final patient in allPatients) {
        uniquePatients[patient.queueEntryId] = patient;
      }
      final deduplicatedPatients = uniquePatients.values.toList();

      if (kDebugMode) {
        print('ConsultationResults: Found ${allPatients.length} total patients, ${deduplicatedPatients.length} unique patients');
        if (allPatients.length != deduplicatedPatients.length) {
          print('ConsultationResults: Removed ${allPatients.length - deduplicatedPatients.length} duplicate patient entries');
        }
      }

      setState(() => _inConsultationPatients = deduplicatedPatients);
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
          .getActiveQueue(statuses: ['in_progress', 'served']);
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

      // CRITICAL: Check if lab results already exist for this patient AND this specific queue entry
      // This prevents showing patients who have lab results from previous visits
      final existingResults = await _dbHelper.getAllMedicalRecords();
      final patientQueueResults = existingResults
          .where((record) =>
              record['patientId'] == patientId &&
              record['queueEntryId'] == patient.queueEntryId && // Check same queue entry
              record['recordType']?.toString().toLowerCase() == 'laboratory')
          .toList();

      // Only show patient if:
      // 1. They have lab services AND
      // 2. No lab results exist for this specific queue entry AND
      // 3. Payment has been processed (to ensure they're ready for lab work)
      return patientQueueResults.isEmpty && patient.paymentStatus == 'Paid';
    } catch (e) {
      if (kDebugMode) {
        print('Error checking lab results for patient $patientId: $e');
      }
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
        setState(() {
          _detailedPatientForResults = Patient.fromJson(patientDataMap);
          // Initialize lab controllers based on selected services
          _initializeLabControllers();
        });
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
        'appointmentId': patientQueueItem.originalAppointmentId, // Add appointment ID for tracking
        'selectedServices': patientQueueItem.selectedServices != null 
            ? jsonEncode(patientQueueItem.selectedServices) 
            : null, // Include selected services for reference
        'consultationType': _consultationType,
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'consultationNotes': _consultationNotesController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'recordType': _isLabTest ? 'laboratory' : 'consultation',
        'recordDate': now.toIso8601String(),
        'status': 'completed',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      // Add lab results if this is a lab test
      if (_isLabTest) {
        // Check if lab controllers are initialized
        if (_labResultControllers.isEmpty) {
          // No lab controllers initialized - this shouldn't happen for lab patients
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No lab test fields available. Please check patient services or switch to consultation mode.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Exit without saving
        }
        
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
          consultationData['labResults'] = jsonEncode(labResults); // Encode as JSON string for SQLite storage
        } else {
          // CRITICAL: If no lab results were entered, don't create a laboratory record
          // This prevents empty laboratory records from appearing in the system
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter lab results before saving, or switch to consultation mode.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Exit without saving
        }
      }

      // Save to medical records
      // CRITICAL: This is the ONLY place where laboratory records should be created
      // The billing/payment system should NEVER create laboratory records
      
      // Check if a medical record already exists for this specific record type
      final existingRecords = await _dbHelper.getAllMedicalRecords();
      final recordType = _isLabTest ? 'laboratory' : 'consultation';
      
      final hasExistingRecord = existingRecords.any((record) =>
        record['patientId'] == patientQueueItem.patientId &&
        record['queueEntryId'] == patientQueueItem.queueEntryId &&
        record['recordType']?.toString().toLowerCase() == recordType
      );

      if (!hasExistingRecord) {
        // Create a new record - this is the authoritative laboratory record
        await _dbHelper.insertMedicalRecord(consultationData);
        
        if (kDebugMode) {
          print('ConsultationResults: Created NEW $recordType medical record (AUTHORITATIVE for lab results)');
        }
      } else {
        // Update existing record instead of creating duplicate
        final existingRecord = existingRecords.firstWhere((record) =>
          record['patientId'] == patientQueueItem.patientId &&
          record['queueEntryId'] == patientQueueItem.queueEntryId &&
          record['recordType']?.toString().toLowerCase() == recordType
        );
        
        // Update the existing record with new data
        final updatedRecord = Map<String, dynamic>.from(existingRecord);
        updatedRecord.addAll(consultationData);
        updatedRecord['updatedAt'] = DateTime.now().toIso8601String();
        
        await _dbHelper.updateMedicalRecord(updatedRecord);
        
        if (kDebugMode) {
          print('ConsultationResults: Updated existing $recordType medical record (AUTHORITATIVE for lab results)');
        }
      }

      // Update patient queue status if needed
      // CRITICAL: This call will check lab completion and update queue status appropriately
      // Only this method should mark lab services as complete
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
        _fetchInProgressPatients();
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
    _selectedLabTests.clear();

    // Get selected services if patient is available
    List<String> serviceNames = [];
    if (_selectedPatientQueueItem != null &&
        _selectedPatientQueueItem!.selectedServices != null) {
      serviceNames = _selectedPatientQueueItem!.selectedServices!
          .map((s) => (s['name'] as String? ?? '').toLowerCase())
          .toList();
    }

    // Check which test categories are needed based on services
    final hasGlucose = _serviceContains(
        serviceNames, ['glucose', 'fbs', 'blood sugar', 'sugar', 'diabetes', 'fasting blood sugar']);
    final hasLipidProfile = _serviceContains(serviceNames,
        ['lipid', 'cholesterol', 'triglyceride', 'hdl', 'ldl', 'total cholesterol']);
    final hasKidneyFunction = _serviceContains(
        serviceNames, ['kidney', 'bun', 'creatinine', 'uric acid', 'blood urea nitrogen']);
    final hasLiverFunction = _serviceContains(serviceNames,
        ['liver', 'sgpt', 'sgot', 'alt', 'ast', 'bilirubin', 'serum glutamic pyruvic', 'serum glutamic oxaloacetic']);
    final hasCBC = _serviceContains(serviceNames,
        ['cbc', 'complete blood', 'blood count', 'platelet', 'hemoglobin', 'cbc w/ platelet']);
    final hasUrinalysis = _serviceContains(serviceNames, ['urinalysis', 'urine test', 'urine']);
    final hasVLDL = _serviceContains(serviceNames, ['vldl', 'very low density lipoprotein']);

    // Update the selected tests map
    _selectedLabTests['glucose'] = hasGlucose;
    _selectedLabTests['lipid'] = hasLipidProfile;
    _selectedLabTests['kidney'] = hasKidneyFunction;
    _selectedLabTests['liver'] = hasLiverFunction;
    _selectedLabTests['cbc'] = hasCBC;
    _selectedLabTests['urinalysis'] = hasUrinalysis;
    _selectedLabTests['vldl'] = hasVLDL;

    // Initialize glucose/blood sugar controllers - exact field names from image
    if (hasGlucose) {
      _labResultControllers['glucose'] = {
        'Fasting Blood Sugar': TextEditingController(),
      };
    }

    // Initialize lipid profile controllers - exact field names from image
    if (hasLipidProfile || hasVLDL) {
      _labResultControllers['lipid'] = {
        'Total Cholesterol': TextEditingController(),
        'Triglycerides': TextEditingController(),
        'High Density Lipoprotein (HDL)': TextEditingController(),
        'Low Density Lipoprotein (LDL)': TextEditingController(),
      };
      
      // Add VLDL only if specifically requested
      if (hasVLDL) {
        _labResultControllers['lipid']!['Very Low Density Lipoprotein (VLDL)'] = TextEditingController();
      }
    }

    // Initialize kidney function controllers - exact field names from image
    if (hasKidneyFunction) {
      _labResultControllers['kidney'] = {
        'Blood Urea Nitrogen': TextEditingController(),
        'Creatinine': TextEditingController(),
        'Blood Uric Acid': TextEditingController(),
      };
    }

    // Initialize liver function controllers - exact field names from image
    if (hasLiverFunction) {
      _labResultControllers['liver'] = {
        'Serum Glutamic Pyruvic Transaminase': TextEditingController(),
        'Serum Glutamic Oxaloacetic Transaminase': TextEditingController(),
      };
    }

    // Initialize CBC controllers - exact field names 
    if (hasCBC) {
      _labResultControllers['cbc'] = {
        'CBC W/ Platelet': TextEditingController(),
      };
    }

    // Initialize other common tests - only include if specifically requested
    final hasThyroidTests = _serviceContains(serviceNames, ['thyroid', 'tsh', 't3', 't4']);
    final hasCRP = _serviceContains(serviceNames, ['crp', 'c-reactive']);
    final hasESR = _serviceContains(serviceNames, ['esr', 'erythrocyte']);
    
    if (hasThyroidTests || hasCRP || hasESR) {
      _labResultControllers['other'] = {};
      
      if (hasThyroidTests) {
        _labResultControllers['other']!['TSH'] = TextEditingController();
        _labResultControllers['other']!['T3'] = TextEditingController();
        _labResultControllers['other']!['T4'] = TextEditingController();
      }
      
      if (hasCRP) {
        _labResultControllers['other']!['CRP'] = TextEditingController();
      }
      
      if (hasESR) {
        _labResultControllers['other']!['ESR'] = TextEditingController();
      }
    }
  }

  // Helper method to check if services contain any of the keywords
  bool _serviceContains(List<String> serviceNames, List<String> keywords) {
    for (var service in serviceNames) {
      for (var keyword in keywords) {
        if (service.contains(keyword)) {
          return true;
        }
      }
    }
    return false;
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
              onPressed: _fetchInProgressPatients,
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
          onConsultationTypeChanged: (type) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _consultationType = type);
              }
            });
          },
          onSaveResults: _saveConsultationResults,
          onBack: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedPatientQueueItem = null;
                  _currentStep = ConsultationStep.patientSelection;
                });
              }
            });
          },
          isLabTest: _isLabTest,
          onToggleType: (isLab) {
            // Use addPostFrameCallback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _isLabTest = isLab);
              }
            });
          },
          labResultControllers: _labResultControllers,
          selectedLabTests: _selectedLabTests,
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
                onPressed: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedPatientQueueItem = null;
                        _currentStep = ConsultationStep.patientSelection;
                        _resetResultsState();
                      });
                    }
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Patient List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _fetchInProgressPatients,
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
