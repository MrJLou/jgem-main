import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_client_service.dart';
import '../services/lan_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnhancedLanClientConnectionScreen extends StatefulWidget {
  const EnhancedLanClientConnectionScreen({super.key});

  @override
  State<EnhancedLanClientConnectionScreen> createState() => _EnhancedLanClientConnectionScreenState();
}

class _EnhancedLanClientConnectionScreenState extends State<EnhancedLanClientConnectionScreen> {
  final _serverIpController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _sessionPortController = TextEditingController(text: '8081');
  final _accessCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';
  Map<String, dynamic>? _serverStatus;
  List<Map<String, dynamic>> _activeSessions = [];
  UserSession? _currentSession;
  
  late StreamSubscription _sessionUpdatesSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
    _setupSessionUpdates();
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _portController.dispose();
    _sessionPortController.dispose();
    _accessCodeController.dispose();
    _sessionUpdatesSubscription.cancel();
    super.dispose();
  }

  void _setupSessionUpdates() {
    // Note: This would need to be connected to remote session updates
    // For now, we'll poll for updates when connected
  }

  Future<void> _loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIpController.text = prefs.getString('lan_server_ip') ?? '';
    _portController.text = prefs.getString('lan_server_port') ?? '8080';
    _sessionPortController.text = prefs.getString('lan_session_port') ?? '8081';
    _accessCodeController.text = prefs.getString('lan_access_code') ?? '';
    
    // Check if we were previously connected
    if (_serverIpController.text.isNotEmpty && _accessCodeController.text.isNotEmpty) {
      _checkConnection();
    }
  }

  Future<void> _saveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lan_server_ip', _serverIpController.text);
    await prefs.setString('lan_server_port', _portController.text);
    await prefs.setString('lan_session_port', _sessionPortController.text);
    await prefs.setString('lan_access_code', _accessCodeController.text);
  }

  Future<void> _connectToServer() async {
    final serverIp = _serverIpController.text.trim();
    final portStr = _portController.text.trim();
    final sessionPortStr = _sessionPortController.text.trim();
    final accessCode = _accessCodeController.text.trim();

    if (serverIp.isEmpty || portStr.isEmpty || sessionPortStr.isEmpty || accessCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final port = int.tryParse(portStr);
    final sessionPort = int.tryParse(sessionPortStr);
    if (port == null || port < 1024 || port > 65535 || 
        sessionPort == null || sessionPort < 1024 || sessionPort > 65535) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid ports (1024-65535)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _connectionStatus = 'Connecting...';
    });

    try {
      // Connect with session management
      final connected = await LanClientService.connectToServerWithSession(
        serverIp, 
        port, 
        accessCode,
        sessionPort: sessionPort,
      );
      
      if (!mounted) return;
      if (connected) {
        await _saveConnection();
        if (!mounted) return;
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected successfully';
          _currentSession = LanClientService.currentSession;
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to LAN server successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Get server status and active sessions
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
            content: Text('Failed to connect to server. Check connection details.'),
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
          _currentSession = LanClientService.currentSession;
        });
        await _getActiveSessions();
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

  Future<void> _getActiveSessions() async {
    final sessions = await LanClientService.getActiveSessions();
    if (!mounted) return;
    if (sessions != null) {
      setState(() {
        _activeSessions = sessions;
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
    LanClientService.disconnect();
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _serverStatus = null;
      _activeSessions = [];
      _currentSession = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Enhanced LAN Server'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : () {
                _checkConnection();
                _getActiveSessions();
              },
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _portController,
                                  decoration: const InputDecoration(
                                    labelText: 'Data Port',
                                    border: OutlineInputBorder(),
                                    hintText: '8080',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  enabled: !_isConnected,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _sessionPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Session Port',
                                    border: OutlineInputBorder(),
                                    hintText: '8081',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  enabled: !_isConnected,
                                ),
                              ),
                            ],
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
                                  color: _isConnected ? Colors.green : Colors.red,
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

                    // Current Session Card
                    if (_currentSession != null) ...[
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    'Your Session',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSessionInfo(_currentSession!),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],

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
                              _buildStatusRow('Status', _serverStatus!['status'] ?? 'Unknown'),
                              _buildStatusRow('Database Path', _serverStatus!['dbPath'] ?? 'Unknown'),
                              _buildStatusRow('Pending Changes', '${_serverStatus!['pendingChanges'] ?? 0}'),
                              _buildStatusRow('Active Sessions', '${_serverStatus!['activeSessions'] ?? 0}'),
                              _buildStatusRow('Last Updated', _serverStatus!['timestamp'] ?? 'Unknown'),
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

                    // Active Sessions Card
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
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final session = _activeSessions[index];
                                  final isCurrentUser = session['sessionId'] == _currentSession?.sessionId;
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCurrentUser ? Colors.green : Colors.blue,
                                      child: Text(
                                        (session['username'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          session['username'] ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'YOU',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Device: ${session['deviceName'] ?? 'Unknown'}'),
                                        Text('Role: ${session['accessLevel'] ?? 'Unknown'}'),
                                        Text('Duration: ${session['duration'] ?? 0}m'),
                                        if (session['ipAddress'] != null)
                                          Text('IP: ${session['ipAddress']}'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _getActiveSessions,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh Users'),
                              ),
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
                              '3. Once connected, your session will be registered on the server',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '4. You can view other active users and download the database',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '5. Only one session per user is allowed at a time',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildSessionInfo(UserSession session) {
    final duration = DateTime.now().difference(session.loginTime);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow('Username', session.username),
        _buildStatusRow('Device', session.deviceName),
        _buildStatusRow('Role', session.accessLevel),
        _buildStatusRow('Duration', '${duration.inMinutes}m'),
        if (session.ipAddress != null)
          _buildStatusRow('IP Address', session.ipAddress!),
        _buildStatusRow('Session ID', session.sessionId),
      ],
    );
  }
}
