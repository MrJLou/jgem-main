import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ServiceSearchScreen extends StatefulWidget {
  const ServiceSearchScreen({super.key});

  @override
  _ServiceSearchScreenState createState() => _ServiceSearchScreenState();
}

class _ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _selectedCategory = 'All Categories';
  final List<String> _categories = [
    'All Categories',
    'General Medicine',
    'Laboratory',
    'Radiology',
    'Surgery',
    'Dental',
    'Physical Therapy'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Service Search',
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
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchCard(),
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
          // Navigate to add service screen
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
        backgroundColor: Colors.teal[700],
      ),
    );
  }

  Widget _buildHeader() {
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
              'Medical Services',
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
                'Search and manage clinic services and procedures',
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

  Widget _buildSearchCard() {
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
              'Search Services',
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
                labelText: 'Service Name or ID',
                hintText: 'Enter service name or ID',
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
                        value: _selectedCategory,
                        isExpanded: true,
                        items: _categories.map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
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
                    onPressed: () {
                      // Show advanced filters
                    },
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
                onPressed: _isLoading ? null : _searchServices,
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
                  _isLoading ? 'SEARCHING...' : 'SEARCH SERVICES',
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
        ..._searchResults.map((service) => _buildServiceCard(service)),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ExpansionTile(
        title: Text(
          service['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${service['id']} | ${service['category']}'),
            Text('Duration: ${service['duration']} | Price: £${service['price']}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: service['availability'] == 'Available'
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: service['availability'] == 'Available'
                  ? Colors.green.withOpacity(0.5)
                  : Colors.orange.withOpacity(0.5),
            ),
          ),
          child: Text(
            service['availability'],
            style: TextStyle(
              color: service['availability'] == 'Available'
                  ? Colors.green[700]
                  : Colors.orange[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service['description'],
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Edit service functionality
                      },
                      icon: Icon(Icons.edit_outlined, color: Colors.teal[700]),
                      label: Text(
                        'Edit',
                        style: TextStyle(color: Colors.teal[700]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {
                        // Delete service functionality
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
              'No Services Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search criteria or category',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedCategory = 'All Categories';
                  _hasSearched = false;
                  _searchResults = [];
                });
              },
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

  Future<void> _searchServices() async {
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
      // Create dummy services data for testing
      _searchResults = [
        {
          'id': 'S001',
          'name': 'General Consultation',
          'category': 'General Medicine',
          'duration': '30 mins',
          'price': 75.00,
          'description': 'Standard medical consultation with a general practitioner',
          'availability': 'Available',
        },
        {
          'id': 'S002',
          'name': 'Complete Blood Count',
          'category': 'Laboratory',
          'duration': '15 mins',
          'price': 45.00,
          'description': 'Comprehensive blood test analyzing red cells, white cells, and platelets',
          'availability': 'Available',
        },
        {
          'id': 'S003',
          'name': 'X-Ray Chest',
          'category': 'Radiology',
          'duration': '20 mins',
          'price': 120.00,
          'description': 'Chest X-ray imaging for diagnostic purposes',
          'availability': 'Maintenance',
        },
        {
          'id': 'S004',
          'name': 'Dental Cleaning',
          'category': 'Dental',
          'duration': '45 mins',
          'price': 85.00,
          'description': 'Professional dental cleaning and checkup',
          'availability': 'Available',
        }
      ];

      // Filter by category if selected
      if (_selectedCategory != 'All Categories') {
        _searchResults = _searchResults.where((service) => 
          service['category'] == _selectedCategory
        ).toList();
      }

      // Filter by search term
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        _searchResults = _searchResults.where((service) => 
          service['name'].toString().toLowerCase().contains(searchTerm) ||
          service['id'].toString().toLowerCase().contains(searchTerm)
        ).toList();
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for services: ${e.toString()}'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
