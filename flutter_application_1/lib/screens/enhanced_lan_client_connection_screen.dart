import 'package:flutter/material.dart';
import '../services/enhanced_real_time_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class EnhancedLanClientConnectionScreen extends StatefulWidget {
  const EnhancedLanClientConnectionScreen({super.key});

  @override
  State<EnhancedLanClientConnectionScreen> createState() =>
      _EnhancedLanClientConnectionScreenState();
}

class _EnhancedLanClientConnectionScreenState extends State<EnhancedLanClientConnectionScreen> {
  final _serverIpController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _accessCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';
  String _lastSyncTime = 'Never';
  int _syncCount = 0;
  Timer? _statusTimer;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
    _setupStatusListening();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _statusSubscription?.cancel();
    _syncSubscription?.cancel();
    _serverIpController.dispose();
    _portController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverIpController.text = prefs.getString('lan_server_ip') ?? '';
      
      final portValue = prefs.get('lan_server_port');
      if (portValue is int) {
        _portController.text = portValue.toString();
      } else if (portValue is String) {
        _portController.text = portValue;
      }
      
      _accessCodeController.text = prefs.getString('lan_access_code') ?? '';
      
      // Check current connection status
      _isConnected = EnhancedRealTimeSyncService.isConnected;
      if (_isConnected) {
        _connectionStatus = 'Connected';
      }
    } catch (e) {
      _showError('Failed to load saved connection: $e');
    }
  }

  void _setupStatusListening() {
    // Listen to connection status changes
    _statusSubscription = EnhancedRealTimeSyncService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
          _isConnected = status.toLowerCase().contains('connected') && 
                         !status.toLowerCase().contains('disconnected');
        });
      }
    });

    // Listen to database updates to count syncs
    _syncSubscription = EnhancedRealTimeSyncService.databaseUpdates.listen((update) {
      if (mounted) {
        setState(() {
          _syncCount++;
          _lastSyncTime = DateTime.now().toString().substring(11, 19);
        });
      }
    });

    // Update status periodically
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _isConnected = EnhancedRealTimeSyncService.isConnected;
        });
      }
    });
  }

  Future<void> _saveConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lan_server_ip', _serverIpController.text.trim());
      await prefs.setInt('lan_server_port', int.parse(_portController.text));
      await prefs.setString('lan_access_code', _accessCodeController.text.trim());
    } catch (e) {
      debugPrint('Error saving connection: $e');
    }
  }

  Future<void> _connectToServer() async {
    if (_isLoading) return;

    final serverIp = _serverIpController.text.trim();
    final portText = _portController.text.trim();
    final accessCode = _accessCodeController.text.trim();

    if (serverIp.isEmpty || portText.isEmpty || accessCode.isEmpty) {
      _showError('Please fill in all connection details');
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port < 1024 || port > 65535) {
      _showError('Please enter a valid port number (1024-65535)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Test basic connectivity first
      final canConnect = await EnhancedRealTimeSyncService.testConnection(serverIp, port);
      if (!canConnect) {
        _showError('Cannot reach server at $serverIp:$port');
        return;
      }

      // Attempt WebSocket connection
      final success = await EnhancedRealTimeSyncService.connectToServer(
        serverIp,
        port,
        accessCode,
        autoReconnect: true,
      );

      if (success) {
        await _saveConnection();
        _showSuccess('Connected to server successfully');
      } else {
        _showError('Failed to connect to server');
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await EnhancedRealTimeSyncService.disconnect();
      _showSuccess('Disconnected from server');
    } catch (e) {
      _showError('Error disconnecting: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importConnectionSettings() async {
    final jsonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Connection Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste connection JSON here:'),
            const SizedBox(height: 8),
            TextField(
              controller: jsonController,
              decoration: const InputDecoration(
                hintText: '{"serverIp":"192.168.1.100","port":8080,"accessCode":"abc123"}',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final jsonData = jsonController.text.trim();
              if (jsonData.isEmpty) {
                _showError('Please enter JSON data');
                return;
              }

              try {
                final success = await EnhancedRealTimeSyncService.importConnectionSettings(jsonData);
                Navigator.pop(context);
                
                if (success) {
                  await _loadSavedConnection();
                  _showSuccess('Connection settings imported successfully');
                  // Try to connect automatically
                  await _connectToServer();
                } else {
                  _showError('Failed to import connection settings');
                }
              } catch (e) {
                Navigator.pop(context);
                _showError('Invalid JSON format: $e');
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    final serverIp = _serverIpController.text.trim();
    final portText = _portController.text.trim();

    if (serverIp.isEmpty || portText.isEmpty) {
      _showError('Please enter server IP and port');
      return;
    }

    final port = int.tryParse(portText);
    if (port == null) {
      _showError('Please enter a valid port number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final canConnect = await EnhancedRealTimeSyncService.testConnection(serverIp, port);
      if (canConnect) {
        _showSuccess('Server is reachable at $serverIp:$port');
      } else {
        _showError('Cannot reach server at $serverIp:$port');
      }
    } catch (e) {
      _showError('Connection test failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _requestFullSync() {
    if (_isConnected) {
      EnhancedRealTimeSyncService.requestFullSync();
      _showSuccess('Full sync requested');
    } else {
      _showError('Not connected to server');
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

  Color _getStatusColor() {
    if (_isConnected) return Colors.green;
    if (_connectionStatus.toLowerCase().contains('connecting')) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced LAN Client'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _importConnectionSettings,
            tooltip: 'Import Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                          _isConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: _getStatusColor(),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection Status',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _connectionStatus,
                              style: TextStyle(
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ONLINE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_isConnected) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              'Last Sync',
                              _lastSyncTime,
                              Icons.sync,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoTile(
                              'Sync Count',
                              _syncCount.toString(),
                              Icons.numbers,
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

            // Connection Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverIpController,
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address',
                        hintText: '192.168.1.100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                      enabled: !_isConnected,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '8080',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.settings_ethernet),
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !_isConnected,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _accessCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Access Code',
                              hintText: 'Enter code',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.security),
                            ),
                            enabled: !_isConnected,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _testConnection,
                            icon: const Icon(Icons.network_check),
                            label: const Text('Test Connection'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _isConnected
                                    ? _disconnect
                                    : _connectToServer,
                            icon: Icon(_isConnected ? Icons.link_off : Icons.connect_without_contact),
                            label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_isConnected) ...[
              const SizedBox(height: 16),

              // Sync Controls Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Controls',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _requestFullSync,
                              icon: const Icon(Icons.sync),
                              label: const Text('Request Full Sync'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Reset sync counter
                                setState(() {
                                  _syncCount = 0;
                                  _lastSyncTime = 'Reset';
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset Counter'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Real-time Updates Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time Sync Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: EnhancedRealTimeSyncService.databaseUpdates,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text('Waiting for updates...');
                          }

                          final update = snapshot.data!;
                          final table = update['table'] ?? 'Unknown';
                          final operation = update['operation'] ?? 'Unknown';
                          final timestamp = update['timestamp'] ?? '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border.all(color: Colors.green),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Latest Update: $table.$operation',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('Time: $timestamp'),
                              ],
                            ),
                          );
                        },
                      ),
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
                        Icon(Icons.help, color: Colors.blue[700]),
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
                      '1. Get connection details from the server device\n'
                      '2. Enter Server IP, Port, and Access Code\n'
                      '3. Test connection first, then connect\n'
                      '4. Real-time sync will start automatically\n\n'
                      'Tip: Use the import button to paste connection JSON',
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
          Icon(icon, size: 24, color: Colors.green[700]),
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
