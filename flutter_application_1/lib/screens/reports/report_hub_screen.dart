import 'package:flutter/material.dart';
import 'medical_records_screen.dart';
import 'drug_test_report_screen.dart';
import 'chemistry_test_report_screen.dart';
import 'ecg_report_screen.dart';
import 'clinical_microscopy_report_screen.dart';
import 'serology_test_report_screen.dart';
import 'hematology_report_screen.dart';
import 'xray_report_screen.dart';

class ReportHubScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 4,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Select a category to view reports',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _ReportCard(
                    icon: Icons.medical_services,
                    title: 'Medical Records and Information',
                    subtitle: 'View detailed medical records',
                   color: Colors.teal[700] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicalRecordsScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.science,
                    title: 'Patients per Drug Test',
                    subtitle: 'View drug test reports',
                   color: Colors.teal[600] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DrugTestReportScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.biotech,
                    title: 'Patients per Chemistry Test',
                    subtitle: 'View chemistry test reports',
                   color: Colors.teal[500] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChemistryTestReportScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.monitor_heart,
                    title: 'Patients per ECG',
                    subtitle: 'View ECG reports',
                   color: Colors.teal[400] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ECGReportScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.science,
                    title: 'Patients per Clinical Microscopy',
                    subtitle: 'View clinical microscopy reports',
                   color: Colors.teal[300] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClinicalMicroscopyReportScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.bloodtype,
                    title: 'Patients per Serology Testing',
                    subtitle: 'View serology test reports',
                   color: Colors.teal[200] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SerologyTestReportScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.bloodtype_outlined,
                    title: 'Patients per Hematology',
                    subtitle: 'View hematology reports',
                   color: Colors.teal[100] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HematologyReportScreen(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _ReportCard(
                    icon: Icons.image, // Replaced invalid icon
                    title: 'Patients per X-Ray',
                    subtitle: 'View X-Ray reports',
                    color: Colors.teal[50] ?? Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => XRayReportScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: color.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[900],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}