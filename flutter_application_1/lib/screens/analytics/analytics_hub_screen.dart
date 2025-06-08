import 'package:flutter/material.dart';
import 'patient_trends_screen.dart';
import 'demographics_screen.dart';
import 'treatment_analysis_screen.dart';

class AnalyticsHubScreen extends StatefulWidget {
  const AnalyticsHubScreen({super.key});

  @override
  _AnalyticsHubScreenState createState() => _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends State<AnalyticsHubScreen>
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Analytics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Trends', icon: Icon(Icons.trending_up)),
            Tab(text: 'Demographics', icon: Icon(Icons.pie_chart)),
            Tab(text: 'Treatments', icon: Icon(Icons.medical_services)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[50]!, Colors.white],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: const [
            PatientTrendsScreen(),
            DemographicsScreen(),
            TreatmentAnalysisScreen(),
          ],
        ),
      ),
    );
  }
} 