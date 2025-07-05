import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';

class LabOrConsultationView extends StatefulWidget {
  final ActivePatientQueueItem patient;
  final TextEditingController consultationNotesController;
  final TextEditingController chiefComplaintController;
  final TextEditingController diagnosisController;
  final TextEditingController prescriptionController;
  final String consultationType;
  final Function(String) onConsultationTypeChanged;
  final VoidCallback onSaveAndContinue;
  final VoidCallback onBack;
  final bool isLabTest;
  final Function(bool) onToggleType;
  final bool isLoading; // Added parameter for loading state
  
  // Use a map for lab results for better flexibility
  final Map<String, Map<String, TextEditingController>> labResultControllers;

  const LabOrConsultationView({
    super.key,
    required this.patient,
    required this.consultationNotesController,
    required this.chiefComplaintController,
    required this.diagnosisController,
    required this.prescriptionController,
    this.consultationType = 'General Consultation',
    this.onConsultationTypeChanged = _noOpStringCallback,
    required this.onSaveAndContinue,
    required this.onBack,
    required this.isLabTest,
    required this.onToggleType,
    required this.labResultControllers,
    this.isLoading = false, // Default is not loading
  });
  
  // Default no-op callback for consultation type changes
  static void _noOpStringCallback(String value) {}

  @override
  State<LabOrConsultationView> createState() => _LabOrConsultationViewState();
}

