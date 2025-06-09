import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../models/active_patient_queue_item.dart';
import '../../services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class PatientTrendsScreen extends StatefulWidget {
  const PatientTrendsScreen({super.key});

  @override
  _PatientTrendsScreenState createState() => _PatientTrendsScreenState();
}

class _PatientTrendsScreenState extends State<PatientTrendsScreen> {
  final Color primaryColor = Colors.teal[700]!;
  Future<Map<String, dynamic>>? _trendsFuture;

  @override
  void initState() {
    super.initState();
    _trendsFuture = _fetchTrendsData();
  }

  void _refreshData() {
    setState(() {
      _trendsFuture = _fetchTrendsData();
    });
  }

  Future<Map<String, dynamic>> _fetchTrendsData() async {
    try {
      // 1. Fetch all appointments (considered "Scheduled")
      final allAppointments = await ApiService.getAllAppointments();

      // 2. Fetch all queue items and filter for "Walk-ins"
      final allQueueItems = await ApiService.getAllQueueItems();
      final walkInQueueItems = allQueueItems
          .where((q) =>
              q.originalAppointmentId == null ||
              q.originalAppointmentId!.isEmpty)
          .toList();

      // --- Process Scheduled Appointments ---
      final scheduledMonthlyData = _calculateMonthlyTrendsForAppointments(allAppointments);
      final scheduledStatusData = _calculateStatusDistributionForAppointments(allAppointments);
      final totalScheduledThisMonth = scheduledMonthlyData['totalThisMonth'] ?? 0;
      final totalScheduledLastMonth = scheduledMonthlyData['totalLastMonth'] ?? 0;
      final scheduledGrowth = _calculateGrowth(totalScheduledThisMonth, totalScheduledLastMonth);
      final scheduledServiceDataRaw = _calculateServiceDistributionForAppointments(allAppointments);

      // --- Process Walk-in Queue Items ---
      final walkInMonthlyData = _calculateMonthlyTrendsForQueueItems(walkInQueueItems);
      final walkInStatusData = _calculateStatusDistributionForQueueItems(walkInQueueItems);
      final totalWalkInThisMonth = walkInMonthlyData['totalThisMonth'] ?? 0;
      final walkInServiceDataRaw = _calculateServiceDistributionForQueueItems(walkInQueueItems);
      
      // --- Combine Data ---
      final combinedStatusCounts = <String, int>{};
      scheduledStatusData.forEach((key, value) => combinedStatusCounts[key] = (combinedStatusCounts[key] ?? 0) + value);
      walkInStatusData.forEach((key, value) => combinedStatusCounts[key] = (combinedStatusCounts[key] ?? 0) + value);

      final combinedServiceCountsRaw = <String, int>{};
      scheduledServiceDataRaw.forEach((key, value) => combinedServiceCountsRaw[key] = (combinedServiceCountsRaw[key] ?? 0) + value);
      walkInServiceDataRaw.forEach((key, value) => combinedServiceCountsRaw[key] = (combinedServiceCountsRaw[key] ?? 0) + value);

      return {
        // Scheduled Data
        'scheduledMonthlyCounts': scheduledMonthlyData['monthlyCounts'],
        'scheduledStatusCounts': scheduledStatusData,
        'scheduledServiceCounts': _getTopServices(scheduledServiceDataRaw),

        // Walk-in Data
        'walkInMonthlyCounts': walkInMonthlyData['monthlyCounts'],
        'walkInStatusCounts': walkInStatusData,
        'walkInServiceCounts': _getTopServices(walkInServiceDataRaw),
        
        // Summary Data
        'totalAppointments': allAppointments.length, // This is just scheduled
        'totalWalkIns': walkInQueueItems.length,
        'totalThisMonth': totalScheduledThisMonth + totalWalkInThisMonth,
        'scheduledGrowth': scheduledGrowth,

        // Combined Data
        'combinedStatusCounts': combinedStatusCounts,
        'combinedServiceCounts': _getTopServices(combinedServiceCountsRaw),
      };
    } catch (e) {
      print('Error fetching trends data: $e');
      throw Exception('Failed to fetch trends data: $e');
    }
  }

