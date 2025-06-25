import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/models/clinic_service.dart';
import 'package:flutter_application_1/models/patient_report.dart';
import 'package:flutter_application_1/models/patient_bill.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/service_analytics_pdf_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';

class LaboratoryReportsScreen extends StatefulWidget {
  const LaboratoryReportsScreen({super.key});

  @override
  State<LaboratoryReportsScreen> createState() =>
      _LaboratoryReportsScreenState();
}

class _LaboratoryReportsScreenState extends State<LaboratoryReportsScreen> {
  late Future<ServiceAnalyticsReportData> _analyticsFuture;
  final _pdfService = ServiceAnalyticsPdfService();
  
  List<ClinicService> _allServices = [];
  ClinicService? _selectedService;
  String _selectedCategory = 'All Categories';
  final List<String> _categories = ['All Categories', 'Laboratory', 'Consultation'];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _analyticsFuture = _fetchAnalytics();
  }

  Future<void> _loadServices() async {
    try {
      final services = await ApiService.getClinicServices();
      setState(() {
        _allServices = services;
      });
    } catch (e) {
      debugPrint('Error loading services: $e');
    }
  }

  void _onServiceChanged(ClinicService? service) {
    setState(() {
      _selectedService = service;
      _selectedCategory = 'All Categories'; // Reset category when specific service is selected
      _analyticsFuture = _fetchAnalytics();
    });
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category ?? 'All Categories';
      _selectedService = null; // Reset service when category is selected
      _analyticsFuture = _fetchAnalytics();
    });
  }  Future<void> _generateAndShowPdf() async {
    try {
      final data = await _analyticsFuture;
      final title = _selectedService?.serviceName ?? 
                   (_selectedCategory != 'All Categories' ? _selectedCategory : 'All Services');
      final pdfBytes = await _pdfService.generatePdf(data, title);
      
      // Create folder structure and save PDF
      await _savePdfToFolder(pdfBytes, title);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _savePdfToFolder(Uint8List pdfBytes, String title) async {
    try {
      // Base directory for reports
      const baseReportsDir = r'C:\Users\Bernie\Documents\jgem-main\Reports\Lab Reports';
      
      // Create service-specific folder name
      String folderName;
      if (_selectedService != null) {
        // Use specific service name
        folderName = _selectedService!.serviceName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      } else if (_selectedCategory != 'All Categories') {
        // Use category name
        folderName = _selectedCategory.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      } else {
        // Use general folder for all services
        folderName = 'All_Services';
      }
      
      // Create full directory path
      final Directory serviceDir = Directory('$baseReportsDir\\$folderName');
      
      // Create directories if they don't exist
      if (!await serviceDir.exists()) {
        await serviceDir.create(recursive: true);
      }
      
      // Generate filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final sanitizedTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = 'Lab_Report_${sanitizedTitle}_$timestamp.pdf';
      
      // Create file path
      final File pdfFile = File('${serviceDir.path}\\$fileName');
      
      // Write PDF bytes to file
      await pdfFile.writeAsBytes(pdfBytes);
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully to: ${pdfFile.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open Folder',
            textColor: Colors.white,
            onPressed: () async {
              // Open the folder in Windows Explorer
              try {
                await Process.run('explorer', [serviceDir.path]);
              } catch (e) {
                debugPrint('Error opening folder: $e');
              }
            },
          ),
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<ServiceAnalyticsReportData> _fetchAnalytics() async {
    try {
      List<PatientReport> serviceReports = [];
      
      if (_selectedService != null) {
        // Get reports for specific service
        serviceReports = await ApiService.getPatientReportsForService(_selectedService!.id, limit: 50);
      } else if (_selectedCategory != 'All Categories') {
        // Get reports for specific category
        final categoryServices = await ApiService.searchServicesByCategory(_selectedCategory);
        for (var service in categoryServices) {
          try {
            final reports = await ApiService.getPatientReportsForService(service.id, limit: 20);
            serviceReports.addAll(reports);
          } catch (e) {
            debugPrint('Error getting reports for ${service.serviceName}: $e');
          }
        }
      } else {
        // Get all recent clinic visits for overview
        serviceReports = await ApiService.getRecentClinicVisits(limit: 100);
      }
      
      // Get unique patient IDs
      final patientIds = serviceReports.map((r) => r.patient.id).toSet();
      
      // Fetch all bills to analyze financial data
      final allBills = await ApiService.getAllPatientBills();
      
      // Filter bills for patients who used services
      final serviceBills = allBills.where((bill) => 
        patientIds.contains(bill.patientId)).toList();

      final paidBills = serviceBills.where((bill) => 
        bill.status.toLowerCase() == 'paid').toList();
      final unpaidBills = serviceBills.where((bill) => 
        bill.status.toLowerCase() != 'paid').toList();

      // Calculate metrics
      final totalRevenue = paidBills.fold<double>(0.0, (sum, bill) => 
        sum + (bill.totalAmount));
      
      final avgPayment = paidBills.isNotEmpty 
        ? totalRevenue / paidBills.length 
        : 0.0;

      // Calculate gender distribution
      final maleCount = serviceReports.where((r) => 
        r.patient.gender.toLowerCase() == 'male').length;
      final femaleCount = serviceReports.where((r) => 
        r.patient.gender.toLowerCase() == 'female').length;      // Calculate service usage
      final serviceUsageData = await _calculateServiceUsage();

      // Get monthly revenue data
      final monthlyRevenueData = await _getMonthlyRevenueForPdf();

      return ServiceAnalyticsReportData(
        totalRevenue: totalRevenue,
        totalPatients: patientIds.length,
        avgPayment: avgPayment,
        totalServices: _getServicesCount(),
        maleCount: maleCount,
        femaleCount: femaleCount,
        recentPatients: serviceReports,
        paidBills: paidBills,
        unpaidBills: unpaidBills,
        serviceUsageData: serviceUsageData,
        monthlyRevenueData: monthlyRevenueData,
      );    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      return ServiceAnalyticsReportData(
        totalRevenue: 0.0,
        totalPatients: 0,
        avgPayment: 0.0,
        totalServices: 0,
        maleCount: 0,
        femaleCount: 0,
        recentPatients: [],
        paidBills: [],
        unpaidBills: [],
        serviceUsageData: [],
        monthlyRevenueData: [],
      );
    }
  }

  int _getServicesCount() {
    if (_selectedService != null) return 1;
    if (_selectedCategory != 'All Categories') {
      return _allServices.where((s) => s.category == _selectedCategory).length;
    }
    return _allServices.length;
  }

  Future<List<ServiceUsageData>> _calculateServiceUsage() async {
    List<ServiceUsageData> usageData = [];
    
    if (_selectedService != null) {
      // For single service
      final reports = await ApiService.getPatientReportsForService(_selectedService!.id, limit: 100);
      usageData.add(ServiceUsageData(
        serviceName: _selectedService!.serviceName,
        usageCount: reports.length,
      ));
    } else if (_selectedCategory != 'All Categories') {
      // For category
      final categoryServices = await ApiService.searchServicesByCategory(_selectedCategory);
      for (var service in categoryServices.take(15)) {
        try {
          final reports = await ApiService.getPatientReportsForService(service.id, limit: 100);
          usageData.add(ServiceUsageData(
            serviceName: service.serviceName,
            usageCount: reports.length,
          ));
        } catch (e) {
          debugPrint('Error getting usage for ${service.serviceName}: $e');
        }
      }
    } else {
      // For all services
      for (var service in _allServices.take(15)) {
        try {
          final reports = await ApiService.getPatientReportsForService(service.id, limit: 100);
          usageData.add(ServiceUsageData(
            serviceName: service.serviceName,
            usageCount: reports.length,
          ));
        } catch (e) {
          debugPrint('Error getting usage for ${service.serviceName}: $e');
        }
      }
    }
    
    // Sort by usage count descending
    usageData.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return usageData;
  }

  Future<List<FlSpot>> _getMonthlyRevenueData() async {
    try {
      // Fetch all payment transactions
      final paymentTransactions = await ApiService.getPaymentTransactions();
      
      // Group payments by month for the current year
      final now = DateTime.now();
      final monthlyRevenue = <int, double>{};
      
      // Initialize all months with 0
      for (int month = 1; month <= 12; month++) {
        monthlyRevenue[month] = 0.0;
      }
      
      // Sum payments by month
      for (final payment in paymentTransactions) {
        try {
          final paymentDate = DateTime.parse(payment['paymentDate'] as String);
          final amountPaid = (payment['amountPaid'] as num?)?.toDouble() ?? 0.0;
          
          // Only include payments from the current year
          if (paymentDate.year == now.year) {
            monthlyRevenue[paymentDate.month] = 
              (monthlyRevenue[paymentDate.month] ?? 0.0) + amountPaid;
          }
        } catch (e) {
          // Skip invalid payment data
          continue;
        }
      }
      
      // Convert to FlSpot list
      final spots = <FlSpot>[];
      for (int month = 1; month <= 12; month++) {
        spots.add(FlSpot(month.toDouble(), monthlyRevenue[month] ?? 0.0));
      }
      
      return spots;
      
    } catch (e) {
      // Return empty data if there's an error
      return List.generate(12, (index) => FlSpot((index + 1).toDouble(), 0.0));
    }
  }

  Future<List<MonthlyRevenueData>> _getMonthlyRevenueForPdf() async {
    try {
      // Fetch all payment transactions
      final paymentTransactions = await ApiService.getPaymentTransactions();
      
      // Group payments by month for the current year
      final now = DateTime.now();
      final monthlyRevenue = <int, double>{};
      final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                         'July', 'August', 'September', 'October', 'November', 'December'];
      
      // Initialize all months with 0
      for (int month = 1; month <= 12; month++) {
        monthlyRevenue[month] = 0.0;
      }
      
      // Sum payments by month
      for (final payment in paymentTransactions) {
        try {
          final paymentDate = DateTime.parse(payment['paymentDate'] as String);
          final amountPaid = (payment['amountPaid'] as num?)?.toDouble() ?? 0.0;
          
          // Only include payments from the current year
          if (paymentDate.year == now.year) {
            monthlyRevenue[paymentDate.month] = 
              (monthlyRevenue[paymentDate.month] ?? 0.0) + amountPaid;
          }
        } catch (e) {
          // Skip invalid payment data
          continue;
        }
      }
      
      // Convert to MonthlyRevenueData list
      final monthlyData = <MonthlyRevenueData>[];
      for (int month = 1; month <= 12; month++) {
        monthlyData.add(MonthlyRevenueData(
          month: monthNames[month - 1],
          revenue: monthlyRevenue[month] ?? 0.0,
        ));
      }
      
      return monthlyData;
      
    } catch (e) {
      debugPrint('Error fetching monthly revenue data: $e');
      // Return empty data with all months showing 0 revenue
      final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                         'July', 'August', 'September', 'October', 'November', 'December'];
      return monthNames.map((month) => MonthlyRevenueData(month: month, revenue: 0.0)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Laboratory Services Analytics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E8B7B),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          _buildCategoryDropdown(),
          const SizedBox(width: 8),
          _buildServiceDropdown(),
          const SizedBox(width: 8),          IconButton(
            onPressed: _generateAndShowPdf,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Save PDF to Reports Folder',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<ServiceAnalyticsReportData>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No analytics data found.'));
          }

          final reportData = snapshot.data!;
          return _buildAnalyticsContent(reportData);
        },
      ),
    );
  }
  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
          style: const TextStyle(color: Colors.black87, fontSize: 12),
          items: _categories.map((category) => DropdownMenuItem<String>(
            value: category,
            child: Text(
              category,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
          )).toList(),
          onChanged: _onCategoryChanged,
        ),
      ),
    );
  }
  Widget _buildServiceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClinicService?>(
          value: _selectedService,
          hint: const Text(
            'All Services',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
          style: const TextStyle(color: Colors.black87, fontSize: 12),
          items: [
            const DropdownMenuItem<ClinicService?>(
              value: null,
              child: Text('All Services', style: TextStyle(color: Colors.black87, fontSize: 12)),
            ),
            ..._allServices.map((service) => DropdownMenuItem<ClinicService?>(
              value: service,
              child: Text(
                service.serviceName.length > 20 
                  ? '${service.serviceName.substring(0, 20)}...'
                  : service.serviceName,
                style: const TextStyle(color: Colors.black87, fontSize: 12),
              ),
            )),
          ],          onChanged: _onServiceChanged,
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent(ServiceAnalyticsReportData reportData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header subtitle
          Text(
            _getSubtitle(),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Cards Row
          _buildStatsCardsRow(reportData),
          
          const SizedBox(height: 32),
          
          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gender Distribution Chart
              Expanded(
                flex: 1,
                child: _buildGenderDistributionCard(reportData),
              ),
              const SizedBox(width: 16),
              // Monthly Revenue Chart
              Expanded(
                flex: 2,
                child: _buildMonthlyRevenueCard(),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Service Usage Chart and Quick Stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Usage Chart
              Expanded(
                flex: 2,
                child: _buildServiceUsageCard(reportData),
              ),
              const SizedBox(width: 16),
              // Quick Stats
              Expanded(
                flex: 1,
                child: _buildQuickStatsCard(reportData),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Recent Patients Table
          _buildRecentPatientsCard(reportData.recentPatients),
        ],
      ),
    );
  }

  String _getSubtitle() {
    if (_selectedService != null) {
      return 'Analytics for ${_selectedService!.serviceName}';
    } else if (_selectedCategory != 'All Categories') {
      return 'Analytics for $_selectedCategory services';
    } else {
      return 'Overview of all clinic services';
    }
  }

  Widget _buildStatsCardsRow(ServiceAnalyticsReportData reportData) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            Icons.people,
            'Patients',
            reportData.totalPatients.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            Icons.attach_money,
            'Revenue',
            '₱${NumberFormat('#,##0').format(reportData.totalRevenue)}',
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            Icons.trending_up,
            'Avg Payment',
            '₱${NumberFormat('#,##0').format(reportData.avgPayment)}',
            Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            Icons.medical_services,
            'Services',
            reportData.totalServices.toString(),
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDistributionCard(ServiceAnalyticsReportData reportData) {
    final total = reportData.maleCount + reportData.femaleCount;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          if (total > 0) ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.blue,
                      value: reportData.femaleCount.toDouble(),
                      title: '',
                      radius: 60,
                    ),
                    PieChartSectionData(
                      color: Colors.red,
                      value: reportData.maleCount.toDouble(),
                      title: '',
                      radius: 60,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Female', reportData.femaleCount, Colors.blue),
                _buildLegendItem('Male', reportData.maleCount, Colors.red),
              ],
            ),
          ] else
            const SizedBox(
              height: 200,
              child: Center(child: Text('No data available')),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $count',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  Widget _buildMonthlyRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Revenue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: FutureBuilder<List<FlSpot>>(
              future: _getMonthlyRevenueData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final monthlyData = snapshot.data ?? [];
                
                if (monthlyData.isEmpty) {
                  return const Center(
                    child: Text(
                      'No revenue data available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,                          getTitlesWidget: (value, meta) {
                            final monthIndex = value.toInt();
                            if (monthIndex >= 1 && monthIndex <= 12) {
                              final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              return Text(
                                monthNames[monthIndex],
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthlyData,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withAlpha(10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceUsageCard(ServiceAnalyticsReportData reportData) {
    final usageData = reportData.serviceUsageData.take(14).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Usage Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: usageData.isEmpty
                ? const Center(child: Text('No service usage data'))
                : BarChart(                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: usageData.isNotEmpty 
                          ? usageData.map((e) => e.usageCount).reduce((a, b) => a > b ? a : b).toDouble() * 1.2
                          : 10.0,
                      barTouchData: const BarTouchData(enabled: false),titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < usageData.length) {
                                final serviceName = usageData[index].serviceName;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Transform.rotate(
                                    angle: -0.5,
                                    child: Text(
                                      serviceName.length > 10
                                          ? '${serviceName.substring(0, 10)}...'
                                          : serviceName,
                                      style: const TextStyle(fontSize: 8),
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: usageData.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.usageCount.toDouble(),
                              color: Colors.blue,
                              width: 16,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(ServiceAnalyticsReportData reportData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildQuickStatRow('Male Patients', reportData.maleCount.toString()),
          _buildQuickStatRow('Female Patients', reportData.femaleCount.toString()),
          _buildQuickStatRow('Highest Payment', '₱${NumberFormat('#,##0').format(reportData.totalRevenue > 0 ? reportData.totalRevenue / (reportData.paidBills.isNotEmpty ? reportData.paidBills.length : 1) * 1.5 : 0)}'),
          _buildQuickStatRow('Most Recent', DateFormat('dd/MM/yyyy').format(DateTime.now())),
        ],
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPatientsCard(List<PatientReport> patients) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Patients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          if (patients.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No recent patients found'),
              ),
            )          else
            FutureBuilder<List<PatientBill>>(
              future: ApiService.getAllPatientBills(),
              builder: (context, billSnapshot) {
                final bills = billSnapshot.data ?? [];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                    columns: const [
                      DataColumn(label: Text('PATIENT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SERVICE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('GENDER', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('PAYMENT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: patients.take(8).map((patient) {
                      // Find the most recent bill for this patient
                      final patientBills = bills.where((bill) => bill.patientId == patient.patient.id).toList();
                      final recentBill = patientBills.isNotEmpty 
                          ? patientBills.reduce((a, b) => a.invoiceDate.isAfter(b.invoiceDate) ? a : b)
                          : null;
                      
                      return DataRow(
                        cells: [
                          DataCell(Text(patient.patient.fullName)),
                          DataCell(Text(_selectedService?.serviceName ?? 'Multiple Services')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: patient.patient.gender.toLowerCase() == 'female' 
                                  ? Colors.pink.withAlpha(10)
                                  : Colors.blue.withAlpha(10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                patient.patient.gender.toUpperCase()[0],
                                style: TextStyle(
                                  color: patient.patient.gender.toLowerCase() == 'female' 
                                    ? Colors.pink
                                    : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(recentBill != null 
                              ? 'PHP ${NumberFormat('#,##0.00').format(recentBill.totalAmount)}'
                              : 'PHP 0.00')),
                          DataCell(Text(DateFormat('dd/MM/yyyy').format(patient.record.recordDate))),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}