import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/database_sync_client.dart';
import 'package:flutter_application_1/utils/error_dialog_utils.dart';
import 'dart:async';

class UserActivityLogScreen extends StatefulWidget {
  const UserActivityLogScreen({super.key});

  @override
  UserActivityLogScreenState createState() => UserActivityLogScreenState();
}

class UserActivityLogScreenState extends State<UserActivityLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
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
        ErrorDialogUtils.showErrorDialog(
          context: context,
          title: 'Error Loading Logs',
          message: 'Failed to load activity logs. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(String timestamp) {
    try {
      // The timestamp from the database is already UTC+8
      final dateTime = DateTime.parse(timestamp);
      // Format directly, as it's already in the desired timezone
      final date =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      return '$date $time';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting timestamp: $timestamp, Error: $e');
      }
      return 'Invalid Date'; // Fallback for parsing errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Activity Logs'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No activity logs found.'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6), // Added more horizontal margin
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(
                          _getIconForAction(
                              log['actionDescription'] as String? ?? ''),
                          color: Colors.teal[600],
                          size: 28, // Slightly larger icon
                        ),
                        title: Text(
                            'User: ${log['userId']} - Action: ${log['actionDescription']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                              _formatDateTime(
                                  log['timestamp'] as String? ?? ''),
                              style: TextStyle(color: Colors.grey[700])),
                        ),
                        trailing: Text(
                          'PHT',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                        isThreeLine:
                            true, // Ensure enough space if details are long
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getIconForAction(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('login')) {
      return Icons.login_outlined;
    } else if (lowerAction.contains('logout')) {
      return Icons.logout_outlined;
    } else if (lowerAction.contains('view')) {
      return Icons.visibility_outlined;
    } else if (lowerAction.contains('update')) {
      return Icons.edit_outlined;
    } else if (lowerAction.contains('delete')) {
      return Icons.delete_outline_outlined;
    } else if (lowerAction.contains('create')) {
      return Icons.add_circle_outline;
    }
    return Icons.history_toggle_off_outlined;
  }
} 