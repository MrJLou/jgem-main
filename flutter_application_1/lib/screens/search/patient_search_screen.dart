import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/patient.dart';
import '../../models/medical_record.dart';

class PatientSearchScreen extends StatefulWidget {
  @override
  _PatientSearchScreenState createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends State<PatientSearchScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  Patient? _foundPatient;
  Map<String, dynamic>? _patientData;
  List<MedicalRecord> _medicalRecords = [];
  String? _errorMessage;

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
            icon: Icon(Icons.refresh),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 5),
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
              if (_hasSearched) ...[
                const SizedBox(height: 30),
                if (_foundPatient != null)
                  _buildPatientDetails()
                else
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.orange[50]!, Colors.white],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              'No patient found with the provided details',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
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
                      child:
                          Icon(Icons.person, color: Colors.teal[700], size: 24),
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
                  onPressed: () {},
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
                _buildDetailRow('Full Name', _patientData!['fullName']),
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
                      .toList(),
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
                    onPressed: () {},
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
                    onPressed: () {},
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
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  void _searchPatient() async {
    if (_patientIdController.text.isEmpty && _surnameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Please enter either Patient ID or Surname to search'),
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
      _medicalRecords = [];
      _errorMessage = null;
    });

    try {
      List<Patient> patients = [];

      if (_patientIdController.text.isNotEmpty) {
        // Search by patient ID
        try {
          final patient =
              await ApiService.getPatientById(_patientIdController.text.trim());
          patients = [patient];
        } catch (e) {
          // Patient not found by ID, try searching in the list
          patients =
              await ApiService.searchPatients(_patientIdController.text.trim());
        }
      } else {
        // Search by surname
        patients =
            await ApiService.searchPatients(_surnameController.text.trim());
      }
      if (patients.isNotEmpty) {
        final patient = patients.first;
        final medicalRecords =
            await ApiService.getPatientMedicalRecords(patient.id);

        // Split fullName into first and last name for display
        final nameParts = patient.fullName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        setState(() {
          _foundPatient = patient;
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
            'hasLabResults': _medicalRecords.isNotEmpty,
            'labResults': _medicalRecords
                .map((record) => {
                      'testName': record.recordType,
                      'date':
                          DateFormat('dd/MM/yyyy').format(record.recordDate),
                      'result': record.labResults ?? 'No results available',
                      'notes': record.notes ?? 'No notes',
                      'diagnosis': record.diagnosis ?? 'No diagnosis',
                      'treatment': record.treatment ?? 'No treatment recorded',
                    })
                .toList(),
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _foundPatient = null;
          _medicalRecords = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _foundPatient = null;
        _medicalRecords = [];
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
                child: Text('Error searching for patient: ${_errorMessage}'),
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
      _errorMessage = null;
    });
  }
}
