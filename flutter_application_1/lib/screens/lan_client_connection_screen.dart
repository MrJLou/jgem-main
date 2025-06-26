import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_client_service.dart';
import '../services/lan_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class LanClientConnectionScreen extends StatefulWidget {
  const LanClientConnectionScreen({super.key});

  @override
  State<LanClientConnectionScreen> createState() =>
      _LanClientConnectionScreenState();
}

class _LanClientConnectionScreenState extends State<LanClientConnectionScreen> {
  final _serverIpController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _accessCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';
  Map<String, dynamic>? _serverStatus;
  List<Map<String, dynamic>> _activeSessions = [];
  Timer? _refreshTimer;
  StreamSubscription? _sessionUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _portController.dispose();
    _accessCodeController.dispose();
    _refreshTimer?.cancel();
    _sessionUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIpController.text = prefs.getString('lan_server_ip') ?? '';

    // Handle both int and string values for port
    final portValue = prefs.get('lan_server_port');
    if (portValue is int) {
      _portController.text = portValue.toString();
    } else if (portValue is String) {
      _portController.text = portValue;
    } else {
      _portController.text = '8080';
    }

    _accessCodeController.text = prefs.getString('lan_access_code') ?? '';

    // Check if we were previously connected
    if (_serverIpController.text.isNotEmpty &&
        _accessCodeController.text.isNotEmpty) {
      _checkConnection();
    }
  }

  Future<void> _saveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lan_server_ip', _serverIpController.text);
    await prefs.setInt(
        'lan_server_port', int.tryParse(_portController.text) ?? 8080);
    await prefs.setString('lan_access_code', _accessCodeController.text);
  }

  Future<void> _connectToServer() async {
    final serverIp = _serverIpController.text.trim();
    final portStr = _portController.text.trim();
    final accessCode = _accessCodeController.text.trim();

    if (serverIp.isEmpty || portStr.isEmpty || accessCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1024 || port > 65535) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid port (1024-65535)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _connectionStatus = 'Connecting...';
    });

    try {
      // Use enhanced connection with integrated session management
      final connected = await LanClientService.connectToServerWithSession(
          serverIp, port, accessCode);

      if (!mounted) return;
      if (connected) {
        await _saveConnection();
        if (!mounted) return;
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected successfully';
        });

        // Start session monitoring
        await _startSessionMonitoring();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to LAN server successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Get initial data
        await _getServerStatus();
        await _getActiveSessions();
      } else {
        if (!mounted) return;
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Connection failed';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to connect to server. Check IP, port, and access code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Connection error: $e';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Start session monitoring
  Future<void> _startSessionMonitoring() async {
    // Start periodic refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isConnected) {
        await _getActiveSessions();
        await _getServerStatus();
      }
    });

    // Listen for session updates (if available)
    try {
      _sessionUpdateSubscription =
          LanSessionService.sessionUpdates.listen((update) {
        if (mounted) {
          _handleSessionUpdate(update);
        }
      });
    } catch (e) {
      // Session updates might not be available in client mode
      debugPrint('Session updates not available: $e');
    }
  }

  // Handle session updates
  void _handleSessionUpdate(Map<String, dynamic> update) {
    final type = update['type'];
    switch (type) {
      case 'user_login':
      case 'user_logout':
      case 'session_expired':
        _getActiveSessions();
        break;
    }
  }

  // Get active sessions from server
  Future<void> _getActiveSessions() async {
    try {
      final sessions = await LanClientService.getActiveSessions();
      if (mounted && sessions != null) {
        setState(() {
          _activeSessions = sessions;
        });
      }
    } catch (e) {
      debugPrint('Failed to get active sessions: $e');
    }
  }

  // Sync database with server
  Future<void> _syncDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Upload local changes first
      final success = await LanClientService.uploadChanges([]);

      if (success) {
        // Then download changes from server
        final changes = await LanClientService.downloadChanges();

        if (!mounted) return;
        if (changes != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synchronized ${changes.length} changes'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database synchronized successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync database'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Build user session card
  Widget _buildUserSessionCard(Map<String, dynamic> session) {
    final username = session['username'] ?? 'Unknown';
    final deviceName = session['deviceName'] ?? 'Unknown Device';
    final accessLevel = session['accessLevel'] ?? 'Unknown';
    final loginTime = session['loginTime'] != null
        ? DateTime.tryParse(session['loginTime'])
        : null;
    final lastActivity = session['lastActivity'] != null
        ? DateTime.tryParse(session['lastActivity'])
        : null;
    final duration = session['duration'] ?? 0;
    final ipAddress = session['ipAddress'];

    // Calculate activity status
    final now = DateTime.now();
    bool isActive = false;
    String activityStatus = 'Inactive';

    if (lastActivity != null) {
      final timeSinceActivity = now.difference(lastActivity).inMinutes;
      if (timeSinceActivity < 5) {
        isActive = true;
        activityStatus = 'Active';
      } else {
        activityStatus = '${timeSinceActivity}m ago';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getAccessLevelColor(accessLevel),
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
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
                            username,
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
                              color: _getAccessLevelColor(accessLevel)
                                  .withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _getAccessLevelColor(accessLevel),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              accessLevel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getAccessLevelColor(accessLevel),
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
                            deviceName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (ipAddress != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.network_check,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ipAddress,
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
                  ],
                ),
              ],
            ),
            if (loginTime != null) ...[
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
                    'Logged in: ${_formatDateTime(loginTime)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
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

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Checking connection...';
    });

    try {
      final status = await LanClientService.getServerStatus();
      if (!mounted) return;
      if (status != null) {
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected';
          _serverStatus = status;
        });
      } else {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Server not reachable';
          _serverStatus = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Connection check failed';
        _serverStatus = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getServerStatus() async {
    final status = await LanClientService.getServerStatus();
    if (!mounted) return;
    if (status != null) {
      setState(() {
        _serverStatus = status;
      });
    }
  }

  Future<void> _downloadDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbPath = await LanClientService.downloadDatabase();
      if (!mounted) return;
      if (dbPath != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database downloaded to: $dbPath'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download database'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _disconnect() {
    _refreshTimer?.cancel();
    _sessionUpdateSubscription?.cancel();
    LanClientService.disconnect();
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _serverStatus = null;
      _activeSessions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to LAN Server'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _checkConnection,
              tooltip: 'Check Connection',
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
                  // Connection Form Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Server Connection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _serverIpController,
                            decoration: const InputDecoration(
                              labelText: 'Server IP Address',
                              border: OutlineInputBorder(),
                              hintText: '192.168.1.100',
                            ),
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                              hintText: '8080',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _accessCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Access Code',
                              border: OutlineInputBorder(),
                              hintText: 'Enter access code from server',
                            ),
                            enabled: !_isConnected,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status: $_connectionStatus',
                                style: TextStyle(
                                  color:
                                      _isConnected ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isConnected)
                                ElevatedButton(
                                  onPressed: _disconnect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Disconnect'),
                                )
                              else
                                ElevatedButton(
                                  onPressed: _connectToServer,
                                  child: const Text('Connect'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isConnected) ...[
                    const SizedBox(height: 16),

                    // Server Status Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Server Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_serverStatus != null) ...[
                              _buildStatusRow('Status',
                                  _serverStatus!['status'] ?? 'Unknown'),
                              _buildStatusRow('Database Path',
                                  _serverStatus!['dbPath'] ?? 'Unknown'),
                              _buildStatusRow('Pending Changes',
                                  '${_serverStatus!['pendingChanges'] ?? 0}'),
                              _buildStatusRow('Last Updated',
                                  _serverStatus!['timestamp'] ?? 'Unknown'),
                              if (_serverStatus!['allowedNetworks'] != null)
                                _buildStatusRow(
                                    'Allowed Networks',
                                    (_serverStatus!['allowedNetworks'] as List)
                                        .join(', ')),
                            ] else
                              const Text('No server status available'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _getServerStatus,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh Status'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _downloadDatabase,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download DB'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Active Users',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Total: ${_activeSessions.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 20),
                                      onPressed: _getActiveSessions,
                                      tooltip: 'Refresh Users',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_activeSessions.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No active users',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...(_activeSessions.map(
                                  (session) => _buildUserSessionCard(session))),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Database Sync Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Database Synchronization',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Keep your local database synchronized with the server database for real-time updates.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _downloadDatabase,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download DB'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _syncDatabase,
                                  icon: const Icon(Icons.sync),
                                  label: const Text('Sync Changes'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Instructions Card
                    const Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'How to Use',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              '1. Get the server IP address and access code from the main device',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '2. Enter the connection details and click Connect',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '3. Once connected, you can view active users and sync databases',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '4. The user list refreshes automatically to show login/logout activity',
                              style: TextStyle(fontSize: 14),
                            ),
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

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
