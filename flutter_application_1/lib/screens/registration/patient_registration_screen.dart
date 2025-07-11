import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    validator: validator,
  );
}

Widget _buildStaticDatePickerField({
  required BuildContext context, // Added context
  required TextEditingController controller,
  required String label,
  required IconData icon,
  required void Function(DateTime) onDatePicked,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    onTap: enabled
        ? () async {
            // Calculate the date 5 years ago from now
            final DateTime fiveYearsAgo =
                DateTime.now().subtract(const Duration(days: 5 * 365));
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: fiveYearsAgo,
              firstDate: DateTime(1900),
              lastDate:
                  fiveYearsAgo, // Restrict to dates at least 5 years in the past
            );
            if (picked != null) {
              onDatePicked(picked);
            }
          }
        : null,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Required';
      }

      // Validate that the date is at least 5 years ago
      try {
        final DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(value);
        final DateTime fiveYearsAgo =
            DateTime.now().subtract(const Duration(days: 5 * 365));
        if (selectedDate.isAfter(fiveYearsAgo)) {
          return 'Patient must be at least 5 years old';
        }
      } catch (e) {
        return 'Invalid date format';
      }
      return null;
    },
  );
}

// Removed unused _buildStaticDropdownField function

Widget _buildStaticSectionCard(String title, IconData icon, Widget content) {
  // Made static
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
  PatientRegistrationScreenState createState() =>
      PatientRegistrationScreenState();
}

class PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController =
      TextEditingController(); // Added for middle name
  final TextEditingController _suffixController =
      TextEditingController(); // Added for suffix
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
  String _civilStatus = 'Single'; // Added for civil status
  String _bloodType = 'A+';
  bool _unknownBloodType = false; // New flag for unknown blood type checkbox
  bool _isSeniorCitizen = false; // Added for senior citizen checkbox
  String? _generatedPatientId;
  bool get _isEditMode => widget.patient != null;
  bool _isLoading = false;

  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  final List<String> _civilStatusOptions = [
    'Single',
    'Married',
    'Widowed',
    'Separated',
    'Divorced'
  ];

  @override
  void initState() {
    super.initState();

    // Add listener to first name field to update the patient ID
    _firstNameController.addListener(() {
      if (!_isEditMode && _firstNameController.text.isNotEmpty) {
        setState(() {
          _generatedPatientId = Patient.generateDisplayId();
        });
      }
    });

    if (_isEditMode && widget.patient != null) {
      final patient = widget.patient!;

      // Parse the fullName which should be in "Last, First Middle (Suffix)" format
      String fullName = patient.fullName;
      String firstName = '';
      String lastName = '';
      String middleName = '';
      String suffix = '';

      // Use the stored fields if available
      if (patient.firstName != null && patient.lastName != null) {
        firstName = patient.firstName!;
        lastName = patient.lastName!;
        middleName = patient.middleName ?? '';
        suffix = patient.suffix ?? '';
      } else {
        // Legacy parsing of fullName if individual fields aren't available
        try {
          if (fullName.contains(',')) {
            // Format is "Last, First Middle (Suffix)"
            final parts = fullName.split(',');
            lastName = parts[0].trim();

            String remainingPart = parts[1].trim();

            // Extract suffix if present
            if (remainingPart.contains('(') && remainingPart.contains(')')) {
              final suffixMatch =
                  RegExp(r'\((.*?)\)').firstMatch(remainingPart);
              if (suffixMatch != null) {
                suffix = suffixMatch.group(1)!;
                remainingPart =
                    remainingPart.replaceAll('($suffix)', '').trim();
              }
            }

            // Split remaining into first and middle
            final nameParts = remainingPart.split(' ');
            firstName = nameParts.isNotEmpty ? nameParts[0] : '';
            middleName =
                nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          } else {
            // Old format or just a simple name
            final nameParts = fullName.split(' ');
            firstName = nameParts.isNotEmpty ? nameParts.first : '';
            lastName = nameParts.length > 1 ? nameParts.last : '';
            middleName = nameParts.length > 2
                ? nameParts.sublist(1, nameParts.length - 1).join(' ')
                : '';
          }
        } catch (e) {
          // If parsing fails, just use the whole name as first name
          firstName = fullName;
        }
      }

      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _middleNameController.text = middleName;
      _suffixController.text = suffix;
      _dobController.text = DateFormat('yyyy-MM-dd')
          .format(patient.birthDate); // Keep yyyy-MM-dd for parsing
      _contactController.text = patient.contactNumber ?? '';
      _emailController.text = patient.email ?? '';
      _addressController.text = patient.address ?? '';
      _emergencyContactController.text = patient.emergencyContactNumber ?? '';
      _emergencyContactNameController.text = patient.emergencyContactName ?? '';
      _medicalInfoController.text = patient.medicalHistory ?? '';
      _allergiesController.text = patient.allergies ?? '';
      _currentMedicationsController.text = patient.currentMedications ?? '';
      _gender = patient.gender == 'Other' ? 'Male' : patient.gender;
      _bloodType = patient.bloodType ?? 'A+';
      _unknownBloodType = patient.bloodType == 'Unknown';
      _civilStatus = patient.civilStatus ?? 'Single';
      _isSeniorCitizen = patient.isSeniorCitizen;
      _unknownBloodType = patient.bloodType == 'Unknown';
      _generatedPatientId = patient.id;
    } else {
      // For new patients, display the next ID that would be assigned WITHOUT incrementing the counter
      _generatedPatientId = Patient.generateDisplayId();
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
                      color: Colors.grey.withAlpha(77),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
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

                              // Patient ID display with copy button at the top
                              if (_generatedPatientId != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.teal[700]!, width: 1),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.teal[50],
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withAlpha(30),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.badge_outlined,
                                          color: Colors.teal[700]),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Patient ID: $_generatedPatientId',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal[700],
                                          fontSize: 16,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 18),
                                        color: Colors.teal[700],
                                        tooltip: 'Copy ID',
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(
                                              text: _generatedPatientId!));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .check_circle_outline,
                                                      color: Colors.white),
                                                  SizedBox(width: 10),
                                                  Text(
                                                      'Patient ID copied to clipboard'),
                                                ],
                                              ),
                                              backgroundColor: Colors.teal,
                                              duration:
                                                  const Duration(seconds: 1),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              margin: const EdgeInsets.all(10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                  'Patient ID copied to clipboard'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor: Colors.teal[700],
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
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
                          middleNameController:
                              _middleNameController, // Pass new controller
                          suffixController:
                              _suffixController, // Pass new controller
                          dobController: _dobController,
                          contactController: _contactController,
                          emailController:
                              _emailController, // Pass all controllers
                          addressController: _addressController,
                          emergencyContactController:
                              _emergencyContactController,
                          emergencyContactNameController:
                              _emergencyContactNameController,
                          medicalInfoController: _medicalInfoController,
                          allergiesController: _allergiesController,
                          currentMedicationsController:
                              _currentMedicationsController,
                          gender: _gender,
                          onGenderChanged: (value) {
                            if (value != null) setState(() => _gender = value);
                          },
                          bloodType: _bloodType,
                          onBloodTypeChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _bloodType = value;
                                // Update the unknown blood type flag if "Unknown" is selected
                                _unknownBloodType = value == 'Unknown';
                              });
                            }
                          },
                          bloodTypes: _bloodTypes,
                          unknownBloodType: _unknownBloodType,
                          onUnknownBloodTypeChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _unknownBloodType = value;
                                if (value) {
                                  _bloodType = 'Unknown';
                                } else if (_bloodType == 'Unknown') {
                                  _bloodType =
                                      'A+'; // Default if unchecking "Unknown"
                                }
                              });
                            }
                          },
                          civilStatus: _civilStatus, // Pass civil status
                          onCivilStatusChanged: (value) {
                            if (value != null)
                              setState(() => _civilStatus = value);
                          },
                          isSeniorCitizen:
                              _isSeniorCitizen, // Pass senior citizen status
                          onSeniorCitizenChanged: (value) {
                            if (value != null)
                              setState(() => _isSeniorCitizen = value);
                          },
                          civilStatusOptions:
                              _civilStatusOptions, // Pass civil status options
                          isEditMode: _isEditMode, // Pass edit mode
                          formType:
                              FormType.full, // Indicate this is the full form
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
                                    ? const SizedBox(
                                        // Consistent loading indicator size
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

                        // Success message removed from here, now showing in dialog only
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

  // Success message now only shown in dialog, not in main form

  Future<void> _registerPatient() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);

        // For new patients, generate an actual ID that increments the counter
        // For existing patients in edit mode, use their existing ID
        final String patientId = _isEditMode
            ? (_generatedPatientId ?? '')
            : Patient
                .generateId(); // Only generate a real ID here when actually registering

        // Format the patient name surname first for display
        final firstName = _firstNameController.text.trim();
        final middleName = _middleNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        final suffix = _suffixController.text.trim();

        // Format the name as "Last, First Middle (Suffix)"
        String middleInitial = '';
        if (middleName.isNotEmpty) {
          middleInitial = ' ${middleName[0]}.';
        }

        final String formattedName = lastName.isNotEmpty
            ? '$lastName, $firstName$middleInitial${suffix.isNotEmpty ? ' ($suffix)' : ''}'
            : firstName; // Fallback if no last name

        final patientObject = Patient(
          id: patientId,
          fullName: formattedName,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          suffix: suffix.isNotEmpty ? suffix : null,
          civilStatus: _civilStatus,
          isSeniorCitizen: _isSeniorCitizen,
          birthDate: DateFormat('yyyy-MM-dd')
              .parse(_dobController.text), // Ensure parsing 'yyyy-MM-dd'
          gender: _gender,
          contactNumber: _contactController.text.trim(),
          address: _addressController.text.trim(),
          bloodType: _bloodType,
          allergies: _allergiesController.text.trim(),
          // Optional fields from full form
          email: _emailController.text.trim(),
          emergencyContactName: _emergencyContactNameController.text.trim(),
          emergencyContactNumber: _emergencyContactController.text.trim(),
          medicalHistory: _medicalInfoController.text.trim(),
          currentMedications: _currentMedicationsController.text.trim(),
          createdAt: _isEditMode && widget.patient != null
              ? widget.patient!.createdAt
              : DateTime.now(),
          updatedAt: DateTime.now(),
          registrationDate: _isEditMode && widget.patient != null
              ? widget.patient!.registrationDate
              : DateTime.now(),
        );

        if (_isEditMode) {
          await ApiService.updatePatient(patientObject,
              source: 'PatientRegistrationScreen');
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showSuccessDialog(context, patientObject);
        } else {
          final newPatientId = await ApiService.createPatient(patientObject);
          final finalNewPatient = patientObject.copyWith(id: newPatientId);
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showSuccessDialog(context, finalNewPatient);
        }
      } catch (e) {
        if (!mounted) return;
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
          backgroundColor:
              Colors.orange[600], // Changed color for differentiation
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    border: Border.all(color: Colors.teal[300]!, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined,
                          color: Colors.teal[700], size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Patient ID:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SelectableText(
                        patient.id,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        color: Colors.teal[700],
                        tooltip: 'Copy ID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: patient.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Patient ID copied to clipboard'),
                              backgroundColor: Colors.teal,
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
    _middleNameController.clear(); // Clear middle name
    _suffixController.clear(); // Clear suffix
    _dobController.clear();
    _contactController.clear();
    _emailController.clear();
    _addressController.clear();
    _emergencyContactController.clear();
    _emergencyContactNameController.clear();
    _medicalInfoController.clear();
    _allergiesController.clear();
    _currentMedicationsController.clear();
    setState(() {
      // Ensure UI updates for gender/bloodType reset
      _gender = 'Male';
      _civilStatus = 'Single'; // Reset to default civil status
      _bloodType = 'A+'; // Keep A+ as default, not Unknown
      _unknownBloodType = false; // Reset unknown blood type flag
      // Display the next ID that would be assigned WITHOUT incrementing the counter
      _generatedPatientId = Patient.generateDisplayId();
    });
  }
}

