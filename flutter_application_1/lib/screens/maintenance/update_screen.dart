import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'modify_patient_details_screen.dart';
import 'modify_patient_status_screen.dart';
import 'modify_services_screen.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  _UpdateScreenState createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _isChecking = false;
  bool _isUpdating = false;
  String _currentVersion = '1.0.0';
  String _latestVersion = '1.0.1';
  List<Map<String, String>> _updateHistory = [
    {
      'version': '1.0.0',
      'date': '2024-03-01',
      'description': 'Initial release',
      'size': '25.4 MB'
    },
    {
      'version': '0.9.0',
      'date': '2024-02-15',
      'description': 'Beta release with core features',
      'size': '24.8 MB'
    },
    {
      'version': '0.8.0',
      'date': '2024-02-01',
      'description': 'Alpha release for testing',
      'size': '23.5 MB'
    },
  ];

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    // Simulate checking for updates
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isChecking = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('System is up to date!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _startUpdate() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    // Simulate update process
    await Future.delayed(Duration(seconds: 3));

    setState(() {
      _isUpdating = false;
      _currentVersion = _latestVersion;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Update completed successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.teal[700],
              padding: EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  SizedBox(height: 20),
                  Text(
                    'System Updates',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Keep your system up to date with the latest features and improvements',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(0, -30),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Version',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _currentVersion,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _isChecking ? null : _checkForUpdates,
                              icon: _isChecking
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.refresh),
                              label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_currentVersion != _latestVersion) ...[
                          SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue[200]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.new_releases,
                                      color: Colors.blue[700],
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'New Update Available!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Version $_latestVersion is now available. Would you like to update?',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isUpdating ? null : _startUpdate,
                                      icon: _isUpdating
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : Icon(Icons.system_update),
                                      label:
                                          Text(_isUpdating ? 'Updating...' : 'Update Now'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Colors.teal[700]),
                              SizedBox(width: 12),
                              Text(
                                'Update History',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[900],
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              // Show full history
                            },
                            icon: Icon(Icons.launch, size: 18),
                            label: Text('View Full History'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.teal[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 48,
                          ),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                            columnSpacing: 24,
                            horizontalMargin: 24,
                            columns: [
                              DataColumn(
                                label: Text(
                                  'Version',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Description',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Size',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                            ],
                            rows: _updateHistory.map((update) {
                              bool isCurrentVersion = update['version'] == _currentVersion;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isCurrentVersion)
                                          Padding(
                                            padding: EdgeInsets.only(right: 8),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.teal[700],
                                              size: 16,
                                            ),
                                          ),
                                        Text(
                                          update['version']!,
                                          style: TextStyle(
                                            fontWeight: isCurrentVersion ? FontWeight.bold : FontWeight.normal,
                                            color: isCurrentVersion ? Colors.teal[700] : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(update['date']!)),
                                  DataCell(
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: 300,
                                      ),
                                      child: Text(
                                        update['description']!,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(update['size']!)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}