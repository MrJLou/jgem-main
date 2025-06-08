import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';

class PatientAnalyticsScreen extends StatefulWidget {
  const PatientAnalyticsScreen({super.key});

  @override
  State<PatientAnalyticsScreen> createState() => _PatientAnalyticsScreenState();
}

class _PatientAnalyticsScreenState extends State<PatientAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.teal[50]!, Colors.white],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Analytics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Desktop-friendly view of patient statistics and trends.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal[800],
            unselectedLabelColor: Colors.grey[700],
            indicatorColor: Colors.teal,
            tabs: const [
              Tab(icon: Icon(Icons.trending_up), text: 'Patient Trends'),
              Tab(icon: Icon(Icons.pie_chart_outline), text: 'Demographics'),
              Tab(icon: Icon(Icons.assessment_outlined), text: 'Treatment Analytics'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPatientTrendsTab(),
                _buildDemographicsTab(),
                _buildTreatmentAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A generic scrollable tab layout
  Widget _buildTabLayout({required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // Tab for Patient Trends
  Widget _buildPatientTrendsTab() {
    return _buildTabLayout(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildChartCard(
                title: 'Patient Visit Trends',
                icon: Icons.show_chart,
                chart: _buildLineChartPlaceholder(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildSummaryCard(
                title: 'Visits Summary',
                icon: Icons.summarize_outlined,
                metrics: {
                  'Total Visits (YTD)': '1,284',
                  'Avg. Visits / Month': '107',
                  'Busiest Day': 'Mondays',
                  'Peak Hour': '10 AM',
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDataTableCard(
          title: 'Visit Purpose Trends',
          icon: Icons.help_outline,
          columns: ['Purpose', 'This Month', 'Last Month', 'Change'],
          rows: [
            DataRow(cells: [
              const DataCell(Text('Routine Check-up')),
              const DataCell(Text('150')),
              const DataCell(Text('120')),
              const DataCell(Text('+25%', style: TextStyle(color: Colors.green))),
            ]),
            DataRow(cells: [
              const DataCell(Text('Follow-up')),
              const DataCell(Text('98')),
              const DataCell(Text('110')),
              const DataCell(Text('-10.9%', style: TextStyle(color: Colors.red))),
            ]),
            DataRow(cells: [
              const DataCell(Text('Lab Test Request')),
              const DataCell(Text('210')),
              const DataCell(Text('180')),
              const DataCell(Text('+16.7%', style: TextStyle(color: Colors.green))),
            ]),
          ],
        ),
      ],
    );
  }

  // Tab for Demographics
  Widget _buildDemographicsTab() {
    return _buildTabLayout(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildChartCard(
                title: 'Gender Distribution',
                icon: Icons.wc,
                chart: _buildPieChartPlaceholder(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildSummaryCard(
                title: 'Demographics Summary',
                icon: Icons.person_search_outlined,
                metrics: {
                  'Total Unique Patients': '4,521',
                  'Average Age': '42.5',
                  'Age Range': '2 - 94',
                  'Most Common Gender': 'Female (58%)'
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDataTableCard(
          title: 'Age Group Distribution',
          icon: Icons.groups_outlined,
          columns: ['Age Group', 'Patient Count', 'Percentage'],
          rows: [
            DataRow(cells: [
              const DataCell(Text('0-18 (Pediatric)')),
              const DataCell(Text('542')),
              const DataCell(Text('12.0%')),
            ]),
            DataRow(cells: [
              const DataCell(Text('19-45 (Adult)')),
              const DataCell(Text('2,170')),
              const DataCell(Text('48.0%')),
            ]),
            DataRow(cells: [
              const DataCell(Text('46-65 (Middle-Aged)')),
              const DataCell(Text('1,356')),
              const DataCell(Text('30.0%')),
            ]),
            DataRow(cells: [
              const DataCell(Text('65+ (Senior)')),
              const DataCell(Text('453')),
              const DataCell(Text('10.0%')),
            ]),
          ],
        ),
      ],
    );
  }

  // Tab for Treatment Analytics
  Widget _buildTreatmentAnalyticsTab() {
    return _buildTabLayout(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildChartCard(
                title: 'Treatment Outcomes',
                icon: Icons.verified_user_outlined,
                chart: _buildBarChartPlaceholder(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildSummaryCard(
                title: 'Treatment Summary',
                icon: Icons.healing_outlined,
                metrics: {
                  'Overall Success Rate': '92.3%',
                  'Avg. Treatment Duration': '14 days',
                  'Most Common Treatment': 'Physical Therapy',
                  'Highest Success Rate': 'Vaccination (99.8%)'
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDataTableCard(
          title: 'Services Analytics',
          icon: Icons.medical_services_outlined,
          columns: ['Service', 'No. of Patients', 'Avg. Cost', 'Success Rate'],
          rows: [
            DataRow(cells: [
              const DataCell(Text('General Consultation')),
              const DataCell(Text('850')),
              const DataCell(Text('\$75.00')),
              const DataCell(Text('N/A')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Physical Therapy')),
              const DataCell(Text('230')),
              const DataCell(Text('\$120.00')),
              const DataCell(Text('95%')),
            ]),
            DataRow(cells: [
              const DataCell(Text('X-Ray')),
              const DataCell(Text('410')),
              const DataCell(Text('\$250.00')),
              const DataCell(Text('N/A')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Minor Surgery')),
              const DataCell(Text('85')),
              const DataCell(Text('\$1,500.00')),
              const DataCell(Text('98%')),
            ]),
          ],
        ),
      ],
    );
  }

  // Generic card for charts
  Widget _buildChartCard({required String title, required IconData icon, required Widget chart}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal[700]),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }

  // Generic card for summary metrics
  Widget _buildSummaryCard({required String title, required IconData icon, required Map<String, String> metrics}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal[700]),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...metrics.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: TextStyle(color: Colors.grey[600])),
                      Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // Generic card for data tables
  Widget _buildDataTableCard({required String title, required IconData icon, required List<String> columns, required List<DataRow> rows}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Icon(icon, color: Colors.teal[700]),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.teal[50]),
                columns: columns.map((col) => DataColumn(label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder Widgets
  Widget _buildPieChartPlaceholder() {
    final Map<String, double> dataMap = {"Female": 58, "Male": 40, "Other": 2};
    return SizedBox(
      height: 250,
      child: PieChart(
        dataMap: dataMap,
        chartType: ChartType.ring,
        ringStrokeWidth: 40,
        centerText: "Gender",
        legendOptions: const LegendOptions(showLegendsInRow: true, legendPosition: LegendPosition.bottom),
        chartValuesOptions: const ChartValuesOptions(showChartValuesInPercentage: true),
      ),
    );
  }

  Widget _buildLineChartPlaceholder() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Icon(Icons.show_chart, size: 60, color: Colors.grey.shade300)),
    );
  }

  Widget _buildBarChartPlaceholder() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Icon(Icons.bar_chart, size: 60, color: Colors.grey.shade300)),
    );
  }
}
