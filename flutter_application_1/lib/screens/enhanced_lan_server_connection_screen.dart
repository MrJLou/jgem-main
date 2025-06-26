import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/enhanced_real_time_sync_service.dart';
import '../services/lan_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class EnhancedLanServerConnectionScreen extends StatefulWidget {
  const EnhancedLanServerConnectionScreen({super.key});

  @override
  State<EnhancedLanServerConnectionScreen> createState() =>
      _EnhancedLanServerConnectionScreenState();
}

class _EnhancedLanServerConnectionScreenState extends State<EnhancedLanServerConnectionScreen> {
  bool _isLoading = true;
  bool _serverEnabled = false;
  String _accessCode = '';
  List<String> _ipAddresses = [];
  int _port = 8080;
  int _activeSessions = 0;
  int _activeConnections = 0;
  String _serverStatus = 'Stopped';
  Timer? _refreshTimer;
  StreamSubscription? _statusSubscription;

  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServerSettings();
    _startStatusMonitoring();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusSubscription?.cancel();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadServerSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _port = prefs.getInt('server_port') ?? 8080;
      _portController.text = _port.toString();
      
      // Get server status
      final status = EnhancedRealTimeSyncService.getServerStatus();
      _serverEnabled = status['isRunning'] ?? false;
      _accessCode = status['accessCode'] ?? '';
      
      if (_serverEnabled) {
        await _refreshServerInfo();
      }
    } catch (e) {
      _showError('Failed to load server settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startStatusMonitoring() {
    _statusSubscription = EnhancedRealTimeSyncService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _serverStatus = status;
        });
      }
    });

    // Refresh server info periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_serverEnabled) {
        _refreshServerInfo();
      }
    });
  }

  Future<void> _refreshServerInfo() async {
    try {
      final status = EnhancedRealTimeSyncService.getServerStatus();
      final sessions = LanSessionService.activeSessions;
      
      setState(() {
        _serverEnabled = status['isRunning'] ?? false;
        _accessCode = status['accessCode'] ?? '';
        _ipAddresses = List<String>.from(status['allowedIpRanges'] ?? []);
        _activeSessions = sessions.length;
        // Note: activeConnections would need to be exposed from ShelfLanServer
        _serverStatus = _serverEnabled ? 'Running' : 'Stopped';
      });
    } catch (e) {
      debugPrint('Error refreshing server info: $e');
    }
  }

  Future<void> _toggleServer() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_serverEnabled) {
        // Stop server
        await EnhancedRealTimeSyncService.stopServer();
        _showSuccess('Server stopped successfully');
      } else {
        // Start server
        final success = await EnhancedRealTimeSyncService.startServer(port: _port);
        if (success) {
          _showSuccess('Server started successfully on port $_port');
          await _saveServerSettings();
        } else {
          _showError('Failed to start server');
        }
      }
      
      await _refreshServerInfo();
    } catch (e) {
      _showError('Server operation failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('server_port', _port);
      await prefs.setBool('lan_server_enabled', _serverEnabled);
    } catch (e) {
      debugPrint('Error saving server settings: $e');
    }
  }

  void _updatePort() {
    final newPort = int.tryParse(_portController.text);
    if (newPort != null && newPort >= 1024 && newPort <= 65535) {
      setState(() => _port = newPort);
    } else {
      _showError('Please enter a valid port number (1024-65535)');
      _portController.text = _port.toString();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _copyConnectionInfo() async {
    if (_accessCode.isEmpty || _ipAddresses.isEmpty) {
      _showError('Server is not running or connection info not available');
      return;
    }

    final primaryIp = _ipAddresses.firstWhere(
      (ip) => ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.'),
      orElse: () => _ipAddresses.first,
    );

    final connectionInfo = {
      'serverIp': '$primaryIp.100', // Assuming host ends with .100
      'port': _port,
      'accessCode': _accessCode,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(connectionInfo);
    
    await Clipboard.setData(ClipboardData(text: jsonString));
    _showSuccess('Connection info copied to clipboard');
  }

  Future<void> _shareInstructions() async {
    if (_accessCode.isEmpty || _ipAddresses.isEmpty) {
      _showError('Server is not running or connection info not available');
      return;
    }

    final primaryIp = _ipAddresses.firstWhere(
      (ip) => ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.'),
      orElse: () => _ipAddresses.first,
    );

    final instructions = '''
📱 PATIENT MANAGEMENT LAN CONNECTION
==================================

Server Details:
• IP Address: $primaryIp.100
• Port: $_port
• Access Code: $_accessCode

Instructions:
1. Open the Patient Management app on your device
2. Go to "LAN Client Connection"
3. Enter the server details above
4. Tap "Connect to Server"

Alternative IP Addresses:
${_ipAddresses.map((ip) => '• $ip.100:$_port').join('\n')}

Generated: ${DateTime.now().toString()}
''';

    await Clipboard.setData(ClipboardData(text: instructions));
    _showSuccess('Instructions copied to clipboard');
  }

  Color _getStatusColor() {
    switch (_serverStatus.toLowerCase()) {
      case 'running':
        return Colors.green;
      case 'connecting...':
      case 'starting...':
        return Colors.orange;
      case 'stopped':
      case 'disconnected':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced LAN Server'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshServerInfo,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Server Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _serverEnabled ? Icons.cloud_done : Icons.cloud_off,
                                color: _getStatusColor(),
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Server Status',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  Text(
                                    _serverStatus,
                                    style: TextStyle(
                                      color: _getStatusColor(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Switch(
                                value: _serverEnabled,
                                onChanged: _isLoading ? null : (_) => _toggleServer(),
                              ),
                            ],
                          ),
                          if (_serverEnabled) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoTile(
                                    'Port',
                                    _port.toString(),
                                    Icons.network_wifi,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoTile(
                                    'Active Sessions',
                                    _activeSessions.toString(),
                                    Icons.people,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoTile(
                                    'Connections',
                                    _activeConnections.toString(),
                                    Icons.link,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoTile(
                                    'Access Code',
                                    _accessCode,
                                    Icons.security,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Server Configuration Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Server Configuration',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Server Port',
                              hintText: 'Enter port number (1024-65535)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _updatePort(),
                            enabled: !_serverEnabled,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Note: Server must be stopped to change the port',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_serverEnabled) ...[
                    const SizedBox(height: 16),

                    // Connection Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection Information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            if (_ipAddresses.isNotEmpty) ...[
                              Text(
                                'Available IP Addresses:',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ..._ipAddresses.map((ip) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('• $ip.100:$_port'),
                              )),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _copyConnectionInfo,
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy JSON'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _shareInstructions,
                                    icon: const Icon(Icons.share),
                                    label: const Text('Copy Instructions'),
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
                    if (_activeSessions > 0)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Sessions ($_activeSessions)',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              // TODO: Display active sessions from LanSessionService
                              const Text('Session details will be displayed here'),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 16),

                  // Help Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'How to Connect',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Start the server by toggling the switch above\n'
                            '2. Copy connection information or instructions\n'
                            '3. Share with other devices on the same network\n'
                            '4. Use the LAN Client Connection screen on other devices',
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

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Colors.blue[700]),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
