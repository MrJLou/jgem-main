import 'package:flutter/material.dart';

class PatientSearchScreen extends StatefulWidget {
  @override
  _PatientSearchScreenState createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends State<PatientSearchScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  Map<String, dynamic>? _patientData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Patient Search',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetSearch,
            tooltip: 'Reset Search',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              shadowColor: Colors.teal.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Column(
                  children: [
                    Text(
                      'Find Patient Record',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildInputField(
                      controller: _patientIdController,
                      label: 'Patient ID',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      hintText: 'Enter patient ID number',
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[400])),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                        ),
                        Expanded(child: Divider(color: Colors.grey[400])),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildInputField(
                      controller: _surnameController,
                      label: 'Patient Surname',
                      icon: Icons.person_outline,
                      hintText: 'Enter patient last name',
                    ),
                    SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _searchPatient,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'SEARCH PATIENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_hasSearched) ...[
              SizedBox(height: 30),
              if (_patientData != null)
                _buildPatientDetails()
              else
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                        SizedBox(width: 15),
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
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.teal[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[700]!, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        labelStyle: TextStyle(color: Colors.grey[600]),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildPatientDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PATIENT DETAILS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.teal[700]),
                  onPressed: () {},
                  tooltip: 'Edit Patient',
                ),
              ],
            ),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 15),
            
            _buildSectionHeader('Personal Information'),
            SizedBox(height: 10),
            _buildDetailRow('Full Name', '${_patientData!['firstName']} ${_patientData!['lastName']}'),
            _buildDetailRow('Date of Birth', _patientData!['dob']),
            _buildDetailRow('Gender', _patientData!['gender']),
            _buildDetailRow('Contact', _patientData!['contactNumber']),
            _buildDetailRow('Address', _patientData!['address']),
            
            SizedBox(height: 20),
            _buildSectionHeader('Medical Information'),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _patientData!['medicalOverview'] ?? 'No medical history recorded',
                style: TextStyle(fontSize: 15),
              ),
            ),
            
            if (_patientData!['hasLabResults'] == true) ...[
              SizedBox(height: 20),
              _buildSectionHeader('Laboratory Results'),
              SizedBox(height: 10),
              ..._patientData!['labResults'].map<Widget>((result) =>
                  _buildLabResultCard(result)).toList(),
            ],
            
            SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: Colors.teal[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'VIEW FULL HISTORY',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'NEW APPOINTMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Icon(Icons.medical_services, color: Colors.teal[700], size: 20),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
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
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabResultCard(Map<String, dynamic> result) {
    return Card(
      margin: EdgeInsets.only(bottom: 15),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  result['testName'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                Chip(
                  label: Text(
                    result['date'],
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.teal[100],
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildLabResultDetail('Result', result['result']),
            if (result['notes'] != null && result['notes'].isNotEmpty)
              _buildLabResultDetail('Notes', result['notes']),
          ],
        ),
      ),
    );
  }

  Widget _buildLabResultDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey[800], fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  void _searchPatient() {
    if (_patientIdController.text.isEmpty && _surnameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter either Patient ID or Surname to search'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _patientData = {
          'firstName': 'John',
          'lastName': 'Doe',
          'dob': '15/03/1985',
          'gender': 'Male',
          'contactNumber': '07123456789',
          'address': '123 Main St, London, UK',
          'medicalOverview':
              'Hypertension, Type 2 Diabetes. Allergic to penicillin. Current medications: Metformin 500mg twice daily, Lisinopril 10mg daily.',
          'hasLabResults': true,
          'labResults': [
            {
              'testName': 'Complete Blood Count',
              'date': '10/05/2023',
              'result': 'Normal (WBC slightly elevated at 11.2)',
              'notes': 'Follow up recommended in 3 months'
            },
            {
              'testName': 'HbA1c',
              'date': '10/05/2023',
              'result': '7.2%',
              'notes': 'Improved from last reading of 7.8%'
            },
            {
              'testName': 'Lipid Panel',
              'date': '10/05/2023',
              'result': 'Cholesterol: 180 mg/dL, Triglycerides: 150 mg/dL',
              'notes': 'Continue current statin therapy'
            }
          ]
        };
      });
    });
  }

  void _resetSearch() {
    setState(() {
      _patientIdController.clear();
      _surnameController.clear();
      _hasSearched = false;
      _patientData = null;
    });
  }
}