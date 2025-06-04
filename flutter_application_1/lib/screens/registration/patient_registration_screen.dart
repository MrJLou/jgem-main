import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/patient.dart';

// Helper build methods (moved to top-level or static for reusability)

Widget _buildStaticInputField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  int maxLines = 1,
  String? Function(String?)? validator,
  bool enabled = true,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    enabled: enabled,
    style: const TextStyle(fontSize: 14.5),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.teal[700], size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.teal[700]!),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red[300]!),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red[300]!),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey[100],
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    validator: validator,
  );
}

Widget _buildStaticDatePickerField({
  required BuildContext context, // Added context
  required TextEditingController controller,
  required String label,
  required IconData icon,
  bool enabled = true,
}) {
  return TextFormField(
    controller: controller,
    readOnly: true,
    enabled: enabled,
    style: const TextStyle(fontSize: 14.5),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.teal[700], size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.teal[700]!),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey[100],
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    onTap: enabled ? () async { // Added enabled check
      final DateTime? picked = await showDatePicker(
        context: context, // Use passed context
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        // setState is not available here, controller update will trigger UI if parent is stateful
        controller.text = DateFormat('yyyy-MM-dd').format(picked); 
      }
    } : null,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Required';
      }
      return null;
    },
  );
}

Widget _buildStaticDropdownField({
  required String value,
  required List<String> items,
  required String label,
  required IconData icon,
  required void Function(String?) onChanged,
  bool enabled = true,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    items: items.map((String itemValue) { // Renamed inner variable
      return DropdownMenuItem<String>(
        value: itemValue, // Use renamed inner variable
        child: Text(itemValue, style: const TextStyle(fontSize: 14.5)),
      );
    }).toList(),
    onChanged: enabled ? onChanged : null, // Added enabled check
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.teal[700], size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.teal[700]!),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey[100],
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
    ),
  );
}

Widget _buildStaticSectionCard(String title, IconData icon, Widget content) { // Made static
  return Card(
    elevation: 1.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal[700], size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          content,
        ],
      ),
    ),
  );
}

class PatientRegistrationScreen extends StatefulWidget {
  final Patient? patient;

  const PatientRegistrationScreen({super.key, this.patient});

