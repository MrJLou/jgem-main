import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/clinic_service.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:uuid/uuid.dart';

class ServiceRegistrationScreen extends StatefulWidget {
  const ServiceRegistrationScreen({super.key});

  @override
  ServiceRegistrationScreenState createState() => ServiceRegistrationScreenState();
}

class ServiceRegistrationScreenState extends State<ServiceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _serviceType = 'Consultation';
  
  late Future<List<ClinicService>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  void _loadServices() {
    setState(() {
      _servicesFuture = ApiService.getClinicServices();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final newService = ClinicService(
        id: const Uuid().v4(),
        serviceName: _nameController.text,
        description: _descriptionController.text,
        category: _serviceType,
        defaultPrice: double.tryParse(_priceController.text),
        selectionCount: 0,
      );

      try {
        await ApiService.createClinicService(newService);
        Navigator.of(context).pop(); // Close dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service Added Successfully')),
        );
        _formKey.currentState?.reset();
        _nameController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _loadServices(); // Refresh data table
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add service: $e')),
        );
      }
    }
  }

  Future<void> _showAddServiceDialog() {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Register a New Service'),
          content: SizedBox(width: 500, child: _buildNewServiceForm()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Service Registration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Clinic Services',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.teal[800],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddServiceDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Service', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(10),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: FutureBuilder<List<ClinicService>>(
                  future: _servicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading services: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No services found in the database.'));
                    }

                    final services = snapshot.data!;
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 40,
                        headingTextStyle: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('SERVICE NAME')),
                          DataColumn(label: Text('DESCRIPTION')),
                          DataColumn(label: Text('CATEGORY')),
                          DataColumn(label: Text('PRICE')),
                        ],
                        rows: services.map((service) {
                          return DataRow(cells: [
                            DataCell(Text(service.id.length > 8 ? service.id.substring(0, 8) : service.id)),
                            DataCell(Text(service.serviceName)),
                            DataCell(Text(service.description ?? 'N/A')),
                            DataCell(Text(service.category ?? 'N/A')),
                            DataCell(Text(service.defaultPrice?.toStringAsFixed(2) ?? '0.00')),
                          ]);
                        }).toList(),
                        columnSpacing: 40,
                        horizontalMargin: 24,
                        showCheckboxColumn: false,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewServiceForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInputField(
              controller: _nameController,
              label: 'Service Name',
              prefixIcon: const Icon(Icons.medical_services),
            ),
            const SizedBox(height: 20),
            _buildDropdownField(
              value: _serviceType,
              items: ['Consultation', 'Laboratory'],
              label: 'Service Type',
              prefixIcon: const Icon(Icons.category),
              onChanged: (value) {
                setState(() {
                  _serviceType = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _priceController,
              label: 'Price (PHP)',
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.0),
                child: Text('₱', style: TextStyle(fontSize: 18)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _descriptionController,
              label: 'Description',
              prefixIcon: const Icon(Icons.description),
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
    Widget? prefixIcon,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon,
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a $label';
        }
        return null;
      },
      maxLines: maxLines,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    Widget? prefixIcon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon,
      ),
      items: items.map((label) => DropdownMenuItem(
        value: label,
        child: Text(label),
      )).toList(),
      onChanged: onChanged,
    );
  }
}