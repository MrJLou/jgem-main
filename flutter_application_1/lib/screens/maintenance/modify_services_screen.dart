import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/clinic_service.dart';
import 'dart:math';
import '../maintenance/update_screen.dart'; // Import for RecentUpdateLogService

class ModifyServicesScreen extends StatefulWidget {
  const ModifyServicesScreen({super.key});

  @override
  _ModifyServicesScreenState createState() => _ModifyServicesScreenState();
}

class _ModifyServicesScreenState extends State<ModifyServicesScreen> {
  final TextEditingController _serviceCategoryController =
      TextEditingController();
  final TextEditingController _specificServiceController =
      TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDescriptionController =
      TextEditingController();

  bool _isLoading = false;
  List<ClinicService> _searchResults = [];
  ClinicService? _selectedServiceForEditing;

  @override
  void initState() {
    super.initState();
    _searchOrFilterServices(fetchInitial: true);
  }

  Future<void> _searchOrFilterServices(
      {String? categoryOverride, bool fetchInitial = false}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      String searchCategory =
          categoryOverride ?? _serviceCategoryController.text;
      if (fetchInitial && searchCategory.isEmpty) {
        // Default to searching all services if category is empty on initial load or after clearing form
      }

      final results =
          await ApiService.searchServicesByCategory(searchCategory.trim());
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

      if (results.isEmpty && !fetchInitial && searchCategory.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('No services found for category "$searchCategory".')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error searching services: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  void _clearFormAndDeselect() {
    _serviceCategoryController.clear();
    _specificServiceController.clear();
    _servicePriceController.clear();
    _serviceDescriptionController.clear();
    setState(() {
      _selectedServiceForEditing = null;
    });
    // After clearing form, refresh the list to show all services or based on cleared category input
    _searchOrFilterServices(fetchInitial: true);
  }

  void _selectServiceForEditing(ClinicService service) {
    setState(() {
      _selectedServiceForEditing = service;
      _serviceCategoryController.text = service.category ?? '';
      _specificServiceController.text = service.serviceName;
      _servicePriceController.text = service.defaultPrice?.toString() ?? '';
      _serviceDescriptionController.text = service.description ?? '';
    });
  }

  Future<void> _saveService() async {
    if (_specificServiceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Service Name cannot be empty.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    final double? price = double.tryParse(_servicePriceController.text);
    if (_servicePriceController.text.isNotEmpty && price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid Price format.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Use the category from the controller, whether it was from editing or newly typed
    String currentCategory = _serviceCategoryController.text.trim();

    try {
      String serviceId;
      bool isUpdating = _selectedServiceForEditing != null;

      if (isUpdating) {
        serviceId = _selectedServiceForEditing!.id;
      } else {
        // For new service, generate ID. ApiService.saveClinicService will also handle if ID exists or not.
        serviceId =
            'service_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      }

      final clinicService = ClinicService(
        id: serviceId,
        serviceName: _specificServiceController.text.trim(),
        category: currentCategory.isNotEmpty ? currentCategory : null,
        defaultPrice: price,
        description: _serviceDescriptionController.text.trim().isNotEmpty
            ? _serviceDescriptionController.text.trim()
            : null,
      );

      String originalName =
          _selectedServiceForEditing?.serviceName ?? clinicService.serviceName;

      ClinicService savedService =
          await ApiService.saveClinicService(clinicService);

      // Log the update
      RecentUpdateLogService.addLog(
          'Service',
          '${isUpdating ? "Updated" : "Added"} service: ${clinicService.serviceName}'
              '${isUpdating && originalName != clinicService.serviceName ? " (was: $originalName)" : ""}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Service "${savedService.serviceName}" ${isUpdating ? 'updated' : 'added'} successfully!'),
            backgroundColor: Colors.green),
      );

      _clearFormAndDeselect(); // Clear form and deselect
      // Refresh the list to show the category of the service just saved/updated, or all if category was cleared
      _searchOrFilterServices(
          categoryOverride: currentCategory.isNotEmpty ? currentCategory : "");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error saving service: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteService(String serviceId, String serviceName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete the service "$serviceName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      String currentCategoryAfterDelete =
          _serviceCategoryController.text.trim();
      try {
        await ApiService.deleteClinicService(serviceId);
        // Log the deletion
        RecentUpdateLogService.addLog(
            'Service', 'Deleted service: $serviceName (ID: $serviceId)');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Service "$serviceName" deleted.'),
              backgroundColor: Colors.orangeAccent),
        );
        _clearFormAndDeselect(); // Clear form and deselect
        _searchOrFilterServices(
            categoryOverride: currentCategoryAfterDelete.isNotEmpty
                ? currentCategoryAfterDelete
                : ""); // Refresh list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting service: $e'),
              backgroundColor: Colors.redAccent),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Modify Services',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel: Input Fields
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _selectedServiceForEditing == null
                          ? 'Add New Service'
                          : 'Edit Service: ${_selectedServiceForEditing!.serviceName}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serviceCategoryController,
                      decoration: InputDecoration(
                        labelText: 'Service Category',
                        hintText:
                            'e.g., Consultation, Laboratory (or leave blank for All)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Search Category / Show All'),
                      onPressed:
                          _isLoading ? null : () => _searchOrFilterServices(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      _selectedServiceForEditing == null
                          ? 'Enter New Service Details:'
                          : 'Editing Details for:',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[700]),
                    ),
                    if (_selectedServiceForEditing != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(_selectedServiceForEditing!.serviceName,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[700])),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _specificServiceController,
                      decoration: InputDecoration(
                        labelText: 'Specific Service Name *',
                        hintText: 'e.g., General Check-up, Blood Test',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _servicePriceController,
                      decoration: InputDecoration(
                        labelText: 'Price (Optional)',
                        hintText: 'e.g., 500.00',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serviceDescriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Brief details about the service',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(_selectedServiceForEditing == null
                          ? Icons.add_circle_outline
                          : Icons.save_alt_outlined),
                      label: Text(_selectedServiceForEditing == null
                          ? 'Save New Service'
                          : 'Update Service'),
                      onPressed: _isLoading ? null : _saveService,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedServiceForEditing == null
                              ? Colors.green[600]
                              : Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 10),
                    if (_selectedServiceForEditing != null)
                      TextButton.icon(
                        icon: Icon(Icons.add_circle_outline,
                            color: Colors.blueGrey[700]),
                        label: Text('Clear Form & Add New',
                            style: TextStyle(color: Colors.blueGrey[700])),
                        onPressed: _clearFormAndDeselect,
                      ),
                  ],
                ),
              ),
            ),
            // Right Panel: Service List
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.teal[50]?.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.teal[300]!, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ]),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _serviceCategoryController.text.trim().isEmpty
                            ? 'Showing All Services'
                            : 'Services in Category: "${_serviceCategoryController.text.trim()}"',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[800]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _searchResults.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      _serviceCategoryController.text
                                                  .trim()
                                                  .isEmpty &&
                                              !_isLoading
                                          ? 'No services found in the system. Add a new service to get started.'
                                          : 'No services found matching your criteria or category is empty.',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.teal[700]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final service = _searchResults[index];
                                    bool isSelected =
                                        _selectedServiceForEditing?.id ==
                                            service.id;
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 4.0),
                                      elevation: isSelected ? 4 : 2,
                                      color: isSelected
                                          ? Colors.teal[100]
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        side: isSelected
                                            ? BorderSide(
                                                color: Colors.teal[700]!,
                                                width: 1.5)
                                            : BorderSide.none,
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 8.0),
                                        leading: Icon(
                                            Icons.medical_services_outlined,
                                            color: Colors.teal[700]),
                                        title: Text(service.serviceName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                          'Category: ${service.category ?? 'N/A'} - Price: ${service.defaultPrice != null ? 'P${service.defaultPrice!.toStringAsFixed(2)}' : 'N/A'}\n${service.description != null && service.description!.isNotEmpty ? service.description : ''}',
                                        ),
                                        isThreeLine:
                                            service.description != null &&
                                                service.description!.isNotEmpty,
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined,
                                                  color:
                                                      Colors.blueAccent[700]),
                                              tooltip: 'Edit Service',
                                              onPressed: () =>
                                                  _selectServiceForEditing(
                                                      service),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline,
                                                  color: Colors.redAccent[700]),
                                              tooltip: 'Delete Service',
                                              onPressed: () => _deleteService(
                                                  service.id,
                                                  service.serviceName),
                                            ),
                                          ],
                                        ),
                                        onTap: () =>
                                            _selectServiceForEditing(service),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