  Map<String, dynamic> _calculateMonthlyTrendsForAppointments(List<Appointment> appointments) {
    return _calculateMonthlyTrends(appointments.map((e) => e.date).toList());
  }

  Map<String, dynamic> _calculateMonthlyTrendsForQueueItems(List<ActivePatientQueueItem> queueItems) {
    return _calculateMonthlyTrends(queueItems.map((e) => e.arrivalTime).toList());
  }

  Map<String, dynamic> _calculateMonthlyTrends(List<DateTime> dates) {
    if (dates.isEmpty) {
      return {'monthlyCounts': <String, int>{}, 'totalThisMonth': 0, 'totalLastMonth': 0};
    }

    final now = DateTime.now();
    final monthlyCounts = <String, int>{};
    int totalThisMonth = 0;
    int totalLastMonth = 0;
    
    final lastSixMonths = List.generate(6, (index) => DateTime(now.year, now.month - index, 1));

    for (var date in lastSixMonths) {
      final monthKey = DateFormat('MMM yyyy').format(date);
      monthlyCounts[monthKey] = 0;
    }

    for (final date in dates) {
      final monthKey = DateFormat('MMM yyyy').format(date);
      if (monthlyCounts.containsKey(monthKey)) {
        monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
      }

      if (date.year == now.year && date.month == now.month) {
        totalThisMonth++;
      }
      if (date.year == now.year && date.month == now.month - 1) {
        totalLastMonth++;
      } else if (now.month == 1 && date.year == now.year - 1 && date.month == 12) {
        totalLastMonth++;
      }
    }
    
    return {
      'monthlyCounts': Map.fromEntries(monthlyCounts.entries.toList().reversed),
      'totalThisMonth': totalThisMonth,
      'totalLastMonth': totalLastMonth,
    };
  }