class _LabOrConsultationViewState extends State<LabOrConsultationView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Switch to appropriate tab based on the selected type
    _tabController.index = widget.isLabTest ? 0 : 1;
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        widget.onToggleType(_tabController.index == 0);
      }
    });
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
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Patient: ${widget.patient.patientName}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                    tooltip: 'Back to invoice preparation',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Toggle between Lab Test and Consultation
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Laboratory Results'),
                          icon: Icon(Icons.science),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Consultation Notes'),
                          icon: Icon(Icons.note_alt),
                        ),
                      ],
                      selected: {widget.isLabTest},
                      onSelectionChanged: (Set<bool> newSelection) {
                        widget.onToggleType(newSelection.first);
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.teal.shade700;
                            }
                            return Colors.grey.shade200;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Lab Test Form or Consultation Notes based on toggle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.isLabTest ? _buildLabTestForm() : _buildConsultationForm(),
              ),
              
              const SizedBox(height: 24),
              
              // Save and Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: widget.isLoading 
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        )
                      : const Icon(Icons.save),
                  label: widget.isLoading 
                      ? const Text('Saving...')
                      : const Text('Save and Continue to Invoice'),
                  onPressed: widget.onSaveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabTestForm() {
    // Get selected services to determine which tests to show
    final selectedServices = widget.patient.selectedServices ?? [];
    final serviceNames = selectedServices.map((s) => 
        (s['name'] as String? ?? '').toLowerCase()).toList();
    
    // Check if specific services are selected
    final hasCBC = _serviceContains(serviceNames, ['cbc', 'complete blood', 'blood count', 'platelet']);
    final hasGlucose = _serviceContains(serviceNames, ['glucose', 'fbs', 'blood sugar', 'sugar']);
    final hasLipidProfile = _serviceContains(serviceNames, ['lipid', 'cholesterol', 'triglyceride', 'hdl', 'ldl']);
    final hasKidneyFunction = _serviceContains(serviceNames, ['kidney', 'bun', 'creatinine', 'uric acid']);
    final hasLiverFunction = _serviceContains(serviceNames, ['liver', 'sgpt', 'sgot', 'alt', 'ast']);
    
    return Column(
      key: const ValueKey('lab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Laboratory Test Results',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              const Text(
                'Selected Laboratory Tests',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                selectedServices.isEmpty 
                    ? 'No specific lab tests selected. Please add services first.'
                    : 'Enter results for the tests performed:',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              if (selectedServices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selectedServices.map((service) => Chip(
                    label: Text(
                      service['name'] as String? ?? 'Unknown Test',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.teal.shade50,
                    side: BorderSide(color: Colors.teal.shade100),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        
        // Conditional sections based on selected services
        
        // Glucose/Blood Sugar Section - only if glucose test is selected
        if (hasGlucose) ...[
          _buildTestSection(
            title: 'Blood Sugar Panel',
            icon: Icons.bloodtype_outlined,
            color: Colors.red.shade800,
            children: <Widget>[
              _buildLabResultField(
                'Fasting Blood Sugar', 
                widget.labResultControllers['glucose']?['fbs'] ?? TextEditingController(),
                'Normal range: 70-100 mg/dL (3.9-5.6 mmol/L)',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Lipid Profile Section - only if lipid profile is selected
        if (hasLipidProfile) ...[
          _buildTestSection(
            title: 'Lipid Profile',
            icon: Icons.water_drop_outlined,
            color: Colors.orange.shade800,
            children: <Widget>[
              _buildLabResultField(
                'Total Cholesterol', 
                widget.labResultControllers['lipid']?['total_cholesterol'] ?? TextEditingController(),
                'Normal range: Less than 200 mg/dL (5.2 mmol/L)',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Triglycerides', 
                widget.labResultControllers['lipid']?['triglycerides'] ?? TextEditingController(),
                'Normal range: Less than 150 mg/dL (1.7 mmol/L)',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'HDL Cholesterol', 
                widget.labResultControllers['lipid']?['hdl'] ?? TextEditingController(),
                'Normal range: 40+ mg/dL for men, 50+ mg/dL for women',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'LDL Cholesterol', 
                widget.labResultControllers['lipid']?['ldl'] ?? TextEditingController(),
                'Normal range: Less than 100 mg/dL (2.6 mmol/L)',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'VLDL Cholesterol', 
                widget.labResultControllers['lipid']?['vldl'] ?? TextEditingController(),
                'Normal range: 5-40 mg/dL',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Kidney Function Section - only if kidney function tests are selected
        if (hasKidneyFunction) ...[
          _buildTestSection(
            title: 'Kidney Function Tests',
            icon: Icons.filter_alt_outlined,
            color: Colors.green.shade800,
            children: <Widget>[
              _buildLabResultField(
                'Blood Urea Nitrogen (BUN)', 
                widget.labResultControllers['kidney']?['bun'] ?? TextEditingController(),
                'Normal range: 6-20 mg/dL',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Creatinine', 
                widget.labResultControllers['kidney']?['creatinine'] ?? TextEditingController(),
                'Normal range: 0.6-1.2 mg/dL for men, 0.5-1.1 mg/dL for women',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Blood Uric Acid', 
                widget.labResultControllers['kidney']?['uric_acid'] ?? TextEditingController(),
                'Normal range: 3.5-7.2 mg/dL for men, 2.6-6.0 mg/dL for women',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Liver Function Section - only if liver function tests are selected
        if (hasLiverFunction) ...[
          _buildTestSection(
            title: 'Liver Function Tests',
            icon: Icons.monitor_heart_outlined,
            color: Colors.purple.shade800,
            children: <Widget>[
              _buildLabResultField(
                'SGPT/ALT', 
                widget.labResultControllers['liver']?['sgpt'] ?? TextEditingController(),
                'Normal range: 7-56 U/L',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'SGOT/AST', 
                widget.labResultControllers['liver']?['sgot'] ?? TextEditingController(),
                'Normal range: 10-40 U/L',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // CBC Section - only if CBC is selected
        if (hasCBC) ...[
          _buildTestSection(
            title: 'Complete Blood Count (CBC)',
            icon: Icons.colorize_outlined,
            color: Colors.indigo.shade800,
            children: <Widget>[
              _buildLabResultField(
                'White Blood Cell Count (WBC)', 
                widget.labResultControllers['cbc']?['wbc'] ?? TextEditingController(),
                'Normal range: 4,500-11,000 cells/μL',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Red Blood Cell Count (RBC)', 
                widget.labResultControllers['cbc']?['rbc'] ?? TextEditingController(),
                'Normal range: 4.7-6.1 million cells/μL (men), 4.2-5.4 million cells/μL (women)',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Hemoglobin', 
                widget.labResultControllers['cbc']?['hemoglobin'] ?? TextEditingController(),
                'Normal range: 14-18 g/dL (men), 12-16 g/dL (women)',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Hematocrit', 
                widget.labResultControllers['cbc']?['hematocrit'] ?? TextEditingController(),
                'Normal range: 42-52% (men), 37-47% (women)',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'Platelet Count', 
                widget.labResultControllers['cbc']?['platelet'] ?? TextEditingController(),
                'Normal range: 150,000-450,000 platelets/μL',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'MCV/MCH/MCHC', 
                widget.labResultControllers['cbc']?['mcv_mch_mchc'] ?? TextEditingController(),
                'MCV: 80-100 fL, MCH: 27-31 pg, MCHC: 32-36 g/dL',
              ),
              const SizedBox(height: 8),
              _buildLabResultField(
                'WBC Differential', 
                widget.labResultControllers['cbc']?['wbc_differential'] ?? TextEditingController(),
                'Neutrophils, lymphocytes, monocytes, eosinophils, basophils percentages',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // If no lab tests were selected
        if (!hasCBC && !hasGlucose && !hasLipidProfile && !hasKidneyFunction && !hasLiverFunction) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Column(
              children: <Widget>[
                Icon(Icons.info_outline, color: Colors.amber, size: 36),
                SizedBox(height: 8),
                Text(
                  'No specific lab tests were identified in the selected services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'If lab tests were performed, please ensure they are added to the patient\'s services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
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
  
  Widget _buildTestSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.only(bottom: 8),
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
  

  
  Widget _buildConsultationForm() {
    return Column(
      key: const ValueKey('consultation'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Consultation Notes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: [
                  'General Consultation',
                  'Follow-up Consultation',
                  'Specialist Consultation',
                  'Emergency Consultation',
                  'Pre-operative Assessment',
                  'Post-operative Follow-up'
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                hint: const Text('Select consultation type'),
                onChanged: (String? value) {
                  if (value != null) {
                    widget.onConsultationTypeChanged(value);
                  }
                },
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
                  hintText: 'Main reason for patient visit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  hintText: 'Provisional or final diagnosis',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              'Detailed Notes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: widget.consultationNotesController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Enter detailed consultation notes, findings, recommendations, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
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
              Text(
                'Prescription / Recommended Medication',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.prescriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter medication details (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLabResultField(String label, TextEditingController controller, String hintText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }
}