  @override
  _PatientRegistrationScreenState createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _emergencyContactNameController =
      TextEditingController();
  final TextEditingController _medicalInfoController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _currentMedicationsController =
      TextEditingController();
  String _gender = 'Male';
  String _bloodType = 'A+';
  String? _generatedPatientId;
  bool get _isEditMode => widget.patient != null;
  bool _isLoading = false;

  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.patient != null) {
      final patient = widget.patient!;
      final nameParts = patient.fullName.split(' ');
      _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
      _lastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      _dobController.text = DateFormat('yyyy-MM-dd').format(patient.birthDate); // Keep yyyy-MM-dd for parsing
      _contactController.text = patient.contactNumber ?? '';
      _emailController.text = ''; 
      _addressController.text = patient.address ?? '';
      _emergencyContactController.text = '';
      _emergencyContactNameController.text = '';
      _medicalInfoController.text = ''; 
      _allergiesController.text = patient.allergies ?? '';
      _currentMedicationsController.text = ''; 
      _gender = patient.gender;
      _bloodType = patient.bloodType ?? 'A+';
      _generatedPatientId = patient.id;
    }
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyContactNameController.dispose();
    _medicalInfoController.dispose();
    _allergiesController.dispose();
    _currentMedicationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.teal[700],
        elevation: 0,
        title: Text(
          _isEditMode ? 'Edit Patient Details' : 'Patient Registration',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Header Section
                        Center(
                          child: Column(
                            children: [
                              Text(
                                _isEditMode
                                    ? 'Update Patient Information'
                                    : 'Register New Patient',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _isEditMode
                                    ? 'Modify the details below and save changes'
                                    : 'Enter patient details to create a new medical record',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Use the ReusablePatientFormFieldsWidget
                        ReusablePatientFormFields(
                          firstNameController: _firstNameController,
                          lastNameController: _lastNameController,
                          dobController: _dobController,
                          contactController: _contactController,
                          emailController: _emailController, // Pass all controllers
                          addressController: _addressController,
                          emergencyContactController: _emergencyContactController,
                          emergencyContactNameController: _emergencyContactNameController,
                          medicalInfoController: _medicalInfoController,
                          allergiesController: _allergiesController,
                          currentMedicationsController: _currentMedicationsController,
                          gender: _gender,
                          onGenderChanged: (value) {
                            if (value != null) setState(() => _gender = value);
                          },
                          bloodType: _bloodType,
                          onBloodTypeChanged: (value) {
                             if (value != null) setState(() => _bloodType = value);
                          },
                          bloodTypes: _bloodTypes,
                          isEditMode: _isEditMode, // Pass edit mode
                          formType: FormType.full, // Indicate this is the full form
                        ),
                        
                        const SizedBox(height: 25),

                        // Submit and Clear Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.clear_all),
                                label: const Text('CLEAR FORM'),
                                onPressed: () {
                                  if (!_isEditMode) {
                                    _resetForm();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Form cleared'),
                                        backgroundColor: Colors.blueGrey[600],
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Clear is disabled in edit mode.'),
                                        backgroundColor: Colors.orange[700],
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _isEditMode
                                      ? Colors.grey
                                      : Colors.teal[700],
                                  side: BorderSide(
                                      color: _isEditMode
                                          ? Colors.grey
                                          : Colors.teal[700]!),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(_isLoading
                                    ? null
                                    : (_isEditMode
                                        ? Icons.save_alt_outlined
                                        : Icons.person_add_alt_1)),
                                label: _isLoading
                                    ? const SizedBox( // Consistent loading indicator size
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Text(
                                        _isEditMode
                                            ? 'SAVE CHANGES'
                                            : 'REGISTER PATIENT',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                onPressed: _isLoading ? null : _registerPatient,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[700],
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (!_isEditMode && _generatedPatientId != null) ...[
                          const SizedBox(height: 20),
                          _buildSuccessMessage(), // This uses _generatedPatientId from state
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() { // Kept as is, uses _generatedPatientId
    return Card(
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient Successfully Registered',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Patient ID: $_generatedPatientId', // Uses state variable
                    style: TextStyle(color: Colors.green[800]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _registerPatient() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);

        final patientObject = Patient(
          id: _isEditMode ? _generatedPatientId! : '',
          fullName:
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          birthDate: DateFormat('yyyy-MM-dd').parse(_dobController.text), // Ensure parsing 'yyyy-MM-dd'
          gender: _gender,
          contactNumber: _contactController.text.trim(),
          address: _addressController.text.trim(),
          bloodType: _bloodType,
          allergies: _allergiesController.text.trim(),
          // Optional fields from full form
          // email: _emailController.text.trim(), // Patient model doesn't have email
          // emergencyContactName: _emergencyContactNameController.text.trim(),
          // emergencyContactNumber: _emergencyContactController.text.trim(),
          // medicalHistory: _medicalInfoController.text.trim(),
          // currentMedications: _currentMedicationsController.text.trim(),
          createdAt: _isEditMode && widget.patient != null
              ? widget.patient!.createdAt
              : DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (_isEditMode) {
          await ApiService.updatePatient(patientObject);
          if (mounted) {
            setState(() => _isLoading = false);
            _showSuccessDialog(context, patientObject);
          }
        } else {
          final newPatientId = await ApiService.createPatient(patientObject);
          final finalNewPatient = patientObject.copyWith(id: newPatientId);
          if (mounted) {
            setState(() {
              _generatedPatientId = newPatientId; // For _buildSuccessMessage
              _isLoading = false;
            });
            _showSuccessDialog(context, finalNewPatient);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Failed to register patient: ${e.toString()}')),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating, // Consistent behavior
              margin: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Please fill in all required fields'),
            ],
          ),
          backgroundColor: Colors.orange[600], // Changed color for differentiation
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green[600], size: 28),
              const SizedBox(width: 10),
              Text(
                _isEditMode ? 'Update Successful' : 'Registration Successful',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode
                    ? 'Patient details have been updated successfully.'
                    : 'Patient has been registered successfully!',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              if (!_isEditMode && patient.id.isNotEmpty) ...[
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      'Patient ID:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SelectableText(
                      patient.id,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.teal[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!_isEditMode) {
                  _resetForm(); 
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _firstNameController.clear();
    _lastNameController.clear();
    _dobController.clear();
    _contactController.clear();
    _emailController.clear();
    _addressController.clear();
    _emergencyContactController.clear();
    _emergencyContactNameController.clear();
    _medicalInfoController.clear();
    _allergiesController.clear();
    _currentMedicationsController.clear();
    setState(() { // Ensure UI updates for gender/bloodType reset
      _gender = 'Male';
      _bloodType = 'A+';
      _generatedPatientId = null; // Also clear generated ID for success message
    });
  }
}

// Enum to differentiate between full form and mini form usage
enum FormType { full, mini }

// Reusable Form Fields Widget
class ReusablePatientFormFields extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController dobController;
  final TextEditingController contactController;
  final TextEditingController? emailController; // Made optional for mini form
  final TextEditingController? addressController; // Made optional
  final TextEditingController? emergencyContactController; // Optional
  final TextEditingController? emergencyContactNameController; // Optional
  final TextEditingController? medicalInfoController; // Optional
  final TextEditingController? allergiesController; // Optional
  final TextEditingController? currentMedicationsController; // Optional

  final String gender;
  final Function(String?) onGenderChanged;
  final String bloodType;
  final Function(String?) onBloodTypeChanged;
  final List<String> bloodTypes;
  final bool isEditMode;
  final FormType formType; // To control which fields are shown/required

  const ReusablePatientFormFields({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.dobController,
    required this.contactController,
    this.emailController,
    this.addressController,
    this.emergencyContactController,
    this.emergencyContactNameController,
    this.medicalInfoController,
    this.allergiesController,
    this.currentMedicationsController,
    required this.gender,
    required this.onGenderChanged,
    required this.bloodType,
    required this.onBloodTypeChanged,
    required this.bloodTypes,
    required this.isEditMode,
    this.formType = FormType.full, // Default to full form
  });

  @override
  Widget build(BuildContext context) {
    // For the mini form, we might only show a subset of fields.
    // For the full form, all fields are shown.
    bool showAllFields = formType == FormType.full;

    return Column(
      children: [
        _buildStaticSectionCard(
          'Personal Information',
          Icons.person_outline,
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStaticInputField(
                      controller: firstNameController,
                      label: 'First Name',
                      icon: Icons.person,
                      enabled: !isEditMode || formType == FormType.mini, // Example: Allow editing name in mini form even if "edit mode" for full form
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStaticInputField(
                      controller: lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      enabled: !isEditMode || formType == FormType.mini,
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStaticDatePickerField(
                      context: context,
                      controller: dobController,
                      label: 'Date of Birth',
                      icon: Icons.calendar_today,
                      enabled: !isEditMode || formType == FormType.mini,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStaticDropdownField(
                      value: gender,
                      items: const ['Male', 'Female', 'Other'],
                      label: 'Gender',
                      icon: Icons.wc,
                      onChanged: onGenderChanged,
                      enabled: !isEditMode || formType == FormType.mini,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _buildStaticSectionCard(
          'Contact Information',
          Icons.contact_phone,
          Column(
            children: [
              // Conditionally render contact and email fields based on formType
              if (formType == FormType.mini) ...[
                _buildStaticInputField(
                  controller: contactController,
                  label: 'Contact Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!RegExp(r'^[0-9]{10,}$').hasMatch(value)) return 'Invalid number';
                    return null;
                  },
                ),
                if (addressController != null) ...[ // Optional Address for mini
                  const SizedBox(height: 16),
                  _buildStaticInputField(
                    controller: addressController!,
                    label: 'Address (Optional)',
                    icon: Icons.home,
                    maxLines: 2,
                  ),
                ],
              ] else if (showAllFields && emailController != null && addressController != null) ...[ 
                // Full form: Contact and Email in a Row, then Address below
                Row(
                  children: [
                    Expanded(
                      child: _buildStaticInputField(
                        controller: contactController, // This is the single contact field for the Row
                        label: 'Contact Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(r'^[0-9]{10,}$').hasMatch(value)) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStaticInputField(
                        controller: emailController!,
                        label: 'Email (Optional)',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) { // Simpler universal email regex
                              return 'Invalid email';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStaticInputField(
                  controller: addressController!,
                  label: 'Address',
                  icon: Icons.home,
                  maxLines: 3,
                  validator: (value) => (value == null || value.isEmpty) && formType == FormType.full ? 'Required' : null,
                ),
              ]
            ],
          ),
        ),
        
        if (showAllFields && emergencyContactNameController != null && emergencyContactController != null) ...[
          const SizedBox(height: 15),
          _buildStaticSectionCard(
            'Emergency Contact',
            Icons.emergency,
            Column(
              children: [
                _buildStaticInputField(
                  controller: emergencyContactNameController!,
                  label: 'Emergency Contact Name',
                  icon: Icons.person_pin,
                  validator: (value) => (value == null || value.isEmpty) && formType == FormType.full ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildStaticInputField(
                  controller: emergencyContactController!,
                  label: 'Emergency Contact Number',
                  icon: Icons.phone_in_talk,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if ((value == null || value.isEmpty) && formType == FormType.full) return 'Required';
                    if (value != null && value.isNotEmpty && !RegExp(r'^[0-9]{10,}$').hasMatch(value)) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 15), // Blood type for both mini and full
         _buildStaticSectionCard(
            'Medical Information',
            Icons.medical_services,
            Column(
                children: [
                    _buildStaticDropdownField(
                        value: bloodType,
                        items: bloodTypes,
                        label: 'Blood Type',
                        icon: Icons.bloodtype,
                        onChanged: onBloodTypeChanged,
                        enabled: !isEditMode || formType == FormType.mini,
                    ),
                    if (showAllFields && allergiesController != null && currentMedicationsController != null && medicalInfoController != null)...[
                        const SizedBox(height: 16),
                        _buildStaticInputField(
                            controller: allergiesController!,
                            label: 'Allergies (if any)',
                            icon: Icons.warning_amber,
                            maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildStaticInputField(
                            controller: currentMedicationsController!,
                            label: 'Current Medications (if any)',
                            icon: Icons.medication,
                            maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildStaticInputField(
                            controller: medicalInfoController!,
                            label: 'Additional Medical Information',
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                        ),
                    ] else if (formType == FormType.mini && allergiesController != null) ... [ // Optional Allergies for mini
                       const SizedBox(height: 16),
                        _buildStaticInputField(
                            controller: allergiesController!,
                            label: 'Allergies (Optional)',
                            icon: Icons.warning_amber,
                            maxLines: 2,
                        ),
                    ]
                ],
            ),
        ),
      ],
    );
  }
}
