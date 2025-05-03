import 'package:flutter/material.dart';

class ServiceRegistrationScreen extends StatefulWidget {
  @override
  _ServiceRegistrationScreenState createState() =>
      _ServiceRegistrationScreenState();
}

class _ServiceRegistrationScreenState extends State<ServiceRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _serviceType = 'Consultation';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Service Registration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorPadding: EdgeInsets.symmetric(horizontal: 20),
          tabs: [
            Tab(icon: Icon(Icons.list_alt), text: 'Existing Services'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'New Service'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExistingServicesTab(),
          _buildNewServiceForm(),
        ],
      ),
    );
  }

  Widget _buildExistingServicesTab() {
    final List<Map<String, String>> existingServices = [
      {'name': 'General Consultation', 'type': 'Consultation', 'price': '\$50'},
      {'name': 'Blood Test', 'type': 'Test', 'price': '\$30'},
      {'name': 'Physical Therapy', 'type': 'Therapy', 'price': '\$75'},
    ];

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: existingServices.length,
      itemBuilder: (context, index) {
        final service = existingServices[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.medical_services, color: Colors.teal[800]),
            ),
            title: Text(
              service['name']!,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.category, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(service['type']!, style: TextStyle(fontSize: 12)),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(service['price']!, style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.add, color: Colors.teal[800]),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${service['name']} added to patient'),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewServiceForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register a New Service',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Fill in the details below to register a new service.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            _buildInputField(
              controller: _nameController,
              label: 'Service Name',
              icon: Icons.medical_services,
            ),
            SizedBox(height: 20),
            _buildDropdownField(
              value: _serviceType,
              items: ['Consultation', 'Procedure', 'Test', 'Therapy'],
              label: 'Service Type',
              icon: Icons.category,
              onChanged: (value) {
                setState(() {
                  _serviceType = value!;
                });
              },
            ),
            SizedBox(height: 20),
            _buildInputField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 3,
            ),
            SizedBox(height: 20),
            _buildInputField(
              controller: _priceController,
              label: 'Price (\$)',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size(double.infinity, 50),
                elevation: 3,
                shadowColor: Colors.teal.withOpacity(0.3),
              ),
              child: Text(
                'Register New Service',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Colors.teal[800]),
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[600]),
        prefixIcon: Icon(icon, color: Colors.teal[600]),
        filled: true,
        fillColor: Colors.teal[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
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
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.teal[50],
      style: TextStyle(color: Colors.teal[800]),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[600]),
        prefixIcon: Icon(icon, color: Colors.teal[600]),
        filled: true,
        fillColor: Colors.teal[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: TextStyle(color: Colors.teal[800])),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New service registered successfully!'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }
}