import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Added import for DateFormat
import '../../services/api_service.dart'; // Added import
import '../../models/patient.dart'; // Added import
import '../maintenance/update_screen.dart'; // Import for RecentUpdateLogService

class ModifyPatientDetailsScreen extends StatefulWidget {
  final Patient? patient;
  final bool isMedicalInfoOnly;
  const ModifyPatientDetailsScreen(
      {super.key, this.patient, this.isMedicalInfoOnly = false});

  @override
  ModifyPatientDetailsScreenState createState() =>
      ModifyPatientDetailsScreenState();
}

class ModifyPatientDetailsScreenState
    extends State<ModifyPatientDetailsScreen> {
  final _formKey = GlobalKey<FormState>(); // Added form key
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _currentMedicationsController =
      TextEditingController();
  final TextEditingController _medicalHistoryController =
      TextEditingController();

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

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      _selectPatient(widget.patient!);
    }
  }

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
        if (!mounted) return;
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
        if (!mounted) return;
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
      if (!mounted) return;
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
    _currentMedicationsController.clear();
    _medicalHistoryController.clear();
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
      _currentMedicationsController.text = patient.currentMedications ?? '';
      _medicalHistoryController.text = patient.medicalHistory ?? '';
    });
  }

  Future<void> _updatePatientDetails() async {
    if (_selectedPatient == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patient selected to update.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      if (!mounted) return;
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
        if (!mounted) return;
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
        currentMedications: _currentMedicationsController.text.isNotEmpty
            ? _currentMedicationsController.text
            : null,
        medicalHistory: _medicalHistoryController.text.isNotEmpty
            ? _medicalHistoryController.text
            : null,
        createdAt: _selectedPatient!.createdAt,
        updatedAt: DateTime.now(),
        registrationDate: _selectedPatient!.registrationDate,
      );

      await ApiService.updatePatient(updatedPatient, source: 'ModifyPatientDetailsScreen');
      if (!mounted) return;

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
      if (!mounted) return;
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
        title: Text(
          widget.isMedicalInfoOnly
              ? 'Modify Medical Information'
              : 'Modify Patient Details',
          style: const TextStyle(
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
          if (widget.patient == null && !widget.isMedicalInfoOnly)
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
          if (widget.patient == null) const Divider(height: 1),

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
    return const Center(
      child: Text('Search for a patient to see their details.'),
    );
  }

  Widget _buildSearchResultsList() {
    return SizedBox(
      height: 150, // Limit height of search results
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final patient = _searchResults[index];
          return ListTile(
            title: Text(patient.fullName),
            subtitle: Text(patient.id),
            onTap: () => _selectPatient(patient),
          );
        },
      ),
    );
  }

  Widget _buildPatientDetailsFormWithCards() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_selectedPatient !=
              null) // Only show title if a patient is selected
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                widget.isMedicalInfoOnly
                    ? 'Editing Medical Info for: ${_selectedPatient!.fullName}'
                    : 'Editing Details for: ${_selectedPatient!.fullName}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

          if (!widget.isMedicalInfoOnly) ...[
            // Full Name
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
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
              validator: (value) => value == null || value.isEmpty
                  ? 'Full Name is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Birth Date
            TextFormField(
              controller: _birthDateController,
              decoration: InputDecoration(
                labelText: 'Birth Date (YYYY-MM-DD)',
                prefixIcon: const Icon(Icons.calendar_today),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Birth Date is required';
                }
                try {
                  DateFormat('yyyy-MM-dd').parseStrict(value);
                  return null;
                } catch (e) {
                  return 'Invalid date format (YYYY-MM-DD)';
                }
              },
            ),
            const SizedBox(height: 16),

            // Gender
            DropdownButtonFormField<String>(
              value: _selectedGender,
              items: _gendersList.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
              validator: (value) =>
                  value == null ? 'Gender is required' : null,
              decoration: InputDecoration(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Contact Number
            TextFormField(
              controller: _contactNumberController,
              decoration: InputDecoration(
                labelText: 'Contact Number',
                prefixIcon: const Icon(Icons.phone),
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
              keyboardType: TextInputType.phone,
              validator: (value) => value == null || value.isEmpty
                  ? 'Contact Number is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                prefixIcon: const Icon(Icons.home),
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
              maxLines: 2,
              validator: (value) => value == null || value.isEmpty
                  ? 'Address is required'
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          // Blood Type
          DropdownButtonFormField<String>(
            value: _selectedBloodType,
            items: _bloodTypesList.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedBloodType = newValue;
              });
            },
            validator: (value) =>
                value == null ? 'Blood Type is required' : null,
            decoration: InputDecoration(
              labelText: 'Blood Type',
              prefixIcon: const Icon(Icons.bloodtype),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Allergies
          TextFormField(
            controller: _allergiesController,
            decoration: InputDecoration(
              labelText: 'Allergies (comma-separated)',
              prefixIcon: const Icon(Icons.warning),
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
            maxLines: 2,
            validator: (value) => value == null || value.isEmpty
                ? 'Allergies are required'
                : null,
          ),
          const SizedBox(height: 16),

          // Current Medications
          TextFormField(
            controller: _currentMedicationsController,
            decoration: InputDecoration(
              labelText: 'Current Medications (if any)',
              prefixIcon: const Icon(Icons.medication),
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
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Additional Medical Information
          TextFormField(
            controller: _medicalHistoryController,
            decoration: InputDecoration(
              labelText: 'Additional Medical Information',
              prefixIcon: const Icon(Icons.note_alt),
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
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
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
                  : Text(
                      widget.isMedicalInfoOnly
                          ? 'Update Medical Info'
                          : 'Update Patient Details',
                      style: const TextStyle(
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
    );
  }
}
