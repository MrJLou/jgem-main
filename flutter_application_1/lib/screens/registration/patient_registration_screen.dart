import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/patient.dart';

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
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
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
      _dobController.text = DateFormat('yyyy-MM-dd').format(patient.birthDate);
      _contactController.text = patient.contactNumber ?? '';
      _emailController.text = ''; // Patient model does not have email
      _addressController.text = patient.address ?? '';
      _emergencyContactController.text =
          ''; // Patient model does not have emergencyContactNumber
      _emergencyContactNameController.text =
          ''; // Patient model does not have emergencyContactName
      _medicalInfoController.text =
          ''; // Patient model does not have medicalHistory
      _allergiesController.text = patient.allergies ?? '';
      _currentMedicationsController.text =
          ''; // Patient model does not have currentMedications
      _gender = patient.gender;
      _bloodType = patient.bloodType ?? 'A+';
      _generatedPatientId = patient.id;
    }
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

                        // Personal Information Card
                        _buildSectionCard(
                          'Personal Information',
                          Icons.person_outline,
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _firstNameController,
                                      label: 'First Name',
                                      icon: Icons.person,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _lastNameController,
                                      label: 'Last Name',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDatePickerField(
                                      controller: _dobController,
                                      label: 'Date of Birth',
                                      icon: Icons.calendar_today,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDropdownField(
                                      value: _gender,
                                      items: ['Male', 'Female', 'Other'],
                                      label: 'Gender',
                                      icon: Icons.wc,
                                      onChanged: (value) {
                                        setState(() {
                                          _gender = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Contact Information Card
                        _buildSectionCard(
                          'Contact Information',
                          Icons.contact_phone,
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _contactController,
                                      label: 'Contact Number',
                                      icon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        if (!RegExp(r'^[0-9]{10,}$')
                                            .hasMatch(value)) {
                                          return 'Invalid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _emailController,
                                      label: 'Email (Optional)',
                                      icon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          if (!RegExp(
                                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(value)) {
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
                              _buildInputField(
                                controller: _addressController,
                                label: 'Address',
                                icon: Icons.home,
                                maxLines: 3,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Emergency Contact Card
                        _buildSectionCard(
                          'Emergency Contact',
                          Icons.emergency,
                          Column(
                            children: [
                              _buildInputField(
                                controller: _emergencyContactNameController,
                                label: 'Emergency Contact Name',
                                icon: Icons.person_pin,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _emergencyContactController,
                                label: 'Emergency Contact Number',
                                icon: Icons.phone_in_talk,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (!RegExp(r'^[0-9]{10,}$')
                                      .hasMatch(value)) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Medical Information Card
                        _buildSectionCard(
                          'Medical Information',
                          Icons.medical_services,
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDropdownField(
                                      value: _bloodType,
                                      items: _bloodTypes,
                                      label: 'Blood Type',
                                      icon: Icons.bloodtype,
                                      onChanged: (value) {
                                        setState(() {
                                          _bloodType = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _allergiesController,
                                label: 'Allergies (if any)',
                                icon: Icons.warning_amber,
                                maxLines: 2,
                                validator: null,
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _currentMedicationsController,
                                label: 'Current Medications (if any)',
                                icon: Icons.medication,
                                maxLines: 2,
                                validator: null,
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _medicalInfoController,
                                label: 'Additional Medical Information',
                                icon: Icons.notes_rounded,
                                maxLines: 3,
                                validator: null,
                              ),
                            ],
                          ),
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
                                    ? SizedBox(
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
                          _buildSuccessMessage(),
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

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
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
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            controller.text = DateFormat('MMM d, yyyy').format(picked);
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(fontSize: 14.5)),
        );
      }).toList(),
      onChanged: onChanged,
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
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      ),
    );
  }

  Widget _buildSuccessMessage() {
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
                    'Patient ID: $_generatedPatientId',
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
        setState(() {
          _isLoading = true;
        });

        final patientData = Patient(
          id: _isEditMode ? _generatedPatientId! : '',
          fullName:
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          birthDate: DateFormat('yyyy-MM-dd').parse(_dobController.text),
          gender: _gender,
          contactNumber: _contactController.text.trim(),
          address: _addressController.text.trim(),
          bloodType: _bloodType,
          allergies: _allergiesController.text.trim(),
          createdAt: _isEditMode && widget.patient != null
              ? widget.patient!.createdAt
              : DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (_isEditMode) {
          await ApiService.updatePatient(patientData);
          setState(() {
            _isLoading = false;
          });
          _showSuccessDialog(context, patientData.id!);
        } else {
          final newPatientId = await ApiService.createPatient(patientData);
          setState(() {
            _generatedPatientId = newPatientId;
            _isLoading = false;
          });
          _showSuccessDialog(context, newPatientId);
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        // Clear any existing snackbars
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show error message
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
            behavior: SnackBarBehavior.floating,
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
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, String patientId) {
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
              if (!_isEditMode && _generatedPatientId != null) ...[
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
                      patientId,
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
                } else {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState!.reset();
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
    _gender = 'Male';
    _bloodType = 'A+';
    _generatedPatientId = null;
  }
}
