import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  _BackupScreenState createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isAutoBackupEnabled = false;
  String _selectedBackupFrequency = 'Daily';
  final List<String> _backupFrequencies = ['Daily', 'Weekly', 'Monthly'];
  bool _isBackingUp = false;
  bool _isRestoring = false;
  Timer? _backupTimer;
  String? _lastBackupDate;
  String? _backupLocation;

  // Dummy backup history data
  final List<Map<String, String>> _backupHistory = [
    {
      'date': '2024-03-15 14:30',
      'size': '256 MB',
      'status': 'Success',
      'type': 'Manual',
    },
    {
      'date': '2024-03-14 14:30',
      'size': '255 MB',
      'status': 'Success',
      'type': 'Auto',
    },
    {
      'date': '2024-03-13 14:30',
      'size': '254 MB',
      'status': 'Failed',
      'type': 'Auto',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeBackupSettings();
  }

  Future<void> _initializeBackupSettings() async {
    // BACKUP LOCATION
    _backupLocation =
        (await getApplicationDocumentsDirectory()).path + '/backups';
    _lastBackupDate =
        _backupHistory.isNotEmpty ? _backupHistory.first['date'] : null;
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
  }

  Future<void> _createBackup(BuildContext context) async {
    if (_isBackingUp) return;

    setState(() {
      _isBackingUp = true;
    });

    try {
      // Simulate backup process
      await Future.delayed(const Duration(seconds: 2));

      final now = DateTime.now();
      final backupEntry = {
        'date': DateFormat('yyyy-MM-dd HH:mm').format(now),
        'size': '${250 + _backupHistory.length} MB',
        'status': 'Success',
        'type': 'Manual',
      };

      setState(() {
        _backupHistory.insert(0, backupEntry);
        _lastBackupDate = backupEntry['date'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Backup created successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create backup: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isBackingUp = false;
      });
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    if (_isRestoring) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      // Simulate restore process
      await Future.delayed(const Duration(seconds: 3));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('System restored successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore system: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      // Simulate export process
      await Future.delayed(const Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Backup exported successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export backup: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _toggleAutoBackup(bool value) {
    setState(() {
      _isAutoBackupEnabled = value;
      if (value) {
        _scheduleAutoBackup();
      } else {
        _backupTimer?.cancel();
      }
    });
  }

  void _scheduleAutoBackup() {
    _backupTimer?.cancel();

    Duration interval;
    switch (_selectedBackupFrequency) {
      case 'Daily':
        interval = const Duration(days: 1);
        break;
      case 'Weekly':
        interval = const Duration(days: 7);
        break;
      case 'Monthly':
        interval = const Duration(days: 30);
        break;
      default:
        interval = const Duration(days: 1);
    }

    _backupTimer = Timer.periodic(interval, (timer) {
      _createBackup(context);
    });
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
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'System Backup',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Manage your system backups and restoration points',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionCard(
                      'Backup Now',
                      Icons.backup,
                      Colors.blue[700]!,
                      _isBackingUp ? null : () => _createBackup(context),
                      isLoading: _isBackingUp,
                    ),
                    _buildActionCard(
                      'Restore',
                      Icons.restore,
                      Colors.orange[700]!,
                      _isRestoring ? null : () => _restoreBackup(context),
                      isLoading: _isRestoring,
                    ),
                    _buildActionCard(
                      'Export',
                      Icons.upload_file,
                      Colors.green[700]!,
                      () => _exportBackup(context),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto Backup',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Automatically backup your system',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isAutoBackupEnabled,
                            onChanged: _toggleAutoBackup,
                            activeColor: Colors.teal[700],
                          ),
                        ],
                      ),
                      if (_isAutoBackupEnabled) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Backup Frequency',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedBackupFrequency,
                          items: _backupFrequencies.map((frequency) {
                            return DropdownMenuItem(
                              value: frequency,
                              child: Text(frequency),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBackupFrequency = value!;
                              _scheduleAutoBackup();
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_backupLocation != null) ...[
                        const Text(
                          'Backup Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.folder, color: Colors.teal[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _backupLocation!,
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  // Implement copy to clipboard
                                },
                                tooltip: 'Copy path',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Colors.teal[700]),
                              const SizedBox(width: 12),
                              Text(
                                'Backup History',
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
                            icon: const Icon(Icons.launch, size: 18),
                            label: const Text('View Full History'),
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
                            headingRowColor:
                                MaterialStateProperty.all(Colors.grey[50]),
                            columnSpacing: 24,
                            horizontalMargin: 24,
                            columns: [
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
                                  'Size',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Type',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Actions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                            ],
                            rows: _backupHistory.map((backup) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(backup['date']!)),
                                  DataCell(Text(backup['size']!)),
                                  DataCell(Text(backup['type']!)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          backup['status'] == 'Success'
                                              ? Icons.check_circle
                                              : Icons.error,
                                          color: backup['status'] == 'Success'
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          backup['status']!,
                                          style: TextStyle(
                                            color: backup['status'] == 'Success'
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.restore,
                                              color: Colors.teal[700]),
                                          onPressed: () =>
                                              _restoreBackup(context),
                                          tooltip: 'Restore',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.download,
                                              color: Colors.teal[700]),
                                          onPressed: () =>
                                              _exportBackup(context),
                                          tooltip: 'Download',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap, {
    bool isLoading = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