// Enum to differentiate between full form and mini form usage
enum FormType { full, mini }

// Reusable Form Fields Widget
class ReusablePatientFormFields extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController middleNameController; // Added for middle name
  final TextEditingController suffixController; // Added for suffix
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
  final bool unknownBloodType; // Added for unknown blood type checkbox
  final Function(bool?)
      onUnknownBloodTypeChanged; // Added for unknown blood type checkbox
  final String civilStatus; // Added for civil status
  final Function(String?) onCivilStatusChanged; // Added for civil status
  final bool isSeniorCitizen; // Added for senior citizen status
  final Function(bool?)
      onSeniorCitizenChanged; // Added for senior citizen status
  final List<String> civilStatusOptions; // Added for civil status options

  const ReusablePatientFormFields({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.middleNameController,
    required this.suffixController,
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
    required this.unknownBloodType,
    required this.onUnknownBloodTypeChanged,
    required this.civilStatus,
    required this.onCivilStatusChanged,
    required this.isSeniorCitizen,
    required this.onSeniorCitizenChanged,
    required this.civilStatusOptions,
    required this.isEditMode,
    required this.formType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient Info Section
        _buildStaticSectionCard(
          'Personal Information',
          Icons.person,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last name, First name, Middle Initial row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildStaticInputField(
                      controller: lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      enabled: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: _buildStaticInputField(
                      controller: firstNameController,
                      label: 'First Name',
                      icon: Icons.person_outline,
                      enabled: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Middle name and suffix row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildStaticInputField(
                      controller: middleNameController,
                      label: 'Middle Name',
                      icon: Icons.person_outline,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildStaticInputField(
                      controller: suffixController,
                      label: 'Suffix (Jr., Sr., III, etc.)',
                      icon: Icons.person_outline,
                      enabled: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Date of Birth and Gender row
              Row(
                children: [
                  Expanded(
                    child: _buildStaticDatePickerField(
                      context: context,
                      controller: dobController,
                      label: 'Date of Birth',
                      icon: Icons.calendar_today,
                      onDatePicked: (date) {
                        dobController.text =
                            DateFormat('yyyy-MM-dd').format(date);
                      },
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        prefixIcon:
                            Icon(Icons.wc, color: Colors.teal[700], size: 20),
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
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      value: gender,
                      items: ['Male', 'Female']
                          .map((item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: onGenderChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Civil status and senior citizen row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Civil Status',
                        prefixIcon: Icon(Icons.family_restroom,
                            color: Colors.teal[700], size: 20),
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
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      value: civilStatus,
                      items: civilStatusOptions
                          .map((item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: onCivilStatusChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.elderly, color: Colors.teal[700], size: 20),
                        const SizedBox(width: 10),
                        const Text("Senior Citizen"),
                        const SizedBox(width: 10),
                        Checkbox(
                          value: isSeniorCitizen,
                          onChanged: onSeniorCitizenChanged,
                          activeColor: Colors.teal[700],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Contact Number
              _buildStaticInputField(
                controller: contactController,
                label: 'Contact Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                enabled: true,
              ),

              // Show additional fields only in the full form
              if (formType == FormType.full) ...[
                const SizedBox(height: 15),
                _buildStaticInputField(
                  controller: emailController!,
                  label: 'Email Address',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: true,
                ),
                const SizedBox(height: 15),
                _buildStaticInputField(
                  controller: addressController!,
                  label: 'Home Address',
                  icon: Icons.home,
                  maxLines: 2,
                  enabled: true,
                ),
              ],
            ],
          ),
        ),

        // Additional sections for the full form
        if (formType == FormType.full) ...[
          const SizedBox(height: 20),
          _buildStaticSectionCard(
            'Medical Information',
            Icons.medical_services,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blood Type and Unknown checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Blood Type',
                          prefixIcon: Icon(Icons.opacity,
                              color: Colors.teal[700], size: 20),
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
                          fillColor: !unknownBloodType
                              ? Colors.white
                              : Colors.grey[100],
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        value: bloodType,
                        items: bloodTypes
                            .map((item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ))
                            .toList(),
                        onChanged:
                            !unknownBloodType ? onBloodTypeChanged : null,
                        style: TextStyle(
                          color: !unknownBloodType
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Text("Unknown"),
                          Checkbox(
                            value: unknownBloodType,
                            onChanged: onUnknownBloodTypeChanged,
                            activeColor: Colors.teal[700],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Allergies
                _buildStaticInputField(
                  controller: allergiesController!,
                  label: 'Allergies',
                  icon: Icons.warning_amber,
                  maxLines: 2,
                  enabled: true,
                ),
                const SizedBox(height: 15),
                // Current Medications
                _buildStaticInputField(
                  controller: currentMedicationsController!,
                  label: 'Current Medications',
                  icon: Icons.medication,
                  maxLines: 2,
                  enabled: true,
                ),
                const SizedBox(height: 15),
                // Medical History
                _buildStaticInputField(
                  controller: medicalInfoController!,
                  label: 'Medical History',
                  icon: Icons.history,
                  maxLines: 3,
                  enabled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildStaticSectionCard(
            'Emergency Contact',
            Icons.emergency,
            Column(
              children: [
                _buildStaticInputField(
                  controller: emergencyContactNameController!,
                  label: 'Emergency Contact Name',
                  icon: Icons.person_pin,
                  enabled: true,
                ),
                const SizedBox(height: 15),
                _buildStaticInputField(
                  controller: emergencyContactController!,
                  label: 'Emergency Contact Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  enabled: true,
                ),
              ],
            ),
          ),
        ]
      ],
    );
  }
}
