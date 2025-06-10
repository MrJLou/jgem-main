import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class DemographicsScreen extends StatefulWidget {
  const DemographicsScreen({super.key});

  @override
  DemographicsScreenState createState() => DemographicsScreenState();
}

class DemographicsScreenState extends State<DemographicsScreen> {
  Future<Map<String, dynamic>>? _demographicsFuture;

  @override
  void initState() {
    super.initState();
    _demographicsFuture = _fetchDemographicsData();
  }

  Future<Map<String, dynamic>> _fetchDemographicsData() async {
    try {
      final patients = await ApiService.getPatients();
      if (patients.isEmpty) {
        return {
          'totalPatients': 0,
          'genderDistribution': {'Male': 0, 'Female': 0, 'Other': 0},
          'ageDistribution': {
            '0-18': 0,
            '19-35': 0,
            '36-50': 0,
            '51-65': 0,
            '65+': 0,
          },
        };
      }

      final totalPatients = patients.length;

      final now = DateTime.now();

      final genderDistribution = {'Male': 0, 'Female': 0, 'Other': 0, 'Unknown': 0};
      for (final patient in patients) {
        final gender = patient.gender.toLowerCase();
        if (gender == 'male') {
          genderDistribution['Male'] = genderDistribution['Male']! + 1;
        } else if (gender == 'female') {
          genderDistribution['Female'] = genderDistribution['Female']! + 1;
        } else if (gender == 'other') {
          genderDistribution['Other'] = genderDistribution['Other']! + 1;
        } else {
          genderDistribution['Unknown'] = genderDistribution['Unknown']! + 1;
        }
      }

      final ageDistribution = {
        '0-18': 0,
        '19-35': 0,
        '36-50': 0,
        '51-65': 0,
        '65+': 0,
      };
      for (final patient in patients) {
        final birthDate = patient.birthDate;
        int age = now.year - birthDate.year;
        if (now.month < birthDate.month ||
            (now.month == birthDate.month && now.day < birthDate.day)) {
          age--;
        }
        
        if (age <= 18) {
          ageDistribution['0-18'] = ageDistribution['0-18']! + 1;
        } else if (age <= 35) {
          ageDistribution['19-35'] = ageDistribution['19-35']! + 1;
        } else if (age <= 50) {
          ageDistribution['36-50'] = ageDistribution['36-50']! + 1;
        } else if (age <= 65) {
          ageDistribution['51-65'] = ageDistribution['51-65']! + 1;
        } else {
          ageDistribution['65+'] = ageDistribution['65+']! + 1;
        }
            }

      return {
        'totalPatients': totalPatients,
        'genderDistribution': genderDistribution,
        'ageDistribution': ageDistribution,
      };
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching demographics: $e");
      }
      throw Exception("Failed to load demographic data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _demographicsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No data available.'));
        }

        final data = snapshot.data!;
        final totalPatients = data['totalPatients'] as int;
        final genderData = data['genderDistribution'] as Map<String, int>;
        final ageData = data['ageDistribution'] as Map<String, int>;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal[50]!, Colors.white],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummarySection(totalPatients, genderData),
                const SizedBox(height: 30),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildAgeDistributionCard(ageData, totalPatients),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildGenderDistributionCard(genderData),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(int totalPatients, Map<String, int> genderData) {
    final femaleCount = genderData['Female'] ?? 0;
    final maleCount = genderData['Male'] ?? 0;
    final totalGendered = femaleCount + maleCount;
    final femalePercent = totalGendered > 0 ? (femaleCount / totalGendered * 100).round() : 0;
    final malePercent = totalGendered > 0 ? (maleCount / totalGendered * 100).round() : 0;

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
                Icon(Icons.people_outline, color: Colors.teal[700]),
                const SizedBox(width: 10),
                Text(
                  'Patient Population Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                    'Total Patients',
                    Text(
                      NumberFormat.compact().format(totalPatients),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                    Icons.people),
                _buildStatCard(
                  'Female / Male',
                  Column(
                    children: [
                      Text(
                        '$femaleCount / $maleCount',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '($femalePercent% / $malePercent%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Icons.wc,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, Widget valueWidget, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.teal[700], size: 30),
          const SizedBox(height: 10),
          valueWidget,
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAgeDistributionCard(Map<String, int> ageData, int totalPatients) {
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
                Icon(Icons.cake, color: Colors.teal[700]),
                const SizedBox(width: 10),
                Text(
                  'Age Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...ageData.entries.map((entry) {
              final percentage = totalPatients > 0 ? (entry.value / totalPatients * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildAgeDistributionBar(entry.key, percentage),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeDistributionBar(String age, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                age,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(26),
                          borderRadius: BorderRadius.circular(12.5),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: 25,
                        width: constraints.maxWidth * (percentage / 100),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal[700]!, Colors.teal[500]!],
                          ),
                          borderRadius: BorderRadius.circular(12.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withAlpha(51),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderDistributionCard(Map<String, int> genderData) {
    final total = genderData.values.reduce((a, b) => a + b);
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
                Icon(Icons.wc, color: Colors.teal[700]),
                const SizedBox(width: 10),
                Text(
                  'Gender Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildGenderRow(
              icon: Icons.male,
              color: Colors.blue,
              gender: 'Male',
              count: genderData['Male'] ?? 0,
              percentage: total > 0 ? ((genderData['Male'] ?? 0) / total * 100) : 0,
            ),
            const SizedBox(height: 12),
            _buildGenderRow(
              icon: Icons.female,
              color: Colors.pink,
              gender: 'Female',
              count: genderData['Female'] ?? 0,
              percentage: total > 0 ? ((genderData['Female'] ?? 0) / total * 100) : 0,
            ),
             if ((genderData['Other'] ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _buildGenderRow(
                icon: Icons.transgender,
                color: Colors.purple,
                gender: 'Other',
                count: genderData['Other'] ?? 0,
                percentage: total > 0 ? ((genderData['Other'] ?? 0) / total * 100) : 0,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenderRow({
    required IconData icon,
    required Color color,
    required String gender,
    required int count,
    required double percentage,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$count Patients',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              )
            ],
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        )
      ],
    );
  }
} 