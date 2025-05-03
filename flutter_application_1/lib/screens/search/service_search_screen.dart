import 'package:flutter/material.dart';

class ServiceSearchScreen extends StatefulWidget {
  @override
  _ServiceSearchScreenState createState() => _ServiceSearchScreenState();
}

class _ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _serviceNameController = TextEditingController();
  String _selectedCategory = 'All';
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];

  final List<String> _categories = [
    'All',
    'Consultation',
    'Diagnostic',
    'Treatment',
    'Therapy',
    'Surgical'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Service Search',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find Medical Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Search our catalog of available medical services',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              shadowColor: Colors.teal.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _serviceNameController,
                      label: 'Service Name',
                      icon: Icons.search,
                      hintText: 'e.g. Blood Test, Consultation',
                    ),
                    SizedBox(height: 20),
                    _buildDropdownField(
                      value: _selectedCategory,
                      items: _categories,
                      label: 'Service Category',
                      icon: Icons.category,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                    SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _searchServices,
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
                                'SEARCH SERVICES',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
              if (_services.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Results (${_services.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    SizedBox(height: 15),
                    ..._services.map((service) =>
                        _buildServiceCard(service)).toList(),
                  ],
                )
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
                        Icon(Icons.search_off, color: Colors.orange[700]),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'No services found matching your criteria',
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
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
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
        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        labelStyle: TextStyle(color: Colors.grey[600]),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
      style: TextStyle(color: Colors.grey[800], fontSize: 15),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Card(
      margin: EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    service['name'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  Chip(
                    label: Text(service['category']),
                    backgroundColor: Colors.teal[100],
                    labelStyle: TextStyle(color: Colors.teal[800]),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  _buildServiceDetailChip(
                    icon: Icons.access_time,
                    text: service['duration'],
                    color: Colors.blue[100]!,
                  ),
                  SizedBox(width: 10),
                  _buildServiceDetailChip(
                    icon: Icons.attach_money,
                    text: '£${service['price']}',
                    color: Colors.green[100]!,
                  ),
                ],
              ),
              SizedBox(height: 15),
              Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              SizedBox(height: 5),
              Text(
                service['description'],
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.teal[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'BOOK THIS SERVICE',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontWeight: FontWeight.bold,
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

  Widget _buildServiceDetailChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Chip(
      backgroundColor: color,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }

  void _searchServices() {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _services = [
          {
            'name': 'General Consultation',
            'category': 'Consultation',
            'duration': '30 mins',
            'price': '50.00',
            'description': 'A general health consultation with a doctor to discuss any health concerns.'
          },
          {
            'name': 'Blood Test Panel',
            'category': 'Diagnostic',
            'duration': '15 mins',
            'price': '75.00',
            'description': 'Comprehensive blood test including CBC, glucose, and lipid profile.'
          },
          {
            'name': 'Physiotherapy Session',
            'category': 'Therapy',
            'duration': '45 mins',
            'price': '65.00',
            'description': 'One-on-one physiotherapy session for rehabilitation or injury treatment.'
          }
        ].where((service) => 
          service['name']!.toLowerCase().contains(_serviceNameController.text.toLowerCase()) &&
          (_selectedCategory == 'All' || service['category'] == _selectedCategory)
        ).toList();
      });
    });
  }
}