  Map<String, int> _calculateStatusDistributionForAppointments(List<Appointment> appointments) {
    if (appointments.isEmpty) return {};
    final statusCounts = <String, int>{};
    for (final appointment in appointments) {
      final status = appointment.status;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts;
  }

  Map<String, int> _calculateStatusDistributionForQueueItems(List<ActivePatientQueueItem> queueItems) {
    if (queueItems.isEmpty) return {};
    final statusCounts = <String, int>{};
    for (final item in queueItems) {
      final status = item.status;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts;
  }
  
  double _calculateGrowth(int currentMonth, int lastMonth) {
    if (lastMonth == 0) {
      return currentMonth > 0 ? 100.0 : 0.0;
    }
    return ((currentMonth - lastMonth) / lastMonth) * 100;
  }

  Map<String, int> _calculateServiceDistribution(List<List<Map<String, dynamic>>?> servicesList) {
    if (servicesList.isEmpty) return {};
    final serviceCounts = <String, int>{};

    for (final services in servicesList) {
      if (services != null) {
        for (final service in services) {
          final serviceName = service['name'] as String?;
          if (serviceName != null) {
            serviceCounts[serviceName] = (serviceCounts[serviceName] ?? 0) + 1;
          }
        }
      }
    }
    
    if (serviceCounts.length > 5) {
      final sortedEntries = serviceCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = Map.fromEntries(sortedEntries.take(5));
      final otherCount = sortedEntries.skip(5).fold(0, (sum, e) => sum + e.value);
      if (otherCount > 0) {
        top5['Other'] = otherCount;
      }
      return top5;
    }
    return serviceCounts;
  }

  Map<String, int> _getTopServices(Map<String, int> serviceCounts) {
    if (serviceCounts.length > 5) {
      final sortedEntries = serviceCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = Map.fromEntries(sortedEntries.take(5));
      final otherCount = sortedEntries.skip(5).fold(0, (sum, e) => sum + e.value);
      if (otherCount > 0) {
        top5['Other'] = otherCount;
      }
      return top5;
    }
    return serviceCounts;
  }

  Map<String, int> _calculateServiceDistributionForAppointments(List<Appointment> appointments) {
    final servicesList = appointments.map((a) => a.selectedServices).toList();
    return _calculateServiceDistribution(servicesList);
  }

  Map<String, int> _calculateServiceDistributionForQueueItems(List<ActivePatientQueueItem> queueItems) {
    final servicesList = queueItems.map((q) => q.selectedServices).toList();
    return _calculateServiceDistribution(servicesList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Patient Visit Trends'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _trendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error.toString()}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No trend data available.'));
          }

          final data = snapshot.data!;
          final totalThisMonth = data['totalThisMonth'];
          final totalScheduled = data['totalAppointments'];
          final totalWalkIns = data['totalWalkIns'];
          final growth = data['scheduledGrowth'];

          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCards(
                      totalThisMonth, totalScheduled, totalWalkIns, growth),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildChartCard(
                          'Monthly Scheduled',
                           _buildBarChart(data['scheduledMonthlyCounts'] ?? {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildChartCard(
                          'Monthly Walk-ins',
                          _buildBarChart(data['walkInMonthlyCounts'] ?? {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Expanded(
                        child: _buildChartCard(
                          'Status Distribution',
                           _buildPieChart(data['combinedStatusCounts'] ?? {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                       Expanded(
                        child: _buildChartCard(
                          'Top Services',
                          _buildPieChart(data['combinedServiceCounts'] ?? {}),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(
      int thisMonth, int totalScheduled, int totalWalkIns, double growth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryCard('This Month', thisMonth.toString(), 'Total Visits',
            Icons.calendar_today, Colors.blue),
        _buildSummaryCard('Scheduled', totalScheduled.toString(),
            'Total Appointments', Icons.event, Colors.purple),
        _buildSummaryCard('Walk-Ins', totalWalkIns.toString(), 'Total Visits',
            Icons.directions_walk, Colors.orange),
        _buildSummaryCard('Growth', '${growth.toStringAsFixed(1)}%',
            'Scheduled (MoM)', Icons.trending_up, growth >= 0 ? Colors.green : Colors.red),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Icon(icon, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> monthlyData) {
    if (monthlyData.isEmpty || monthlyData.values.every((v) => v == 0)) {
      return const Center(
          child: Text("Not enough data for monthly trends yet."));
    }

    final barGroups = monthlyData.entries.map((entry) {
      final month = entry.key;
      final count = entry.value;
      final index = monthlyData.keys.toList().indexOf(month);

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: primaryColor,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          )
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < monthlyData.keys.length) {
                  final month =
                      monthlyData.keys.elementAt(index).split(' ')[0];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(month, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final positiveValues = monthlyData.values.where((v) => v > 0);
                if (positiveValues.isEmpty) {
                  if (value == 0) return const Text('0');
                  return const Text('');
                }
                
                final maxValue = positiveValues.reduce(max);
                if (value > 0 && value % (max(1, (maxValue / 5).ceil())) == 0) {
                  return Text(value.toInt().toString());
                }
                
                if (value == 0) {
                  return const Text('0');
                }
                return const Text('');
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
          },
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(
          show: false,
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> statusData) {
    if (statusData.isEmpty) {
      return const Center(child: Text("No data available."));
    }

    final total = statusData.values.reduce((a, b) => a + b);
    final List<PieChartSectionData> sections = [];
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.brown
    ];
    int colorIndex = 0;

    statusData.forEach((status, count) {
      final percentage = total > 0 ? (count / total) * 100 : 0.0;
      sections.add(PieChartSectionData(
        color: colors[colorIndex % colors.length],
        value: count.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
      colorIndex++;
    });

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ListView(
            children: statusData.keys.map((status) {
              final index = statusData.keys.toList().indexOf(status);
              return _buildLegendItem(status, colors[index % colors.length]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Text(name),
        ],
      ),
    );
  }
}