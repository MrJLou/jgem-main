import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/reports/financial_report_screen.dart';
import 'package:flutter_application_1/screens/reports/laboratory_reports_screen.dart';
import 'package:flutter_application_1/screens/reports/medical_records_screen.dart';
import 'package:flutter_application_1/screens/reports/user_logs_report_tab.dart';

class ReportHubScreen extends StatefulWidget {
  const ReportHubScreen({super.key});

  @override
  State<ReportHubScreen> createState() => _ReportHubScreenState();
}

class _ReportHubScreenState extends State<ReportHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Reports Hub',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.folder_shared_outlined), text: 'Patient Records'),
            Tab(icon: Icon(Icons.science_outlined), text: 'Lab Reports'),
            Tab(icon: Icon(Icons.monetization_on_outlined), text: 'Financial'),
            Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: 'User Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MedicalRecordsScreen(),
          LaboratoryReportsScreen(),
          FinancialReportScreen(),
          UserLogsReportTab(),
        ],
      ),
    );
  }
}
