import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/api_service.dart';
import 'models/clinic_service.dart';

class DebugServiceAnalyticsTest extends StatefulWidget {
  const DebugServiceAnalyticsTest({super.key});

  @override
  State<DebugServiceAnalyticsTest> createState() => _DebugServiceAnalyticsTestState();
}

class _DebugServiceAnalyticsTestState extends State<DebugServiceAnalyticsTest> {
  List<ClinicService> _services = [];
  String? _selectedServiceId;
  String _debugOutput = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await ApiService.getClinicServices();
      setState(() {
        _services = services;
      });
    } catch (e) {
      setState(() {
        _debugOutput = 'Error loading services: $e';
      });
    }
  }

  Future<void> _testServiceAnalytics(String serviceId) async {
    setState(() {
      _isLoading = true;
      _debugOutput = 'Testing analytics for service ID: $serviceId\n\n';
    });

    try {
      // Test times availed
      final timesAvailed = await ApiService.getServiceTimesAvailed(serviceId);
      _appendDebug('Times Availed: $timesAvailed');

      // Test usage trend
      final usageTrend = await ApiService.getServiceUsageTrend(serviceId);
      _appendDebug('Usage Trend Data: ${usageTrend.length} entries');
      for (final trend in usageTrend) {
        _appendDebug('  - ${trend['month']}: ${trend['count']} uses');
      }

      // Test recent patients
      final recentPatients = await ApiService.getRecentPatientsForService(serviceId);
      _appendDebug('\nRecent Patients: ${recentPatients.length} found');
      for (final patient in recentPatients) {
        _appendDebug('  - ${patient.fullName} (ID: ${patient.id})');
      }

      // Test total patients for service
      final totalPatients = await ApiService.getTotalPatientsForService(serviceId);
      _appendDebug('\nTotal Unique Patients: $totalPatients');

      // Test recent records
      final recentRecords = await ApiService.getRecentPatientRecordsForService(serviceId);
      _appendDebug('\nRecent Records: ${recentRecords.length} found');
      for (final record in recentRecords) {
        _appendDebug('  - ${record['fullName']} on ${record['recordDate']}');
      }

    } catch (e) {
      _appendDebug('\nERROR: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _appendDebug(String message) {
    setState(() {
      _debugOutput += '$message\n';
    });
    if (kDebugMode) {
      print('DEBUG SERVICE ANALYTICS: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Service Analytics'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service selection
            DropdownButtonFormField<String>(
              value: _selectedServiceId,
              decoration: const InputDecoration(
                labelText: 'Select Service to Test',
                border: OutlineInputBorder(),
              ),
              items: _services.map((service) {
                return DropdownMenuItem<String>(
                  value: service.id,
                  child: Text('${service.serviceName} (Count: ${service.selectionCount})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedServiceId = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Test button
            ElevatedButton.icon(
              onPressed: _selectedServiceId == null || _isLoading ? null : () {
                _testServiceAnalytics(_selectedServiceId!);
              },
              icon: _isLoading 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.bug_report),
              label: Text(_isLoading ? 'Testing...' : 'Test Analytics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Debug output
            const Text(
              'Debug Output:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugOutput.isEmpty ? 'Select a service and click "Test Analytics" to see debug information.' : _debugOutput,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
