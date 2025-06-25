import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_sync_service.dart';
import '../services/lan_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnhancedLanConnectionScreen extends StatefulWidget {
  const EnhancedLanConnectionScreen({super.key});

  @override
  State<EnhancedLanConnectionScreen> createState() =>
      _EnhancedLanConnectionScreenState();
}

class _EnhancedLanConnectionScreenState
    extends State<EnhancedLanConnectionScreen> {
  bool _isLoading = true;
  bool _serverEnabled = false;
  bool _sessionServerEnabled = false;
  String _accessCode = '';
  String _sessionToken = '';
  List<String> _ipAddresses = [];
  int _port = 8080;
  final int _sessionPort = 8081;
  int _syncInterval = 5;
  int _pendingChanges = 0;
  List<UserSession> _activeSessions = [];

  late StreamSubscription _sessionUpdatesSubscription;

  final _syncIntervalController = TextEditingController();
  final _portController = TextEditingController();
  final _sessionPortController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConnectionInfo();
    _setupSessionUpdates();
  }

  @override
  void dispose() {
    _syncIntervalController.dispose();
    _portController.dispose();
    _sessionPortController.dispose();
    _sessionUpdatesSubscription.cancel();
    super.dispose();
  }

  void _setupSessionUpdates() {
    _sessionUpdatesSubscription =
        LanSessionService.sessionUpdates.listen((update) {
      if (mounted) {
        _loadActiveSessions();
        setState(() {});
      }
    });
  }

  Future<void> _loadConnectionInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final info = await LanSyncService.getConnectionInfo();
      setState(() {
        _serverEnabled = info['lanServerEnabled'] ?? false;
        _accessCode = info['accessCode'] ?? '';
        _ipAddresses = List<String>.from(info['ipAddresses'] ?? []);
        _port = info['port'] ?? 8080;
        _sessionServerEnabled = LanSessionService.isServerRunning;
        _sessionToken = LanSessionService.getServerToken() ?? '';

        _portController.text = _port.toString();
        _sessionPortController.text = _sessionPort.toString();
      });

      // Get pending changes count
      final pendingChanges = await LanSyncService.getPendingChanges();
      setState(() {
        _pendingChanges = pendingChanges;
      });

      // Get sync interval
      final prefs = await SharedPreferences.getInstance();
      _syncInterval = prefs.getInt('sync_interval_minutes') ?? 5;
      _syncIntervalController.text = _syncInterval.toString();

      // Load active sessions
      await _loadActiveSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading connection info: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActiveSessions() async {
    try {
      final sessions = LanSessionService.activeSessions.values.toList();
      setState(() {
        _activeSessions = sessions;
      });
    } catch (e) {
      debugPrint('Error loading active sessions: $e');
    }
  }

  Future<void> _toggleServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_serverEnabled) {
        await LanSyncService.stopLanServer();
      } else {
        await LanSyncService.startLanServer(port: _port);
      }

      await _loadConnectionInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling server: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSessionServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_sessionServerEnabled) {
        await LanSessionService.stopSessionServer();
      } else {
        await LanSessionService.startSessionServer(port: _sessionPort);
      }

      await _loadConnectionInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling session server: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceLogoutUser(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Logout'),
        content: const Text('Are you sure you want to force logout this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Force Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await LanSessionService.endUserSession(sessionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User logged out successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out user: $e')),
          );
        }
      }
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced LAN Connection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadConnectionInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Data Server Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Data Server Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Switch(
                                value: _serverEnabled,
                                onChanged: (value) => _toggleServer(),
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_serverEnabled) ...[
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: Colors.green, size: 12),
                                const SizedBox(width: 8),
                                Text('Running on port $_port'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Access Code: $_accessCode'),
                            const SizedBox(height: 8),
                            Text('Pending Changes: $_pendingChanges'),
                          ] else
                            const Row(
                              children: [
                                Icon(Icons.circle, color: Colors.red, size: 12),
                                SizedBox(width: 8),
                                Text('Stopped'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Session Server Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Session Server Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Switch(
                                value: _sessionServerEnabled,
                                onChanged: (value) => _toggleSessionServer(),
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_sessionServerEnabled) ...[
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: Colors.green, size: 12),
                                const SizedBox(width: 8),
                                Text('Running on port $_sessionPort'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Session Token: $_sessionToken'),
                            const SizedBox(height: 8),
                            Text('Active Sessions: ${_activeSessions.length}'),
                          ] else
                            const Row(
                              children: [
                                Icon(Icons.circle, color: Colors.red, size: 12),
                                SizedBox(width: 8),
                                Text('Stopped'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Active Users Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'Active Users',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_activeSessions.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_activeSessions.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text(
                                  'No active users',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _activeSessions.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final session = _activeSessions[index];
                                final duration = DateTime.now()
                                    .difference(session.loginTime);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(
                                      session.username
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    session.username,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Device: ${session.deviceName}'),
                                      Text('Role: ${session.accessLevel}'),
                                      Text(
                                          'Duration: ${_formatDuration(duration)}'),
                                      if (session.ipAddress != null)
                                        Text('IP: ${session.ipAddress}'),
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'logout',
                                        child: Row(
                                          children: [
                                            Icon(Icons.logout,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Force Logout'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'logout') {
                                        _forceLogoutUser(session.sessionId);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Connection Information Card
                  if (_serverEnabled || _sessionServerEnabled) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connection Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_ipAddresses.isNotEmpty) ...[
                              const Text(
                                'Server IP Addresses:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _ipAddresses.length,
                                itemBuilder: (context, index) {
                                  final ip = _ipAddresses[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(
                                        '$ip:$_port (Data) | $ip:$_sessionPort (Session)'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () => _copyToClipboard(
                                        '$ip:$_port',
                                        'Connection info copied to clipboard',
                                      ),
                                      tooltip: 'Copy connection info',
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
