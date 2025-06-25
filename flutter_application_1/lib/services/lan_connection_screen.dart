import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_sync_service.dart';
import '../services/lan_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class LanConnectionScreen extends StatefulWidget {
  const LanConnectionScreen({super.key});

  @override
  State<LanConnectionScreen> createState() => _LanConnectionScreenState();
}

class _LanConnectionScreenState extends State<LanConnectionScreen> {
  bool _isLoading = true;
  bool _serverEnabled = false;
  bool _sessionServerEnabled = false;
  String _accessCode = '';
  List<String> _ipAddresses = [];
  int _port = 8080;
  final int _sessionPort = 8081;
  int _syncInterval = 5;
  int _pendingChanges = 0;
  List<String> _allowedNetworks = [];
  String _dbPath = '';
  List<UserSession> _activeSessions = [];
  Timer? _refreshTimer;
  StreamSubscription? _sessionUpdateSubscription;

  final _syncIntervalController = TextEditingController();
  final _portController = TextEditingController();
  final _sessionPortController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadConnectionInfo();
    // Initialize session management if LAN server is enabled
    _initializeSessionManagement();
  }

  Future<void> _initializeSessionManagement() async {
    try {
      // Check if session server should be running
      if (LanSessionService.isServerRunning) {
        await _startSessionManagement();
      }
    } catch (e) {
      // Handle initialization error silently
    }
  }

  @override
  void dispose() {
    _syncIntervalController.dispose();
    _portController.dispose();
    _sessionPortController.dispose();
    _refreshTimer?.cancel();
    _sessionUpdateSubscription?.cancel();
    super.dispose();
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
        _dbPath = info['dbPath'] ?? '';
        _allowedNetworks = List<String>.from(info['allowedNetworks'] ?? []);

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

  Future<void> _regenerateAccessCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newCode = await LanSyncService.regenerateAccessCode();
      setState(() {
        _accessCode = newCode;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access code regenerated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error regenerating access code: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Session Management Methods
  Future<void> _startSessionManagement() async {
    // Start session server if not running
    if (!LanSessionService.isServerRunning) {
      final started =
          await LanSessionService.startSessionServer(port: _sessionPort);
      if (started) {
        setState(() {
          _sessionServerEnabled = true;
        });
      }
    } else {
      setState(() {
        _sessionServerEnabled = true;
      });
    }

    // Load active sessions
    await _loadActiveSessions();

    // Start periodic refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        await _loadActiveSessions();
      }
    });

    // Listen for session updates
    _sessionUpdateSubscription =
        LanSessionService.sessionUpdates.listen((update) {
      if (mounted) {
        _handleSessionUpdate(update);
      }
    });
  }

  Future<void> _loadActiveSessions() async {
    try {
      final sessions = LanSessionService.activeSessions.values.toList();
      if (mounted) {
        setState(() {
          _activeSessions = sessions;
        });
      }
    } catch (e) {
      // Handle error silently to avoid spamming UI
    }
  }

  void _handleSessionUpdate(Map<String, dynamic> update) {
    final type = update['type'];
    switch (type) {
      case 'user_login':
      case 'user_logout':
      case 'session_expired':
        _loadActiveSessions();
        break;
    }
  }

  Future<void> _toggleSessionServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_sessionServerEnabled) {
        await LanSessionService.stopSessionServer();
        _refreshTimer?.cancel();
        _sessionUpdateSubscription?.cancel();
        setState(() {
          _sessionServerEnabled = false;
          _activeSessions = [];
        });
      } else {
        await _startSessionManagement();
      }
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

  Future<void> _endUserSession(String sessionId) async {
    try {
      final success = await LanSessionService.endUserSession(sessionId);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User session ended successfully')),
        );
        await _loadActiveSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending session: $e')),
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await LanSyncService.syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Synchronization completed successfully'
              : 'Synchronization failed'),
        ),
      );

      await _loadConnectionInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during synchronization: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSyncInterval() async {
    final value = int.tryParse(_syncIntervalController.text);
    if (value == null || value < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid interval (minimum 1)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await LanSyncService.setSyncInterval(value);
      setState(() {
        _syncInterval = value;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync interval updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating sync interval: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePort() async {
    final value = int.tryParse(_portController.text);
    if (value == null || value < 1024 || value > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid port (1024-65535)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Stop server if running
      if (_serverEnabled) {
        await LanSyncService.stopLanServer();
      }

      // Save new port
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('server_port', value);

      // Restart server if it was running
      if (_serverEnabled) {
        await LanSyncService.startLanServer(port: value);
      }

      setState(() {
        _port = value;
      });

      await _loadConnectionInfo();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server port updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating server port: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showDbBrowserInstructions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final instructions = await LanSyncService.getDbBrowserInstructions();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('DB Browser Connection Instructions'),
          content: SingleChildScrollView(
            child: SelectableText(instructions),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: instructions));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Instructions copied to clipboard')),
                );
                Navigator.pop(context);
              },
              child: const Text('Copy to Clipboard'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting instructions: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Build session card widget
  Widget _buildSessionCard(UserSession session) {
    final now = DateTime.now();
    final timeSinceActivity = now.difference(session.lastActivity).inMinutes;
    final isActive = timeSinceActivity < 5;
    final activityStatus = isActive ? 'Active' : '${timeSinceActivity}m ago';
    final duration = now.difference(session.loginTime).inMinutes;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getAccessLevelColor(session.accessLevel),
                  child: Text(
                    session.username.isNotEmpty
                        ? session.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            session.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getAccessLevelColor(session.accessLevel)
                                  .withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    _getAccessLevelColor(session.accessLevel),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              session.accessLevel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    _getAccessLevelColor(session.accessLevel),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.devices,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.deviceName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (session.ipAddress != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.network_check,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              session.ipAddress!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activityStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${duration}m session',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _endUserSession(session.sessionId),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'End Session',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.login,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Logged in: ${_formatDateTime(session.loginTime)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Get color for access level
  Color _getAccessLevelColor(String accessLevel) {
    switch (accessLevel.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'doctor':
        return Colors.blue;
      case 'medtech':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Format date time
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Connection'),
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
                  // Server Status Card
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
                                'LAN Server Status',
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _portController,
                                  decoration: const InputDecoration(
                                    labelText: 'Server Port',
                                    border: OutlineInputBorder(),
                                    hintText: '8080',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  enabled: !_serverEnabled,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _serverEnabled ? null : _updatePort,
                                child: const Text('Update Port'),
                              ),
                            ],
                          ),
                          if (_serverEnabled) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Access Code:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _accessCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(
                                    _accessCode,
                                    'Access code copied to clipboard',
                                  ),
                                  tooltip: 'Copy access code',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _regenerateAccessCode,
                                  tooltip: 'Regenerate access code',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Server IP Addresses:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (_ipAddresses.isEmpty)
                              const Text('No IP addresses available')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _ipAddresses.length,
                                itemBuilder: (context, index) {
                                  final ip = _ipAddresses[index];
                                  final url = 'http://$ip:$_port/db';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text('$ip:$_port'),
                                    subtitle: Text(url),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () => _copyToClipboard(
                                        url,
                                        'URL copied to clipboard',
                                      ),
                                      tooltip: 'Copy URL',
                                    ),
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Synchronization Settings Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Synchronization Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _syncIntervalController,
                                  decoration: const InputDecoration(
                                    labelText: 'Sync Interval (minutes)',
                                    border: OutlineInputBorder(),
                                    hintText: '5',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _updateSyncInterval,
                                child: const Text('Update'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pending Changes: $_pendingChanges',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _syncNow,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync Now'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Database Info Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Database Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Database Path:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dbPath,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copyToClipboard(
                                  _dbPath,
                                  'Database path copied to clipboard',
                                ),
                                tooltip: 'Copy path',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Allowed Networks:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_allowedNetworks.isEmpty)
                            const Text('No networks configured')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allowedNetworks.map((network) {
                                return Chip(
                                  label: Text('$network.*'),
                                  backgroundColor: Colors.blue[100],
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _showDbBrowserInstructions,
                              icon: const Icon(Icons.info_outline),
                              label: const Text('DB Browser Instructions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Session Management Card
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
                                'Session Management',
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
                                Expanded(
                                  child: TextField(
                                    controller: _sessionPortController,
                                    decoration: const InputDecoration(
                                      labelText: 'Session Server Port',
                                      border: OutlineInputBorder(),
                                      hintText: '8081',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    enabled: false, // Always disabled for now
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _loadActiveSessions,
                                  tooltip: 'Refresh Sessions',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Active Users: ${_activeSessions.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Auto-refresh: 5s',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_activeSessions.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No active user sessions',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: _activeSessions
                                    .map(
                                        (session) => _buildSessionCard(session))
                                    .toList(),
                              ),
                          ] else ...[
                            const Text(
                              'Enable session management to view and control active user sessions across devices.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Prevent multiple logins from same user',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const Text(
                              '• Monitor user activity and session duration',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const Text(
                              '• Remote session management and logout',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Security Info
                  const Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Security Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '• LAN server only allows connections from local network',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Access code required for database access',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Data is synchronized  ly between devices',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Changes are tracked and can be reviewed',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
