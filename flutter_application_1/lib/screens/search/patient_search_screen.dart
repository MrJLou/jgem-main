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
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _selectedFilter = 'All Filters';
  final List<String> _filters = ['All Filters', 'Active Patients', 'Inactive Patients', 'Upcoming Appointments'];
  
  // Advanced filter values
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDepartment = 'All Departments';
  final List<String> _departments = ['All Departments', 'General Medicine', 'Cardiology', 'Pediatrics', 'Orthopedics'];
  RangeValues _ageRange = const RangeValues(0, 100);
  String _selectedGender = 'All';
  final List<String> _genders = ['All', 'Male', 'Female', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Patient Search',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _buildSearchHeader(),
            const SizedBox(height: 24),
            _buildSearchFilters(),
              if (_hasSearched) ...[
              const SizedBox(height: 24),
              if (_searchResults.isNotEmpty)
                _buildSearchResults()
              else
                _buildNoResultsCard(),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to add patient screen
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
        backgroundColor: Colors.teal[700],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.teal[700],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal[700]!,
            Colors.teal[800]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Patient Search',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: Text(
                'Access patient records, medical history, and appointments',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: Colors.teal.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
              'Search Filters',
                      style: TextStyle(
                fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Term',
                hintText: 'Enter patient name, ID, or contact info',
                prefixIcon: Icon(Icons.search, color: Colors.teal[700]),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                labelStyle: TextStyle(color: Colors.grey[600]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _resetSearch,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
                        items: _filters.map((String filter) {
                          return DropdownMenuItem(
                            value: filter,
                    child: Row(
                      children: [
                                Icon(
                                  _getFilterIcon(filter),
                                  size: 20,
                            color: Colors.teal[700],
                                ),
                                const SizedBox(width: 8),
                                Text(filter),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFilter = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAdvancedFiltersDialog(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('More'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _isLoading = true;
                    _hasSearched = true;
                  });
                  // Use the actual API service here
                  _searchPatients();
                },
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isLoading ? 'SEARCHING...' : 'SEARCH PATIENTS',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Search Results (${_searchResults.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                // Export results functionality
              },
              icon: Icon(Icons.download_outlined, color: Colors.teal[700]),
              label: Text(
                'Export',
                style: TextStyle(color: Colors.teal[700]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._searchResults.map((patient) => _buildPatientCard(patient)).toList(),
      ],
    );
  }

  Widget _buildNoResultsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
        children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Matching Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search criteria or filters',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _resetSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal[700],
                side: BorderSide(color: Colors.teal[700]!),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.teal[50],
                  child: Icon(Icons.person, color: Colors.teal[700], size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['fullName']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient ID: ${patient['id']?.toString() ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Show more options menu
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoSection('Personal Information', [
              _buildDetailRow('Age', patient['age']?.toString() ?? 'N/A'),
              _buildDetailRow('Gender', patient['gender']?.toString() ?? 'N/A'),
              _buildDetailRow('Blood Type', patient['bloodType']?.toString() ?? 'N/A'),
              _buildDetailRow('Contact', patient['contactNumber']?.toString() ?? 'N/A'),
            ]),
            const SizedBox(height: 16),
            _buildInfoSection('Medical Information', [
              _buildDetailRow('Department', patient['department']?.toString() ?? 'N/A'),
              _buildDetailRow('Last Visit', patient['lastVisit']?.toString() ?? 'N/A'),
              _buildDetailRow('Allergies', patient['allergies']?.toString() ?? 'None'),
            ]),
            if (patient['medicalHistory'] != null) ...[
              const SizedBox(height: 24),
              Text(
                'Medical History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                ),
              ),
              const SizedBox(height: 16),
              ..._buildMedicalHistoryList(patient['medicalHistory'] as List<dynamic>),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMedicalHistoryList(List<dynamic> medicalHistory) {
    return medicalHistory.map<Widget>((record) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record['date'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    record['doctor'],
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                record['diagnosis'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Active Patients':
        return Icons.check_circle_outline;
      case 'Inactive Patients':
        return Icons.cancel_outlined;
      case 'Upcoming Appointments':
        return Icons.calendar_today_outlined;
      default:
        return Icons.filter_list_outlined;
    }
  }

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _hasSearched = false;
      _searchResults = [];
      _selectedFilter = 'All Filters';
      _startDate = null;
      _endDate = null;
      _selectedDepartment = 'All Departments';
      _ageRange = const RangeValues(0, 100);
      _selectedGender = 'All';
    });
  }

  Future<void> _searchPatients() async {
    if (_searchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a search term'),
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

    try {
      // Create dummy patient data for testing
      _searchResults = [
        {
          'id': 'P001',
          'fullName': 'John Smith',
          'age': '45',
          'gender': 'Male',
          'bloodType': 'O+',
          'contactNumber': '+44 123 456 7890',
          'department': 'General Medicine',
          'lastVisit': '15/03/2024',
          'allergies': 'Penicillin',
          'medicalHistory': [
            {
              'date': '15/03/2024',
              'doctor': 'Dr. Sarah Wilson',
              'diagnosis': 'Hypertension',
            },
            {
              'date': '01/02/2024',
              'doctor': 'Dr. James Brown',
              'diagnosis': 'Common Cold',
            }
          ]
        },
        {
          'id': 'P002',
          'fullName': 'Mary Johnson',
          'age': '32',
          'gender': 'Female',
          'bloodType': 'A+',
          'contactNumber': '+44 098 765 4321',
          'department': 'Cardiology',
          'lastVisit': '10/03/2024',
          'allergies': 'None',
          'medicalHistory': [
            {
              'date': '10/03/2024',
              'doctor': 'Dr. Michael Chen',
              'diagnosis': 'Annual Checkup',
            }
          ]
        }
      ];

      setState(() {
        _isLoading = false;
      });

      /* Comment out the actual API call for now
      final results = await ApiService.searchPatients(_searchController.text);
      setState(() {
        _searchResults = results.map((patient) => patient.toJson()).toList();
        _isLoading = false;
      });
      */
    } catch (e) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for patients: ${e.toString()}'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showAdvancedFiltersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Advanced Filters',
                  style: TextStyle(color: Colors.teal[700])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date Range',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _startDate = date);
                              }
                            },
                            icon: Icon(Icons.calendar_today,
                                color: Colors.teal[700]),
                            label: Text(
                              _startDate == null
                                  ? 'Start Date'
                                  : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: Colors.grey),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _endDate = date);
                              }
                            },
                            icon: Icon(Icons.calendar_today,
                                color: Colors.teal[700]),
                            label: Text(
                              _endDate == null
                                  ? 'End Date'
                                  : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Department',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _selectedDepartment,
                      isExpanded: true,
                      items: _departments.map((String department) {
                        return DropdownMenuItem(
                          value: department,
                          child: Text(department),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedDepartment = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Age Range',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    RangeSlider(
                      values: _ageRange,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      labels: RangeLabels(
                        _ageRange.start.round().toString(),
                        _ageRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() => _ageRange = values);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Gender',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _selectedGender,
                      isExpanded: true,
                      items: _genders.map((String gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedGender = newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _selectedDepartment = 'All Departments';
                      _ageRange = const RangeValues(0, 100);
                      _selectedGender = 'All';
                    });
                  },
                  child: Text('Reset',
                      style: TextStyle(color: Colors.grey[600])),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _searchPatients();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
