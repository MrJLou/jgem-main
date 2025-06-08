import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Added import for DateFormat
import '../../services/api_service.dart'; // Added import
import '../../models/patient.dart'; // Added import
import '../maintenance/update_screen.dart'; // Import for RecentUpdateLogService

class ModifyPatientDetailsScreen extends StatefulWidget {
  const ModifyPatientDetailsScreen({super.key});

  @override
  _ModifyPatientDetailsScreenState createState() =>
      _ModifyPatientDetailsScreenState();
}

class _ModifyPatientDetailsScreenState
    extends State<ModifyPatientDetailsScreen> {
  final _formKey = GlobalKey<FormState>(); // Added form key
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();

  List<Patient> _searchResults = [];
  Patient? _selectedPatient;
  bool _isLoading = false;
  bool _isUpdating = false; // For update button loader

  // Added for Blood Type Dropdown
  String?
      _selectedBloodType; // Can be nullable if blood type is optional or to represent no selection
  final List<String> _bloodTypesList = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
    'Unknown' // Added 'Unknown' as an option
  ];
  String? _selectedGender;
  final List<String> _gendersList = ['Male', 'Female'];

  Future<void> _performSearch() async {
    String searchTerm = _searchController.text;
    if (searchTerm.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _searchResults = [];
        _selectedPatient = null;
        _clearFormFields();
      });
      try {
        final results = await ApiService.searchPatients(searchTerm);
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No patients found for "$searchTerm".'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching patients: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Patient ID or Name to search.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  void _clearFormFields() {
    _fullNameController.clear();
    _birthDateController.clear();
    _contactNumberController.clear();
    _addressController.clear();
    _allergiesController.clear();
    setState(() {
      _selectedBloodType = null; // Reset selected blood type
      _selectedGender = null;
    });
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _fullNameController.text = patient.fullName;
      _birthDateController.text =
          DateFormat('yyyy-MM-dd').format(patient.birthDate);
      if (patient.gender.isNotEmpty && _gendersList.contains(patient.gender)) {
        _selectedGender = patient.gender;
      } else {
        _selectedGender = 'Male';
      }
      _contactNumberController.text = patient.contactNumber ?? '';
      _addressController.text = patient.address ?? '';
      _allergiesController.text = patient.allergies ?? '';
      _searchResults = [];
      if (patient.bloodType != null &&
          _bloodTypesList.contains(patient.bloodType)) {
        _selectedBloodType = patient.bloodType;
      } else if (patient.bloodType != null && patient.bloodType!.isNotEmpty) {
        // If blood type from DB isn't in the list, add it temporarily or default to Unknown
        // For simplicity, defaulting to Unknown if not in list. Or add it to _bloodTypesList dynamically.
        _selectedBloodType = 'Unknown';
      } else {
        _selectedBloodType = null; // No blood type recorded or empty
      }
    });
  }

  Future<void> _updatePatientDetails() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patient selected to update.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      DateTime birthDate;
      try {
        birthDate =
            DateFormat('yyyy-MM-dd').parseStrict(_birthDateController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Birth Date format. Please use YYYY-MM-DD.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isUpdating = false);
        return;
      }

      Patient updatedPatient = Patient(
        id: _selectedPatient!.id,
        fullName: _fullNameController.text,
        birthDate: birthDate,
        gender: _selectedGender ?? 'Male',
        contactNumber: _contactNumberController.text.isNotEmpty
            ? _contactNumberController.text
            : null,
        address:
            _addressController.text.isNotEmpty ? _addressController.text : null,
        bloodType: _selectedBloodType == 'Unknown' ? null : _selectedBloodType,
        allergies: _allergiesController.text.isNotEmpty
            ? _allergiesController.text
            : null,
        createdAt: _selectedPatient!.createdAt,
        updatedAt: DateTime.now(),
      );

      await ApiService.updatePatient(updatedPatient);

      // Log the update
      RecentUpdateLogService.addLog('Patient Detail',
          'Updated: ${updatedPatient.fullName} (ID: ${updatedPatient.id})');

      setState(() {
        _isUpdating = false;
        _selectedPatient = updatedPatient;
        // Refresh blood type in UI after update if it changed
        if (updatedPatient.bloodType != null &&
            _bloodTypesList.contains(updatedPatient.bloodType)) {
          _selectedBloodType = updatedPatient.bloodType;
        } else if (updatedPatient.bloodType != null &&
            updatedPatient.bloodType!.isNotEmpty) {
          _selectedBloodType = 'Unknown';
        } else {
          _selectedBloodType = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Patient details for ${updatedPatient.fullName} updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating patient: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Match registration screen background
      appBar: AppBar(
        title: const Text(
          'Modify Patient Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar - Stays at the top
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Patient ID/Name',
                      hintText: 'Enter Patient ID or Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.white, // Changed from grey[100]
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.teal[700]), // Added icon
                    ),
                    onSubmitted: (_) =>
                        _performSearch(), // Allow search on submit
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search), // Changed to icon button
                  label: const Text('Search'), // Changed from 'Enter'
                  onPressed: _isLoading ? null : _performSearch,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Area based on state
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedPatient != null
                    ? _buildPatientDetailsFormWithCards() // New method for form with cards
                    : _searchResults.isNotEmpty
                        ? _buildSearchResultsList() // Renamed for clarity
                        : _buildInitialPlaceholder(), // Method for placeholder
          ),
        ],
      ),
    );
  }

  Widget _buildInitialPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'Search for a patient to view and modify their details.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final patient = _searchResults[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading:
                Icon(Icons.person_outline, color: Colors.teal[700], size: 30),
            title: Text(patient.fullName,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
                'ID: ${patient.id} \nDOB: ${DateFormat('MMM d, yyyy').format(patient.birthDate)}'),
            isThreeLine: true,
            trailing: Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.teal[600], size: 18),
            onTap: () => _selectPatient(patient),
          ),
        );
      },
    );
  }

  // Helper to build styled input field similar to PatientRegistrationScreen
  Widget _buildStyledInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[700]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red[300]!),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red[300]!),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  // Helper to build section cards similar to PatientRegistrationScreen
  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal[700], size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  // Helper to build styled DropdownButtonFormField
  Widget _buildStyledDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPatientDetailsFormWithCards() {
    if (_selectedPatient == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        // Match registration screen gradient if desired, or keep simple
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.teal[50]!, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Column(
                children: [
                  Text(
                    'Editing: ${_selectedPatient!.fullName}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Patient ID: ${_selectedPatient!.id}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              )),
              const SizedBox(height: 20),

              _buildSectionCard(
                'Personal Information',
                Icons.person_outline,
                [
                  _buildStyledInputField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Full Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledInputField(
                    controller: _birthDateController,
                    label: 'Birth Date (YYYY-MM-DD)',
                    icon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () async {
                      DateTime initialDateTime =
                          DateTime.now(); // Default to now
                      if (_birthDateController.text.isNotEmpty) {
                        try {
                          initialDateTime = DateFormat('yyyy-MM-dd')
                              .parseStrict(_birthDateController.text);
                        } catch (e) {
                          // If parsing fails, initialDateTime remains DateTime.now()
                          print('Error parsing date for DatePicker: $e');
                        }
                      }
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: initialDateTime,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _birthDateController.text =
                              DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Birth Date is required';
                      try {
                        DateFormat('yyyy-MM-dd').parseStrict(value);
                        return null;
                      } catch (e) {
                        return 'Invalid date format (YYYY-MM-DD)';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStyledDropdownField(
                    value: _selectedGender,
                    items: _gendersList,
                    label: 'Gender',
                    icon: Icons.wc,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Gender is required' : null,
                  ),
                ],
              ),

              _buildSectionCard(
                'Contact Information',
                Icons.contact_phone_outlined,
                [
                  _buildStyledInputField(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledInputField(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.home_outlined,
                    maxLines: 2,
                  ),
                ],
              ),

              _buildSectionCard(
                'Medical Information',
                Icons.medical_services_outlined,
                [
                  _buildStyledDropdownField(
                    value: _selectedBloodType,
                    items: _bloodTypesList,
                    label: 'Blood Type',
                    icon: Icons.bloodtype_outlined,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedBloodType = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStyledInputField(
                    controller: _allergiesController,
                    label: 'Allergies (comma-separated)',
                    icon: Icons.warning_amber_outlined,
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isUpdating
                      ? Container() // Hide icon when loading, or use a smaller one
                      : const Icon(Icons.save_alt_outlined),
                  label: _isUpdating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ))
                      : const Text('Update Patient Details',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed: _isUpdating ? null : _updatePatientDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // Ensure consistent text style for the button when not loading
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
