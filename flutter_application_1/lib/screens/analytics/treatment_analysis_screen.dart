import 'package:flutter/material.dart';

class TreatmentAnalysisScreen extends StatefulWidget {
  const TreatmentAnalysisScreen({super.key});

  @override
  _TreatmentAnalysisScreenState createState() => _TreatmentAnalysisScreenState();
}

class _TreatmentAnalysisScreenState extends State<TreatmentAnalysisScreen> {
  final Color primaryColor = Colors.teal[700]!;
  final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  final List<double> successRates = [82.5, 84.0, 83.0, 86.5, 85.0, 87.5];

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 20),
              _buildSuccessRateCard(),
              const SizedBox(height: 20),
              _buildTreatmentTypeCard(),
              const SizedBox(height: 20),
              _buildOutcomeDetailsCard(),
            ],
          ),
        ),
      );
  }

  Widget _buildSummaryCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSummaryCard(
          'Success Rate',
          '87.5%',
          Icons.check_circle,
          '+1.5% vs last month',
          Colors.green,
        ),
        _buildSummaryCard(
          'Avg. Duration',
          '14 days',
          Icons.timer,
          '-2 days vs last month',
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    String trend,
    Color trendColor,
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
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessRateCard() {
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
                Icon(Icons.trending_up, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Success Rate Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        months.length,
                        (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: Duration(milliseconds: 1000 + (index * 200)),
                              builder: (context, double value, child) {
                                return _buildSuccessBar(
                                  successRates[index],
                                  months[index],
                                  value,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: months
                        .map(
                          (month) => Expanded(
                            child: Text(
                              month,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBar(double value, String month, double animationValue) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${value.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180 * (value / 100) * animationValue,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.7),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentTypeCard() {
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
                Icon(Icons.medical_services, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Treatment Types',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTreatmentStat('Medication', 45, Colors.blue[400]!),
                _buildTreatmentStat('Therapy', 35, Colors.purple[400]!),
                _buildTreatmentStat('Surgery', 20, Colors.orange[400]!),
              ],
            ),
            const SizedBox(height: 20),
            _buildTreatmentLegend(),
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
                color: color.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${value.toInt()}%',
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
        Text(
          treatment,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentLegend() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Medication', Colors.blue[400]!, '45%'),
          _buildLegendItem('Therapy', Colors.purple[400]!, '35%'),
          _buildLegendItem('Surgery', Colors.orange[400]!, '20%'),
        ],
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
        Text(
          '$label: $value',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOutcomeDetailsCard() {
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
                Icon(Icons.assessment, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Outcome Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildOutcomeBar('Complete Recovery', 65, Colors.green[400]!),
            const SizedBox(height: 15),
            _buildOutcomeBar('Significant Improvement', 25, Colors.blue[400]!),
            const SizedBox(height: 15),
            _buildOutcomeBar('Moderate Improvement', 8, Colors.orange[400]!),
            const SizedBox(height: 15),
            _buildOutcomeBar('Limited Improvement', 2, Colors.red[400]!),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeBar(String outcome, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              outcome,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: percentage / 100),
          duration: const Duration(milliseconds: 1000),
          builder: (context, double value, child) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.2),
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