import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/patient.dart';

class ConsultationResultsForm extends StatefulWidget {
  final ActivePatientQueueItem patient;
  final Patient? detailedPatient;
  final TextEditingController consultationNotesController;
  final TextEditingController chiefComplaintController;
  final TextEditingController diagnosisController;
  final TextEditingController prescriptionController;
  final String consultationType;
  final Function(String) onConsultationTypeChanged;
  final VoidCallback onSaveResults;
  final VoidCallback onBack;
  final bool isLabTest;
  final Function(bool) onToggleType;
  final Map<String, Map<String, TextEditingController>> labResultControllers;
  final bool isLoading;
  final String accessLevel;

  const ConsultationResultsForm({
    super.key,
    required this.patient,
    this.detailedPatient,
    required this.consultationNotesController,
    required this.chiefComplaintController,
    required this.diagnosisController,
    required this.prescriptionController,
    required this.consultationType,
    required this.onConsultationTypeChanged,
    required this.onSaveResults,
    required this.onBack,
    required this.isLabTest,
    required this.onToggleType,
    required this.labResultControllers,
    this.isLoading = false,
    required this.accessLevel,
  });

  @override
  State<ConsultationResultsForm> createState() =>
      _ConsultationResultsFormState();
}

class _ConsultationResultsFormState extends State<ConsultationResultsForm>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Method to clear all lab result fields with confirmation
  void _clearLabResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Lab Results'),
        content: const Text('Are you sure you want to clear all lab result fields?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Clear all lab result controllers
              widget.labResultControllers.forEach((category, fields) {
                fields.forEach((fieldName, controller) {
                  controller.clear();
                });
              });
              
              // Show a snackbar to confirm the action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All lab result fields have been cleared'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Method to clear consultation form fields with confirmation
  void _clearConsultationFields() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Consultation Form'),
        content: const Text('Are you sure you want to clear all consultation fields?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Clear all consultation fields
              widget.consultationNotesController.clear();
              widget.chiefComplaintController.clear();
              widget.diagnosisController.clear();
              widget.prescriptionController.clear();
              
              // Reset consultation type to default
              widget.onConsultationTypeChanged('General Consultation');
              
              // Show a snackbar to confirm the action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Consultation form has been cleared'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Method to clear all forms with confirmation
  void _clearAllForms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Forms'),
        content: const Text('Are you sure you want to clear all form fields? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Clear lab results
              _clearLabResults();
              
              // Clear consultation fields
              _clearConsultationFields();
              
              // Show a snackbar to confirm the action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All forms have been cleared'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set initial tab based on access level and selected type
    if (widget.accessLevel.toLowerCase() == 'medtech') {
      _tabController.index = 0; // Default to lab tests for medtech
    } else {
      _tabController.index = widget.isLabTest ? 0 : 1;
    }

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        widget.onToggleType(_tabController.index == 0);
      }
    });
    
    // Set default values for non-relevant fields on initialization
    _setDefaultValueForNonRelevantFields();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Information Header
          _buildPatientInfoHeader(),

          const SizedBox(height: 20),

          // Tab selector for Lab Test vs Consultation
          _buildTabSelector(),

          const SizedBox(height: 20),

          // Tab content
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLabTestForm(),
                _buildConsultationForm(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPatientInfoHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Patient info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal[600],
                      child: Text(
                        widget.patient.patientName.isNotEmpty
                            ? widget.patient.patientName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patient.patientName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Queue #${widget.patient.queueNumber} • ID: ${widget.patient.patientId ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (widget.patient.age != null ||
                            widget.patient.gender != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${widget.patient.age ?? 'Unknown'} years old • ${widget.patient.gender ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                // Clear all button
                ElevatedButton.icon(
                  onPressed: _clearAllForms,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All Forms'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[800],
                    elevation: 0,
                  ),
                ),
              ],
            ),
            if (widget.patient.selectedServices != null &&
                widget.patient.selectedServices!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Selected Services:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: widget.patient.selectedServices!.map((service) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Text(
                      service['name'] ?? 'Unknown Service',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.teal[600],
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[700],
        tabs: const [
          Tab(
            icon: Icon(Icons.science),
            text: 'Laboratory Results',
          ),
          Tab(
            icon: Icon(Icons.medical_services),
            text: 'Consultation Notes',
          ),
        ],
      ),
    );
  }

  Widget _buildLabTestForm() {
    // Get selected services to determine which tests to show
    final selectedServices = widget.patient.selectedServices ?? [];
    final serviceNames = selectedServices
        .map((s) => (s['name'] as String? ?? '').toLowerCase())
        .toList();

    // Check if specific services are selected
    final hasCBC = _serviceContains(
        serviceNames, ['cbc', 'complete blood', 'blood count', 'platelet']);
    final hasGlucose = _serviceContains(
        serviceNames, ['glucose', 'fbs', 'blood sugar', 'sugar', 'diabetes']);
    final hasLipidProfile = _serviceContains(
        serviceNames, ['lipid', 'cholesterol', 'triglyceride', 'hdl', 'ldl']);
    final hasKidneyFunction = _serviceContains(
        serviceNames, ['kidney', 'bun', 'creatinine', 'uric acid', 'renal']);
    final hasLiverFunction = _serviceContains(
        serviceNames, ['liver', 'sgpt', 'sgot', 'alt', 'ast', 'hepatic']);
    final hasUrinalysis = _serviceContains(
        serviceNames, ['urine', 'urinalysis', 'ua', 'urinalysys']);
    final hasOtherTests =
        _serviceContains(serviceNames, ['esr', 'crp', 'tsh', 'thyroid', 'psa']);
        
    // Apply default values for non-relevant fields each time the form is built
    // to ensure fields are properly disabled/enabled
    _setDefaultValueForNonRelevantFields();

    // If no specific lab services are detected, show all categories for manual selection
    final showAllCategories = !hasCBC &&
        !hasGlucose &&
        !hasLipidProfile &&
        !hasKidneyFunction &&
        !hasLiverFunction &&
        !hasUrinalysis &&
        !hasOtherTests;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Laboratory Test Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _clearLabResults,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Form'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[800],
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Lab test selection info
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Lab Test Information',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Patient: ${widget.patient.patientName}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Services: ${serviceNames.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          // Conditional sections based on selected services

          // Glucose/Blood Sugar Section
          if (hasGlucose || showAllCategories) ...[
            _buildTestSection(
              title: 'Blood Sugar Panel',
              icon: Icons.bloodtype_outlined,
              color: Colors.red.shade800,
              isEnabled: hasGlucose,
              children: [
                _buildLabResultField(
                    'FBS (mg/dL)',
                    widget.labResultControllers['glucose']?['FBS'] ??
                        TextEditingController(),
                    'Normal: 70-100 mg/dL',
                    enabled: hasGlucose || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'RBS (mg/dL)',
                    widget.labResultControllers['glucose']?['RBS'] ??
                        TextEditingController(),
                    'Normal: <140 mg/dL',
                    enabled: hasGlucose || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'HbA1c (%)',
                    widget.labResultControllers['glucose']?['HbA1c'] ??
                        TextEditingController(),
                    'Normal: <5.7%',
                    enabled: hasGlucose || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    '2hPP (mg/dL)',
                    widget.labResultControllers['glucose']?['2hPP'] ??
                        TextEditingController(),
                    'Normal: <140 mg/dL (2-hour post-prandial)',
                    enabled: hasGlucose || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Lipid Profile Section
          if (hasLipidProfile || showAllCategories) ...[
            _buildTestSection(
              title: 'Lipid Profile',
              icon: Icons.water_drop_outlined,
              color: Colors.orange.shade800,
              isEnabled: hasLipidProfile,
              children: [
                _buildLabResultField(
                    'Total Cholesterol (mg/dL)',
                    widget.labResultControllers['lipid']
                            ?['Total Cholesterol'] ??
                        TextEditingController(),
                    'Normal: <200 mg/dL',
                    enabled: hasLipidProfile || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'HDL (mg/dL)',
                    widget.labResultControllers['lipid']?['HDL'] ??
                        TextEditingController(),
                    'Normal: >40 mg/dL (M), >50 mg/dL (F)',
                    enabled: hasLipidProfile || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'LDL (mg/dL)',
                    widget.labResultControllers['lipid']?['LDL'] ??
                        TextEditingController(),
                    'Normal: <100 mg/dL',
                    enabled: hasLipidProfile || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Triglycerides (mg/dL)',
                    widget.labResultControllers['lipid']?['Triglycerides'] ??
                        TextEditingController(),
                    'Normal: <150 mg/dL',
                    enabled: hasLipidProfile || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'VLDL (mg/dL)',
                    widget.labResultControllers['lipid']?['VLDL'] ??
                        TextEditingController(),
                    'Normal: 5-40 mg/dL',
                    enabled: hasLipidProfile || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Kidney Function Section
          if (hasKidneyFunction || showAllCategories) ...[
            _buildTestSection(
              title: 'Kidney Function Tests',
              icon: Icons.filter_alt_outlined,
              color: Colors.green.shade800,
              isEnabled: hasKidneyFunction,
              children: [
                _buildLabResultField(
                    'BUN (mg/dL)',
                    widget.labResultControllers['kidney']?['BUN'] ??
                        TextEditingController(),
                    'Normal: 7-20 mg/dL',
                    enabled: (hasKidneyFunction || hasLiverFunction || showAllCategories)),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Creatinine (mg/dL)',
                    widget.labResultControllers['kidney']?['Creatinine'] ??
                        TextEditingController(),
                    'Normal: 0.6-1.2 mg/dL',
                    enabled: hasKidneyFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Uric Acid (mg/dL)',
                    widget.labResultControllers['kidney']?['Uric Acid'] ??
                        TextEditingController(),
                    'Normal: 3.4-7.0 mg/dL',
                    enabled: hasKidneyFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Protein (mg/dL)',
                    widget.labResultControllers['kidney']?['Protein'] ??
                        TextEditingController(),
                    'Normal: 6.0-8.3 mg/dL',
                    enabled: hasKidneyFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Albumin (g/dL)',
                    widget.labResultControllers['kidney']?['Albumin'] ??
                        TextEditingController(),
                    'Normal: 3.5-5.0 g/dL',
                    enabled: hasKidneyFunction || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Liver Function Section
          if (hasLiverFunction || showAllCategories) ...[
            _buildTestSection(
              title: 'Liver Function Tests',
              icon: Icons.monitor_heart_outlined,
              color: Colors.purple.shade800,
              isEnabled: hasLiverFunction,
              children: [
                _buildLabResultField(
                    'SGPT/ALT (U/L)',
                    widget.labResultControllers['liver']?['SGPT/ALT'] ??
                        TextEditingController(),
                    'Normal: 7-56 U/L',
                    enabled: hasLiverFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'SGOT/AST (U/L)',
                    widget.labResultControllers['liver']?['SGOT/AST'] ??
                        TextEditingController(),
                    'Normal: 10-40 U/L',
                    enabled: hasLiverFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Total Bilirubin (mg/dL)',
                    widget.labResultControllers['liver']?['Total Bilirubin'] ??
                        TextEditingController(),
                    'Normal: 0.2-1.2 mg/dL',
                    enabled: hasLiverFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Direct Bilirubin (mg/dL)',
                    widget.labResultControllers['liver']?['Direct Bilirubin'] ??
                        TextEditingController(),
                    'Normal: 0.0-0.3 mg/dL',
                    enabled: hasLiverFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Indirect Bilirubin (mg/dL)',
                    widget.labResultControllers['liver']
                            ?['Indirect Bilirubin'] ??
                        TextEditingController(),
                    'Normal: 0.2-0.8 mg/dL',
                    enabled: hasLiverFunction || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Alkaline Phosphatase (U/L)',
                    widget.labResultControllers['liver']
                            ?['Alkaline Phosphatase'] ??
                        TextEditingController(),
                    'Normal: 44-147 U/L',
                    enabled: hasLiverFunction || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // CBC Section
          if (hasCBC || showAllCategories) ...[
            _buildTestSection(
              title: 'Complete Blood Count (CBC)',
              icon: Icons.colorize_outlined,
              color: Colors.indigo.shade800,
              isEnabled: hasCBC,
              children: [
                _buildLabResultField(
                    'WBC (x10³/μL)',
                    widget.labResultControllers['cbc']?['WBC'] ??
                        TextEditingController(),
                    'Normal: 4.5-11.0 x10³/μL',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'RBC (x10⁶/μL)',
                    widget.labResultControllers['cbc']?['RBC'] ??
                        TextEditingController(),
                    'Normal: 4.5-5.9 x10⁶/μL',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Hemoglobin (g/dL)',
                    widget.labResultControllers['cbc']?['Hemoglobin'] ??
                        TextEditingController(),
                    'Normal: 12-16 g/dL',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Hematocrit (%)',
                    widget.labResultControllers['cbc']?['Hematocrit'] ??
                        TextEditingController(),
                    'Normal: 36-46%',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Platelet Count (x10³/μL)',
                    widget.labResultControllers['cbc']?['Platelet Count'] ??
                        TextEditingController(),
                    'Normal: 150-450 x10³/μL',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 16),
                const Text(
                  'Red Blood Cell Indices',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildLabResultField(
                    'MCV (fL)',
                    widget.labResultControllers['cbc']?['MCV'] ??
                        TextEditingController(),
                    'Normal: 80-100 fL',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'MCH (pg)',
                    widget.labResultControllers['cbc']?['MCH'] ??
                        TextEditingController(),
                    'Normal: 27-31 pg',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'MCHC (g/dL)',
                    widget.labResultControllers['cbc']?['MCHC'] ??
                        TextEditingController(),
                    'Normal: 32-36 g/dL',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'RDW (%)',
                    widget.labResultControllers['cbc']?['RDW'] ??
                        TextEditingController(),
                    'Normal: 11.5-14.5%',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 16),
                const Text(
                  'White Blood Cell Differential',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildLabResultField(
                    'Neutrophils (%)',
                    widget.labResultControllers['cbc']?['Neutrophils'] ??
                        TextEditingController(),
                    'Normal: 50-70%',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Lymphocytes (%)',
                    widget.labResultControllers['cbc']?['Lymphocytes'] ??
                        TextEditingController(),
                    'Normal: 20-40%',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Monocytes (%)',
                    widget.labResultControllers['cbc']?['Monocytes'] ??
                        TextEditingController(),
                    'Normal: 2-8%',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Eosinophils (%)',
                    widget.labResultControllers['cbc']?['Eosinophils'] ??
                        TextEditingController(),
                    'Normal: 1-4%',
                    enabled: hasCBC || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Basophils (%)',
                    widget.labResultControllers['cbc']?['Basophils'] ??
                        TextEditingController(),
                    'Normal: 0.5-1%',
                    enabled: hasCBC || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Urinalysis Section
          if (hasUrinalysis || showAllCategories) ...[
            _buildTestSection(
              title: 'Urinalysis',
              icon: Icons.science_outlined,
              color: Colors.brown.shade800,
              isEnabled: hasUrinalysis,
              children: [
                const Text(
                  'Physical Examination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildLabResultField(
                    'Color',
                    widget.labResultControllers['urinalysis']?['Color'] ??
                        TextEditingController(),
                    'Normal: Yellow',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Transparency',
                    widget.labResultControllers['urinalysis']
                            ?['Transparency'] ??
                        TextEditingController(),
                    'Normal: Clear',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Specific Gravity',
                    widget.labResultControllers['urinalysis']
                            ?['Specific Gravity'] ??
                        TextEditingController(),
                    'Normal: 1.003-1.030',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 16),
                const Text(
                  'Chemical Examination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildLabResultField(
                    'pH',
                    widget.labResultControllers['urinalysis']?['pH'] ??
                        TextEditingController(),
                    'Normal: 4.5-8.0',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Protein',
                    widget.labResultControllers['urinalysis']?['Protein'] ??
                        TextEditingController(),
                    'Normal: Negative',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Glucose',
                    widget.labResultControllers['urinalysis']?['Glucose'] ??
                        TextEditingController(),
                    'Normal: Negative',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Ketones',
                    widget.labResultControllers['urinalysis']?['Ketones'] ??
                        TextEditingController(),
                    'Normal: Negative',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Blood',
                    widget.labResultControllers['urinalysis']?['Blood'] ??
                        TextEditingController(),
                    'Normal: Negative',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Leukocyte Esterase',
                    widget.labResultControllers['urinalysis']
                            ?['Leukocyte Esterase'] ??
                        TextEditingController(),
                    'Normal: Negative',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Nitrites',
                    widget.labResultControllers['urinalysis']?['Nitrites'] ??
                        TextEditingController(),
                    'Normal: Negative',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 16),
                const Text(
                  'Microscopic Examination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildLabResultField(
                    'WBC/hpf',
                    widget.labResultControllers['urinalysis']?['WBC/hpf'] ??
                        TextEditingController(),
                    'Normal: 0-5/hpf',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'RBC/hpf',
                    widget.labResultControllers['urinalysis']?['RBC/hpf'] ??
                        TextEditingController(),
                    'Normal: 0-2/hpf',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Bacteria',
                    widget.labResultControllers['urinalysis']?['Bacteria'] ??
                        TextEditingController(),
                    'Normal: Few',
                    enabled: hasUrinalysis || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'Epithelial Cells',
                    widget.labResultControllers['urinalysis']
                            ?['Epithelial Cells'] ??
                        TextEditingController(),
                    'Normal: Few',
                    enabled: hasUrinalysis || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Other Common Tests Section
          if (hasOtherTests || showAllCategories) ...[
            _buildTestSection(
              title: 'Other Common Tests',
              icon: Icons.biotech_outlined,
              color: Colors.teal.shade800,
              isEnabled: hasOtherTests,
              children: [
                _buildLabResultField(
                    'ESR (mm/hr)',
                    widget.labResultControllers['other']?['ESR'] ??
                        TextEditingController(),
                    'Normal: <20 mm/hr (M), <30 mm/hr (F)',
                    enabled: hasOtherTests || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'CRP (mg/L)',
                    widget.labResultControllers['other']?['CRP'] ??
                        TextEditingController(),
                    'Normal: <3.0 mg/L',
                    enabled: hasOtherTests || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'TSH (mIU/L)',
                    widget.labResultControllers['other']?['TSH'] ??
                        TextEditingController(),
                    'Normal: 0.4-4.0 mIU/L',
                    enabled: hasOtherTests || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'FT3 (pg/mL)',
                    widget.labResultControllers['other']?['FT3'] ??
                        TextEditingController(),
                    'Normal: 2.3-4.2 pg/mL',
                    enabled: hasOtherTests || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'FT4 (ng/dL)',
                    widget.labResultControllers['other']?['FT4'] ??
                        TextEditingController(),
                    'Normal: 0.8-1.8 ng/dL',
                    enabled: hasOtherTests || showAllCategories),
                const SizedBox(height: 12),
                _buildLabResultField(
                    'PSA (ng/mL)',
                    widget.labResultControllers['other']?['PSA'] ??
                        TextEditingController(),
                    'Normal: <4.0 ng/mL',
                    enabled: hasOtherTests || showAllCategories),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // If no lab tests were selected
          if (!hasCBC &&
              !hasGlucose &&
              !hasLipidProfile &&
              !hasKidneyFunction &&
              !hasLiverFunction &&
              !hasUrinalysis &&
              !hasOtherTests &&
              !showAllCategories) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[700], size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'No specific lab tests detected',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'The selected services do not contain recognizable laboratory test types. Any fields below will be autofilled with "0" and marked as non-editable. You can also record general consultation notes in the Consultation tab.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsultationForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Consultation Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _clearConsultationFields,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Form'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[800],
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Consultation Type
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consultation Type',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: widget.consultationType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'General Consultation',
                        child: Text('General Consultation')),
                    DropdownMenuItem(
                        value: 'Follow-up', child: Text('Follow-up')),
                    DropdownMenuItem(
                        value: 'Emergency', child: Text('Emergency')),
                    DropdownMenuItem(
                        value: 'Specialist Consultation',
                        child: Text('Specialist Consultation')),
                    DropdownMenuItem(
                        value: 'Routine Check-up',
                        child: Text('Routine Check-up')),
                  ],
                  onChanged: (value) => widget.onConsultationTypeChanged(
                      value ?? 'General Consultation'),
                ),
              ],
            ),
          ),

          // Chief Complaint
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chief Complaint',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: widget.chiefComplaintController,
                  decoration: InputDecoration(
                    hintText: 'Patient\'s main concern or reason for visit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),

          // Diagnosis
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diagnosis',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: widget.diagnosisController,
                  decoration: InputDecoration(
                    hintText: 'Medical diagnosis or assessment',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),

          // Consultation Notes
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consultation Notes',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: widget.consultationNotesController,
                decoration: InputDecoration(
                  hintText:
                      'Detailed consultation notes, findings, recommendations, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 4,
              ),
            ],
          ),

          // Prescription/Medication
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medication, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Prescription / Medication',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.prescriptionController,
                  decoration: InputDecoration(
                    hintText:
                        'Prescribed medications, dosage, and instructions',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool isEnabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isEnabled ? color.withOpacity(0.3) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: isEnabled ? color.withOpacity(0.03) : null,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        iconColor: color,
        collapsedIconColor: color,
        backgroundColor: Colors.grey.shade50,
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }

  Widget _buildLabResultField(
      String label, TextEditingController controller, String hintText, {bool enabled = true}) {
    // If disabled, set a default value of "0" if the field is empty
    if (!enabled && controller.text.isEmpty) {
      controller.text = "0";
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? null : Colors.grey[500],
                ),
              ),
            ),
            if (!enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  'Autofilled',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: enabled ? Colors.grey[400]! : Colors.grey[300]!,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          style: TextStyle(
            color: enabled ? Colors.black87 : Colors.grey[600],
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: widget.isLoading ? null : widget.onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
        ),
        ElevatedButton.icon(
          onPressed: widget.isLoading ? null : widget.onSaveResults,
          icon: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(widget.isLoading
              ? 'Saving...'
              : 'Save ${widget.isLabTest ? 'Lab Results' : 'Consultation Notes'}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Helper method to check if any keywords are contained in the service names
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

  // Helper method to set default values for non-relevant fields
  void _setDefaultValueForNonRelevantFields() {
    // Get selected services to determine which tests to show
    final selectedServices = widget.patient.selectedServices ?? [];
    final serviceNames = selectedServices
        .map((s) => (s['name'] as String? ?? '').toLowerCase())
        .toList();

    // Check if specific services are selected
    final hasCBC = _serviceContains(
        serviceNames, ['cbc', 'complete blood', 'blood count', 'platelet']);
    final hasGlucose = _serviceContains(
        serviceNames, ['glucose', 'fbs', 'blood sugar', 'sugar', 'diabetes']);
    final hasLipidProfile = _serviceContains(
        serviceNames, ['lipid', 'cholesterol', 'triglyceride', 'hdl', 'ldl']);
    final hasKidneyFunction = _serviceContains(
        serviceNames, ['kidney', 'bun', 'creatinine', 'uric acid', 'renal']);
    final hasLiverFunction = _serviceContains(
        serviceNames, ['liver', 'sgpt', 'sgot', 'alt', 'ast', 'hepatic']);
    final hasUrinalysis = _serviceContains(
        serviceNames, ['urine', 'urinalysis', 'ua', 'urinalysys']);
    final hasOtherTests =
        _serviceContains(serviceNames, ['esr', 'crp', 'tsh', 'thyroid', 'psa']);

    // Handle overlap tests that might be in multiple panels (like BUN in both kidney and liver panels)
    final hasBUN = hasKidneyFunction || hasLiverFunction;

    // Process each test category controller
    if (widget.labResultControllers['cbc'] != null) {
      widget.labResultControllers['cbc']!.forEach((key, controller) {
        if (!hasCBC && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
    
    if (widget.labResultControllers['glucose'] != null) {
      widget.labResultControllers['glucose']!.forEach((key, controller) {
        if (!hasGlucose && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
    
    if (widget.labResultControllers['lipid'] != null) {
      widget.labResultControllers['lipid']!.forEach((key, controller) {
        if (!hasLipidProfile && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
    
    if (widget.labResultControllers['kidney'] != null) {
      widget.labResultControllers['kidney']!.forEach((key, controller) {
        // Special case for BUN which can be in both kidney and liver panels
        if (key == 'BUN' && hasBUN) {
          // Don't autofill BUN if either kidney or liver tests are selected
          return;
        }
        
        if (!hasKidneyFunction && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
    
    if (widget.labResultControllers['liver'] != null) {
      widget.labResultControllers['liver']!.forEach((key, controller) {
        // Special case for BUN which can be in both kidney and liver panels
        if (key == 'BUN' && hasBUN) {
          // Don't autofill BUN if either kidney or liver tests are selected
          return;
        }
        
        if (!hasLiverFunction && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
    
    if (widget.labResultControllers['urinalysis'] != null) {
      widget.labResultControllers['urinalysis']!.forEach((key, controller) {
        if (!hasUrinalysis && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
    
    if (widget.labResultControllers['other'] != null) {
      widget.labResultControllers['other']!.forEach((key, controller) {
        if (!hasOtherTests && controller.text.isEmpty) {
          controller.text = "0";
        }
      });
    }
  }

  // This method can be called when services change to update the form state
  void updateFormBasedOnServices() {
    // This will set default values for non-relevant fields
    _setDefaultValueForNonRelevantFields();
    
    // Refresh the UI to reflect the changes
    setState(() {});
  }
}
