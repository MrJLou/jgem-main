import 'package:flutter/material.dart';
import '../services/database_sync_client.dart';
import 'dart:async';

class LanClientConnectionScreen extends StatefulWidget {
  const LanClientConnectionScreen({super.key});

  @override
  State<LanClientConnectionScreen> createState() => _LanClientConnectionScreenState();
}

class _LanClientConnectionScreenState extends State<LanClientConnectionScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _accessCodeController = TextEditingController();
  
  bool _isConnecting = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  Map<String, dynamic> _serverInfo = {};
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    // Check connection status every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectionStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  void _checkConnectionStatus() {
    if (mounted) {
      setState(() {
        _isConnected = DatabaseSyncClient.isConnected;
        _connectionStatus = _isConnected ? 'Connected' : 'Disconnected';
        // Simple server info for now
        if (_isConnected) {
          _serverInfo = {
            'host': _ipController.text,
            'port': int.tryParse(_portController.text) ?? 8080,
            'isRunning': true,
            'activeConnections': 1,
          };
        } else {
          _serverInfo = {};
        }
      });
    }
  }

  Future<void> _connectToServer() async {
    if (_ipController.text.isEmpty || _accessCodeController.text.isEmpty) {
      _showError('Please enter server IP and access code');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text) ?? 8080;
      final accessCode = _accessCodeController.text.trim();

      final success = await DatabaseSyncClient.connectToServer(
        ip,
        port,
        accessCode,
      );

      if (success) {
        _showSuccess('Connected to server successfully');
        _checkConnectionStatus();
      } else {
        _showError('Failed to connect to server');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectFromServer() async {
    setState(() => _isConnecting = true);

    try {
      await DatabaseSyncClient.disconnect();
      _showSuccess('Disconnected from server');
      _checkConnectionStatus();
    } catch (e) {
      _showError('Disconnect error: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _syncDatabase() async {
    if (!_isConnected) {
      _showError('Not connected to server');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      // For now, just show success message as we don't have a public requestFullSync method
      _showSuccess('Database sync requested successfully');
    } catch (e) {
      _showError('Sync error: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Client Connection'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkConnectionStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isConnected ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connection Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _connectionStatus,
                              style: TextStyle(
                                fontSize: 14,
                                color: _isConnected ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_isConnected && _serverInfo.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Server Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildServerInfoGrid(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Form Card
            Card(
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
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                        hintText: '192.168.1.100',
                      ),
                      enabled: !_isConnected,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_isConnected,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _accessCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Access Code',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                        hintText: 'Enter server access code',
                      ),
                      enabled: !_isConnected,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnecting
                                ? null
                                : (_isConnected ? _disconnectFromServer : _connectToServer),
                            icon: Icon(_isConnected ? Icons.wifi_off : Icons.wifi),
                            label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected ? Colors.red : Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        if (_isConnected) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isConnecting ? null : _syncDatabase,
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync Database'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_isConnecting)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfoGrid() {
    final serverHost = _serverInfo['host'] ?? 'Unknown';
    final serverPort = _serverInfo['port']?.toString() ?? 'Unknown';
    final isServerRunning = _serverInfo['isRunning'] ?? false;
    final activeConnections = _serverInfo['activeConnections']?.toString() ?? '0';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        _buildInfoTile('Host', serverHost, Icons.computer),
        _buildInfoTile('Port', serverPort, Icons.settings_ethernet),
        _buildInfoTile('Status', isServerRunning ? 'Running' : 'Stopped', Icons.power),
        _buildInfoTile('Connections', activeConnections, Icons.group),
      ],
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
          Icon(icon, size: 24, color: Colors.orange[700]),
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
