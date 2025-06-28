import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/logs/user_logs_print_preview_screen.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'dart:async';

class UserLogsReportTab extends StatefulWidget {
  const UserLogsReportTab({super.key});

  @override
  State<UserLogsReportTab> createState() => _UserLogsReportTabState();
}

class _UserLogsReportTabState extends State<UserLogsReportTab> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _setupSyncListener();
  }

  void _setupSyncListener() {
    _syncSubscription = DatabaseSyncClient.syncUpdates.listen((updateEvent) {
      if (!mounted) return;
      
      // Handle user activity log changes
      switch (updateEvent['type']) {
        case 'remote_change_applied':
        case 'database_change':
          final change = updateEvent['change'] as Map<String, dynamic>?;
          if (change != null && change['table'] == 'user_activity_log') {
            // Refresh logs when user activity changes
            _fetchLogs();
          }
          break;
        case 'ui_refresh_requested':
          // Periodic refresh
          if (DateTime.now().millisecondsSinceEpoch % 60000 < 2000) {
            _fetchLogs();
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper();
      _logs = await db.getUserActivityLogs();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching logs: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading activity logs')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPrintPreview() {
    if (_logs.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserLogsPrintPreviewScreen(logs: _logs),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to print.')),
      );
    }
  }

  String _formatDateTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final date =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return '$date $time';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No activity logs found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Icon(
                          _getIconForAction(
                              log['actionDescription'] as String? ?? ''),
                          color: Colors.teal,
                        ),
                        title: Text(
                            '${log['actionDescription']} by User: ${log['userId']}'),
                        subtitle: Text(
                            _formatDateTime(log[' timestamp '] as String? ?? '')),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPrintPreview,
        icon: const Icon(Icons.print_outlined),
        label: const Text('Print Preview', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
    );
  }

  IconData _getIconForAction(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('login')) return Icons.login;
    if (lowerAction.contains('logout')) return Icons.logout;
    if (lowerAction.contains('create')) return Icons.add;
    if (lowerAction.contains('update')) return Icons.edit;
    if (lowerAction.contains('delete')) return Icons.delete;
    if (lowerAction.contains('view')) return Icons.visibility;
    return Icons.history;
  }
} 