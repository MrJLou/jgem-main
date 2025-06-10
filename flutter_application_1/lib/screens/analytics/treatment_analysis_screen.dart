import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/clinic_service.dart';
import '../../services/api_service.dart';

class TreatmentAnalysisScreen extends StatefulWidget {
  const TreatmentAnalysisScreen({super.key});

  @override
  TreatmentAnalysisScreenState createState() =>
      TreatmentAnalysisScreenState();
}

class TreatmentAnalysisScreenState extends State<TreatmentAnalysisScreen> {
  final Color primaryColor = Colors.teal[700]!;
  Future<List<ClinicService>>? _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _fetchServiceData();
  }

  Future<List<ClinicService>> _fetchServiceData() async {
    try {
      // Fetch all services and sort them by selectionCount in descending order
      final services = await ApiService.getAllClinicServices();
      services.sort((a, b) => b.selectionCount.compareTo(a.selectionCount));
      return services;
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching service data for analytics: $e");
      }
      // Show a snackbar or handle the error appropriately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load service data: $e'),
              backgroundColor: Colors.red),
        );
      }
      return []; // Return empty list on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClinicService>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No service data available.'));
        }

        final services = snapshot.data!;
        final categoryDistribution = _calculateCategoryDistribution(services);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal[50]!, Colors.white],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(services),
                const SizedBox(height: 20),
                _buildTopServicesCard(services),
                const SizedBox(height: 20),
                _buildServiceCategoryCard(categoryDistribution),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, int> _calculateCategoryDistribution(List<ClinicService> services) {
    final Map<String, int> distribution = {};
    for (final service in services) {
      final category = service.category ?? 'Uncategorized';
      distribution[category] = (distribution[category] ?? 0) + service.selectionCount;
    }
    return distribution;
  }

  Widget _buildSummaryCards(List<ClinicService> services) {
    final totalServicesOffered = services.length;
    final mostPopularService = services.isNotEmpty ? services.first.serviceName : 'N/A';
    final totalSelections = services.fold<int>(0, (sum, item) => sum + item.selectionCount);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSummaryCard(
          'Total Services Offered',
          totalServicesOffered.toString(),
          Icons.medical_services_outlined,
          "Count of distinct services",
        ),
        _buildSummaryCard(
          'Most Popular Service',
          mostPopularService,
          Icons.star_rate_rounded,
          "By total selections",
        ),
         _buildSummaryCard(
          'Total Selections Made',
          NumberFormat.compact().format(totalSelections),
          Icons.touch_app,
          "Across all services",
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    String subtitle,
  ) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: value.length > 15 ? 16 : 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopServicesCard(List<ClinicService> allServices) {
    // Take top 5 services, or fewer if not available
    final topServices = allServices.take(5).toList();
    final double maxCount = topServices.isNotEmpty && topServices.first.selectionCount > 0
        ? topServices.first.selectionCount.toDouble()
        : 1.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Most Popular Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (topServices.isEmpty)
              const Center(child: Text("No service usage has been recorded yet."))
            else
              ...topServices.map((service) {
                return _buildServiceUsageBar(
                  service.serviceName,
                  service.selectionCount,
                  service.selectionCount / maxCount, // Normalize for bar width
                  Colors.teal,
                );
              }).expand((widget) => [widget, const SizedBox(height: 15)]),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceUsageBar(String serviceName, int count, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          serviceName,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: percentage.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                builder: (context, double value, child) {
                  return Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withAlpha(179), color],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color: color.withAlpha(26),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              NumberFormat.compact().format(count),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCategoryCard(Map<String, int> categoryDistribution) {
     final totalSelections = categoryDistribution.values.fold(0, (sum, item) => sum + item);
     final List<Color> colors = [
      Colors.blue[400]!,
      Colors.purple[400]!,
      Colors.orange[400]!,
      Colors.green[400]!,
      Colors.red[400]!,
      Colors.indigo[400]!,
    ];

    final sortedCategories = categoryDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Service Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (totalSelections == 0)
              const Center(child: Text("No service categories to display."))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: List.generate(sortedCategories.length, (index) {
                      final entry = sortedCategories[index];
                      final percentage = (entry.value / totalSelections) * 100;
                      return _buildTreatmentStat(
                        entry.key, 
                        percentage.toInt(), 
                        colors[index % colors.length]
                      );
                    }),
                  );
                }
              ),
            const SizedBox(height: 20),
             if (totalSelections > 0)
              _buildTreatmentLegend(sortedCategories, colors, totalSelections),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentStat(String treatment, int percentage, Color color) {
    return Column(
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: percentage.toDouble()),
          duration: const Duration(milliseconds: 1000),
          builder: (context, double value, child) {
            return Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(77), width: 4),
              ),
              child: Center(
                child: Text(
                  '${value.round()}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 90,
          child: Text(
            treatment,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentLegend(List<MapEntry<String, int>> categories, List<Color> colors, int total) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: List.generate(categories.length, (index) {
          final entry = categories[index];
          final percentage = (entry.value / total * 100);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: _buildLegendItem(
              entry.key, 
              colors[index % colors.length], 
              '${percentage.toStringAsFixed(1)}% (${NumberFormat.compact().format(entry.value)})'
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        )
      ],
    );
  }
}

class TreatmentStat {
  final String name;
  final String successRate;
  final String avgRecovery;
  final String followUps;

  TreatmentStat({
    required this.name,
    required this.successRate,
    required this.avgRecovery,
    required this.followUps,
  });
}

Future<List<TreatmentStat>> fetchTreatmentStats() async {
  await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
  return [
    TreatmentStat(
      name: 'Antibiotic Treatment',
      successRate: '85%',
      avgRecovery: '7 days',
      followUps: '2 visits',
    ),
    TreatmentStat(
      name: 'Physical Therapy',
      successRate: '78%',
      avgRecovery: '4 weeks',
      followUps: '6 visits',
    ),
    TreatmentStat(
      name: 'Surgery Recovery',
      successRate: '92%',
      avgRecovery: '3 months',
      followUps: '4 visits',
    ),
    TreatmentStat(
      name: 'Chronic Care',
      successRate: '70%',
      avgRecovery: 'Ongoing',
      followUps: 'Monthly',
    ),
    TreatmentStat(
      name: 'Mental Health',
      successRate: '75%',
      avgRecovery: '6 months',
      followUps: 'Bi-weekly',
    ),
    TreatmentStat(
      name: 'Preventive Care',
      successRate: '95%',
      avgRecovery: 'N/A',
      followUps: 'Yearly',
    ),
  ];
} 