import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/clinic_service.dart';
import '../../models/patient.dart';
import '../../services/api_service.dart';

class ServiceSearchScreen extends StatefulWidget {
  const ServiceSearchScreen({super.key});

  @override
  ServiceSearchScreenState createState() => ServiceSearchScreenState();
}

class ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedService;
  String _selectedCategory = 'All Categories';
  final List<String> _categories = [
    'All Categories',
    'Consultation',
    'Laboratory',
  ];

  // State for analytics
  int? _timesAvailed;
  List<Map<String, dynamic>> _usageTrend = [];
  List<Patient> _recentPatients = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _selectedService = null;
    });

    try {
      final services = await ApiService.getClinicServices();
      if (!mounted) return;
      setState(() {
        _searchResults = services.map((s) => s.toJson()).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading services: $e')),
      );
    }
  }

  Future<void> _fetchServiceDetails(String serviceId) async {
    setState(() {
      // Reset analytics data and show loading state if needed
      _timesAvailed = null;
      _usageTrend = [];
      _recentPatients = [];
    });

    try {
      // Fetch all details in parallel
      final results = await Future.wait([
        ApiService.getServiceTimesAvailed(serviceId),
        ApiService.getServiceUsageTrend(serviceId),
        ApiService.getRecentPatientsForService(serviceId),
      ]);

      if (!mounted) return;

      setState(() {
        _timesAvailed = results[0] as int;
        _usageTrend = results[1] as List<Map<String, dynamic>>;
        _recentPatients = results[2] as List<Patient>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching service details: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Service Dashboard',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Search & Results
          Expanded(
            flex: 2,
            child: _buildSearchPane(),
          ),
          const VerticalDivider(width: 1),
          // Right Pane: Analytics
          Expanded(
            flex: 4,
            child: _buildAnalyticsPane(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPane() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildSearchCard(),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildSearchResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Services',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal[800],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Service Name or ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: _categories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchServices,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No services found.'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
          child: Text(
            'Results (${_searchResults.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final service = _searchResults[index];
                final isSelected = _selectedService != null &&
                    _selectedService!['id'] == service['id'];
                return ListTile(
                  title: Text(service['serviceName'] ?? ''),
                  tileColor: isSelected ? Colors.teal.withAlpha(10) : null,
                  onTap: () {
                    setState(() {
                      _selectedService = service;
                    });
                    _fetchServiceDetails(service['id']);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsPane() {
    if (_selectedService == null) {
      return const Center(
        child: Text('Select a service to view details'),
      );
    }

    final service = ClinicService.fromJson(_selectedService!);
    final price = service.defaultPrice?.toStringAsFixed(2) ?? 'N/A';
    final selectionCount = _timesAvailed?.toString() ?? '...';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            service.serviceName,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            service.description ?? 'No description available.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Metrics
          Row(
            children: [
              _buildMetricCard('Price', '₱$price', Icons.attach_money, Colors.green),
              const SizedBox(width: 16),
              _buildMetricCard('Times Availed', selectionCount, Icons.person, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),

          // Graph
          _buildUsageGraphCard(),
          const SizedBox(height: 24),

          // Patient List
          _buildPatientListCard(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(10),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageGraphCard() {
    final List<BarChartGroupData> barGroups = [];
    if (_usageTrend.isNotEmpty) {
      for (var i = 0; i < _usageTrend.length; i++) {
        final trendItem = _usageTrend[i];
        final count = (trendItem['count'] as int?)?.toDouble() ?? 0.0;
        barGroups.add(_makeGroupData(i, count));
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage Trend (Last 6 Months)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: _usageTrend.isEmpty
                  ? const Center(child: Text("No usage data available."))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barGroups,
                        titlesData: const FlTitlesData(
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [BarChartRodData(toY: y, color: Colors.teal, width: 15)],
    );
  }

  Widget _buildPatientListCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recently Availed By', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_recentPatients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No recent patients for this service.'),
              )
            else
              ..._recentPatients.map((patient) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(patient.fullName),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _searchServices() async {
    if (_searchController.text.isEmpty && _selectedCategory == 'All Categories') {
      _loadInitialData();
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedService = null;
      _timesAvailed = null;
      _usageTrend = [];
      _recentPatients = [];
    });

    try {
      final results = await ApiService.searchServices(
        searchTerm: _searchController.text,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching services: $e')),
      );
    }
  }
}
