import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/patient.dart';
import '../../models/medical_record.dart';

class PatientSearchScreen extends StatefulWidget {
  const PatientSearchScreen({super.key});

  @override
  _PatientSearchScreenState createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends State<PatientSearchScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  Patient? _foundPatient;
  List<MedicalRecord> _medicalRecords = [];
  List<Patient> _searchResults = [];
  String? _errorMessage;
  Map<String, dynamic>? _patientData;

  // --- Additions for inline editing ---
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>(); // For validating the edit form

  // Controllers for editable fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); // Will store as YYYY-MM-DD
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  // For dropdowns, we'll manage state directly
  String? _editGender;
  String? _editBloodType;
  // --- End of additions ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Patient Search',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSearch,
            tooltip: 'Reset Search',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Search Form
              Expanded(
                flex: 1,
                child: _buildSearchPane(),
              ),
              const SizedBox(width: 16),
              // Right Pane: Results Display
              Expanded(
                flex: 1,
                child: _buildResultsPane(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPane() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.teal[50]!],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_search,
                      size: 30,
                      color: Colors.teal[700],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Find Patient Record',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Search by ID or surname to access patient information',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildInputField(
                controller: _patientIdController,
                label: 'Patient ID',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                hintText: 'Enter patient ID number',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 20),
              _buildInputField(
                controller: _surnameController,
                label: 'Patient Surname',
                icon: Icons.person_outline,
                hintText: 'Enter patient last name',
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: Icon(_isLoading ? null : Icons.search),
                  label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SEARCH PATIENT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  onPressed: _isLoading ? null : _searchPatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.teal.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildResultsPane() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal[50]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.teal[300]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search_outlined,
                  color: Colors.teal[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildResultsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_foundPatient != null && _patientData != null) {
      return _buildPatientDetails();
    }

    if (_searchResults.isNotEmpty) {
      return _buildPatientSelectionList();
    }

    if (!_hasSearched) {
      return _buildEmptyState();
    }

    return _buildNoResultsState();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          labelStyle: TextStyle(color: Colors.teal[700]),
          prefixIcon: Icon(icon, color: Colors.teal[700], size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal[700]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPatientDetails() {
    if (_foundPatient == null || _patientData == null) {
      return _buildNoResultsState();
    }
    // If in edit mode, show the edit form, otherwise show details
    return _isEditing ? _buildEditPatientForm() : _buildDisplayPatientDetails();
  }

  // Method to build the display part of patient details (extracted and kept same)
  Widget _buildDisplayPatientDetails() {
    if (_foundPatient == null || _patientData == null) {
      return _buildNoResultsState(); 
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.teal[50]!],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person,
                            color: Colors.teal[700], size: 24),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        'PATIENT DETAILS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.teal[700]),
                    onPressed: () {
                      if (_foundPatient != null) {
                        setState(() {
                          _isEditing = true;
                          final patient = _foundPatient!;
                          final nameParts = patient.fullName.split(' ');
                          _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
                          _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
                          _dobController.text = DateFormat('yyyy-MM-dd').format(patient.birthDate);
                          _contactController.text = patient.contactNumber ?? '';
                          _addressController.text = patient.address ?? '';
                          _allergiesController.text = patient.allergies ?? '';
                          _editGender = patient.gender == 'Other' ? 'Male' : patient.gender;
                          _editBloodType = patient.bloodType; // Can be null, handled by DropdownButtonFormField
                        });
                      }
                    },
                    tooltip: 'Edit Patient',
                  ),
                ],
              ),
              Divider(color: Colors.grey[300], height: 30),
              _buildInfoSection(
                'Personal Information',
                Icons.person_outline,
                [
                  _buildDetailRow('Patient ID', _foundPatient?.id ?? 'Unknown'),
                  _buildDetailRow('Full Name', _patientData!['fullName']), // Displayed from _patientData
                  _buildDetailRow('Date of Birth', _patientData!['dob']),
                  _buildDetailRow('Gender', _patientData!['gender']),
                  _buildDetailRow('Contact', _patientData!['contactNumber']),
                  _buildDetailRow('Address', _patientData!['address']),
                  _buildDetailRow('Blood Type', _patientData!['bloodType']),
                  _buildDetailRow('Allergies', _patientData!['allergies']),
                ],
              ),
              const SizedBox(height: 25),
              _buildInfoSection(
                'Medical Records & Lab Results',
                Icons.science_outlined,
                 [
                  if (_patientData!['hasLabResults'] == true &&
                      (_patientData!['labResults'] as List).isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[600], size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '${(_patientData!['labResults'] as List).length} medical record(s) found',
                            style: TextStyle(
                              color: Colors.teal[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    ...(_patientData!['labResults'] as List)
                        .map((result) => _buildLabResultCard(result))
                        ,
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange[600], size: 24),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Text(
                              'No Tests Found Yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('VIEW FULL HISTORY'),
                      onPressed: () { /* TODO: Implement or remove */ },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal[700],
                        side: BorderSide(color: Colors.teal[700]!),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('NEW APPOINTMENT'),
                      onPressed: () { /* TODO: Implement or remove */ },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 2,
                        shadowColor: Colors.teal.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method to build the edit form
  Widget _buildEditPatientForm() {
    final List<String> genderItems = ['Male', 'Female'];
    final List<String> bloodTypeItems = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];

    // Ensure _editBloodType has a valid default if null and patient.bloodType was null
    if (_editBloodType == null && (_foundPatient?.bloodType == null || _foundPatient!.bloodType!.isEmpty)) {
      _editBloodType = 'Unknown'; // Default to 'Unknown' if not set
    }
    if (!bloodTypeItems.contains(_editBloodType)) _editBloodType = 'Unknown';
    if (!genderItems.contains(_editGender)) _editGender = genderItems.first;


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.teal[50]!],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EDIT PATIENT DETAILS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Divider(color: Colors.grey[300], height: 30),
                
                // Using _buildEditField for consistency
                _buildEditField(
                  controller: _firstNameController,
                  label: 'First Name',
                  icon: Icons.person,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  icon: Icons.person_outline,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildEditDateField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today,
                ),
                const SizedBox(height: 16),
                _buildEditDropdownField(
                  value: _editGender,
                  items: genderItems,
                  label: 'Gender',
                  icon: Icons.wc,
                  onChanged: (value) {
                    setState(() { _editGender = value; });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  controller: _contactController,
                  label: 'Contact Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                   validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!RegExp(r'^[0-9]{10,}$').hasMatch(value)) return 'Invalid number (min 10 digits)';
                    return null;
                  }
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.home,
                  maxLines: 2,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildEditDropdownField(
                  value: _editBloodType,
                  items: bloodTypeItems,
                  label: 'Blood Type',
                  icon: Icons.bloodtype,
                  onChanged: (value) {
                    setState(() { _editBloodType = value; });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  controller: _allergiesController,
                  label: 'Allergies (if any)',
                  icon: Icons.warning_amber_rounded,
                  maxLines: 2,
                  // No validator for optional field
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('CANCEL'),
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          // Reset fields to original _patientData if needed, or simply exit edit mode
                           _fetchPatientDetailsAndSetState(_foundPatient!); // Re-fetch to discard changes
                        });
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_outlined),
                      label: const Text('SAVE CHANGES'),
                      onPressed: _isLoading ? null : _savePatientChanges, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for creating styled TextFormFields in the edit form
  Widget _buildEditField({
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
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Enter $label',
        prefixIcon: Icon(icon, color: Colors.teal[700], size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.teal[700]!, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }

  // Helper for creating styled DatePicker in the edit form
  Widget _buildEditDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal[700], size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.teal[700]!, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateFormat('yyyy-MM-dd').parse(controller.text), // Use current field value or fallback
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            controller.text = DateFormat('yyyy-MM-dd').format(picked);
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        try {
          DateFormat('yyyy-MM-dd').parseStrict(value);
          return null;
        } catch (e) {
          return 'Invalid date (YYYY-MM-DD)';
        }
      },
    );
  }

  // Helper for creating styled DropdownButtonFormFields in the edit form
  Widget _buildEditDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String itemValue) {
        return DropdownMenuItem<String>(
          value: itemValue,
          child: Text(itemValue, style: const TextStyle(fontSize: 15)),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal[700], size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.teal[700]!, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }

  void _savePatientChanges() async {
    if (_formKey.currentState!.validate()) {
      if (_foundPatient == null || _editGender == null || _editBloodType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: Patient data or selections missing.'),
            backgroundColor: Colors.red[600],
          ),
        );
        return;
      }

      setState(() { _isLoading = true; });

      try {
        final updatedPatient = Patient(
          id: _foundPatient!.id,
          fullName: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          birthDate: DateFormat('yyyy-MM-dd').parseStrict(_dobController.text),
          gender: _editGender!,
          contactNumber: _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          bloodType: _editBloodType!,
          allergies: _allergiesController.text.trim().isNotEmpty ? _allergiesController.text.trim() : null,
          createdAt: _foundPatient!.createdAt, 
          updatedAt: DateTime.now(), 
        );

        await ApiService.updatePatient(updatedPatient);
        await _fetchPatientDetailsAndSetState(updatedPatient); 

        setState(() {
          _isEditing = false; 
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Patient details updated successfully!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );

      } catch (e) {
        setState(() { 
          _isLoading = false; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update patient: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
  }

  Future<void> _fetchPatientDetailsAndSetState(Patient patient) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Set _foundPatient immediately so UI can potentially react, but clear _patientData
      _foundPatient = patient;
      _patientData = null;
      _searchResults =
          []; // Clear search results as we are focusing on one patient
    });

    try {
      final medicalRecords =
          await ApiService.getPatientMedicalRecords(patient.id);
      final nameParts = patient.fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      setState(() {
        // _foundPatient is already set
        _medicalRecords = medicalRecords;
        _patientData = {
          'firstName': firstName,
          'lastName': lastName,
          'fullName': patient.fullName,
          'dob': DateFormat('dd/MM/yyyy').format(patient.birthDate),
          'gender': patient.gender,
          'contactNumber': patient.contactNumber ?? 'Not provided',
          'address': patient.address ?? 'Not provided',
          'bloodType': patient.bloodType ?? 'Not specified',
          'allergies': patient.allergies ?? 'None recorded',
          'hasLabResults': medicalRecords.isNotEmpty,
          'labResults': medicalRecords
              .map((record) => {
                    'testName': record.recordType,
                    'date': DateFormat('dd/MM/yyyy').format(record.recordDate),
                    'result': record.labResults ?? 'No results available',
                    'notes': record.notes ?? 'No notes',
                    'diagnosis': record.diagnosis ?? 'No diagnosis',
                    'treatment': record.treatment ?? 'No treatment recorded',
                  })
              .toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            "Error fetching patient details: ${e.toString().replaceAll('Exception: ', '')}";
        _isLoading = false;
        _foundPatient = null; // Clear patient if details fetch failed
        _patientData = null;
        _medicalRecords = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching patient details: $_errorMessage'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.teal[700], size: 20),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabResultCard(Map<String, dynamic> result) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    result['testName'] ?? 'Unknown Test',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal[200]!),
                  ),
                  child: Text(
                    result['date'] ?? 'No date',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result['diagnosis'] != null &&
                result['diagnosis'] != 'No diagnosis') ...[
              _buildResultDetailRow('Diagnosis:', result['diagnosis']),
              const SizedBox(height: 8),
            ],
            if (result['result'] != null &&
                result['result'] != 'No results available') ...[
              _buildResultDetailRow('Lab Results:', result['result']),
              const SizedBox(height: 8),
            ],
            if (result['treatment'] != null &&
                result['treatment'] != 'No treatment recorded') ...[
              _buildResultDetailRow('Treatment:', result['treatment']),
              const SizedBox(height: 8),
            ],
            if (result['notes'] != null && result['notes'] != 'No notes') ...[
              _buildResultDetailRow('Notes:', result['notes']),
            ],
            if ((result['diagnosis'] == null ||
                    result['diagnosis'] == 'No diagnosis') &&
                (result['result'] == null ||
                    result['result'] == 'No results available') &&
                (result['treatment'] == null ||
                    result['treatment'] == 'No treatment recorded') &&
                (result['notes'] == null || result['notes'] == 'No notes')) ...[
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'No detailed information available',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientSelectionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
          child: Text(
            '${_searchResults.length} Patient(s) Found. Select one to view details:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.teal[700],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final patient = _searchResults[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: Text(
                      patient.fullName.isNotEmpty
                          ? patient.fullName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                          color: Colors.teal[700], fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(patient.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Patient ID: ${patient.id}'),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.teal[600]),
                  onTap: () {
                    _fetchPatientDetailsAndSetState(patient);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              size: 50,
              color: Colors.teal[300],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Search for a Patient',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter a Patient ID or surname to begin your search',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Search Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorMessage ?? 'An error occurred while searching',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            onPressed: _resetSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_off,
              size: 50,
              color: Colors.orange[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Patient Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No patient matches your search criteria.\nPlease check the ID or surname and try again.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Search Again'),
            onPressed: _resetSearch,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange[700],
              side: BorderSide(color: Colors.orange[700]!),
            ),
          ),
        ],
      ),
    );
  }

  void _searchPatient() async {
    if (_patientIdController.text.isEmpty && _surnameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Please enter either Patient ID or Surname to search')),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _foundPatient = null;
      _patientData = null;
      _medicalRecords = [];
      _searchResults = [];
      _errorMessage = null;
    });

    try {
      List<Patient> tempPatientsList = [];
      String patientIdInput = _patientIdController.text.trim();
      String surnameInput = _surnameController.text.trim();

      if (patientIdInput.isNotEmpty) {
        try {
          final patient = await ApiService.getPatientById(patientIdInput);
          tempPatientsList = [patient];
        } catch (e) {
          // If getPatientById fails, search using the patientIdInput as a general term
          tempPatientsList = await ApiService.searchPatients(patientIdInput);
        }
      } else if (surnameInput.isNotEmpty) {
        tempPatientsList = await ApiService.searchPatients(surnameInput);
      }
      // No need for an else here as the initial check handles both empty

      if (tempPatientsList.isNotEmpty) {
        if (tempPatientsList.length == 1) {
          await _fetchPatientDetailsAndSetState(tempPatientsList.first);
        } else {
          // Multiple patients found
          setState(() {
            _searchResults = tempPatientsList;
            _foundPatient = null;
            _patientData = null; // Ensure this is cleared
            _isLoading = false;
          });
        }
      } else {
        // No patients found
        setState(() {
          _foundPatient = null;
          _searchResults = []; // Ensure cleared
          _isLoading = false;
          // _errorMessage = "No patient found"; // Let _buildNoResultsState handle message
        });
      }
    } catch (e) {
      setState(() {
        _foundPatient = null;
        _medicalRecords = [];
        _searchResults = [];
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Error searching for patient: $_errorMessage'),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  void _resetSearch() {
    setState(() {
      _patientIdController.clear();
      _surnameController.clear();
      _hasSearched = false;
      _foundPatient = null;
      _patientData = null;
      _medicalRecords = [];
      _searchResults = [];
      _errorMessage = null;
      _isLoading = false;
    });
  }
}
