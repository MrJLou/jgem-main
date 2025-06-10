import 'package:flutter/material.dart';

class ServiceRegistrationScreen extends StatefulWidget {
  const ServiceRegistrationScreen({super.key});

  @override
  ServiceRegistrationScreenState createState() => ServiceRegistrationScreenState();
}

class ServiceRegistrationScreenState extends State<ServiceRegistrationScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  String _serviceType = 'Consultation';
  
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: null,
      appBar: AppBar(
        title: const Text(
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
          unselectedLabelColor: Colors.white.withAlpha(179),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 20),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Existing Services'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'New Service'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExistingServicesView(),
          _buildNewServiceForm(),
        ],
      ),
    );
  }

  Widget _buildExistingServicesView() {
    final List<Map<String, dynamic>> existingServices = [
      {
        'name': 'General Consultation',
        'type': 'Consultation',
        'price': '\$50',
        'duration': '30 min',
        'color': Colors.blue[100],
        'icon': Icons.medical_services,
      },
      {
        'name': 'Blood Test',
        'type': 'Laboratory',
        'price': '\$30',
        'duration': '15 min',
        'color': Colors.red[100],
        'icon': Icons.science,
      },
      {
        'name': 'Physical Therapy',
        'type': 'Therapy',
        'price': '\$75',
        'duration': '60 min',
        'color': Colors.green[100],
        'icon': Icons.accessibility_new,
      },
      {
        'name': 'Dental Cleaning',
        'type': 'Dental',
        'price': '\$100',
        'duration': '45 min',
        'color': Colors.orange[100],
        'icon': Icons.cleaning_services,
      },
      {
        'name': 'X-Ray',
        'type': 'Radiology',
        'price': '\$120',
        'duration': '20 min',
        'color': Colors.purple[100],
        'icon': Icons.radio,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: existingServices.length,
      itemBuilder: (context, index) {
        final service = existingServices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: service['color'],
                shape: BoxShape.circle,
              ),
              child: Icon(service['icon'], color: Colors.teal[800]),
            ),
            title: Text(
              service['name']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(service['type']!),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildServiceDetail(
                          Icons.attach_money,
                          'Price',
                          service['price']!,
                        ),
                        _buildServiceDetail(
                          Icons.timer,
                          'Duration',
                          service['duration']!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.edit, color: Colors.teal[700]),
                          label: Text('Edit', style: TextStyle(color: Colors.teal[700])),
                          onPressed: () {
                            // Handle edit
                          },
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Patient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                          ),
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
      ],
    );
  }

  Widget _buildNewServiceForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 10),
            Text(
              'Fill in the details below to register a new service.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _nameController,
              label: 'Service Name',
              icon: Icons.medical_services,
            ),
            const SizedBox(height: 20),
            _buildDropdownField(
              value: _serviceType,
              items: ['Consultation', 'Laboratory', 'Therapy', 'Dental', 'Radiology'],
              label: 'Service Type',
              icon: Icons.category,
              onChanged: (value) {
                setState(() {
                  _serviceType = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _priceController,
                    label: 'Price (\$)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInputField(
                    controller: _durationController,
                    label: 'Duration (min)',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 50),
                elevation: 3,
                shadowColor: Colors.teal.withAlpha(77),
              ),
              child: const Text(
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
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
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
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
          content: const Text('New service registered successfully!'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _tabController?.animateTo(0); // Switch back to existing services tab
    }
  }
}