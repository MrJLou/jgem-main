import 'package:flutter/material.dart';
import '../services/database_sync_client.dart';
import '../services/enhanced_shelf_lan_server.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class LanConnectionDialog extends StatefulWidget {
  const LanConnectionDialog({super.key});

  @override
  State<LanConnectionDialog> createState() => _LanConnectionDialogState();
}

class _LanConnectionDialogState extends State<LanConnectionDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Server Management State
  Map<String, dynamic> _serverStatus = {};
  Timer? _statusTimer;

  // Client Connection State
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _accessCodeController = TextEditingController();
  bool _isConnecting = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  Map<String, dynamic> _serverInfo = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkConnectionStatus();
    _updateServerStatus();
    
    // Refresh status every 3 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _updateServerStatus();
      _checkConnectionStatus();
    });
    
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statusTimer?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  void _updateServerStatus() {
    if (mounted) {
      setState(() {
        _serverStatus = EnhancedShelfServer.getServerStatus();
      });
    }
  }

  void _checkConnectionStatus() {
    if (mounted) {
      setState(() {
        _isConnected = DatabaseSyncClient.isConnected;
        _connectionStatus = _isConnected ? 'Connected' : 'Disconnected';
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

  // Server Management Methods
  Future<void> _startServer() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await EnhancedShelfServer.startServer(port: 8080);
      if (success) {
        _showSuccess('Server started successfully on port 8080');
      } else {
        _showError('Failed to start server');
      }
    } catch (e) {
      _showError('Error starting server: $e');
    } finally {
      setState(() => _isLoading = false);
      _updateServerStatus();
    }
  }

  Future<void> _stopServer() async {
    setState(() => _isLoading = true);
    
    try {
      await EnhancedShelfServer.stopServer();
      _showSuccess('Server stopped successfully');
    } catch (e) {
      _showError('Error stopping server: $e');
    } finally {
      setState(() => _isLoading = false);
      _updateServerStatus();
    }
  }

  void _shareConnectionInfo() async {
    final connectionInfo = await EnhancedShelfServer.getConnectionInfo();
    
    if (connectionInfo.containsKey('error')) {
      _showError(connectionInfo['error']);
      return;
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(connectionInfo);
    Clipboard.setData(ClipboardData(text: jsonString));
    _showSuccess('Connection info copied to clipboard');
  }

  // Client Connection Methods
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
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
    if (_isLoading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SizedBox(
            width: 200,
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.wifi, color: Colors.teal[700], size: 28),
                const SizedBox(width: 12),
                const Text(
                  'LAN Connection',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Icon(Icons.computer, color: Colors.blue[700]),
                  text: 'Server Management',
                ),
                Tab(
                  icon: Icon(Icons.phone_android, color: Colors.orange[700]),
                  text: 'Connect to Server',
                ),
              ],
              indicatorColor: Colors.teal[700],
              labelColor: Colors.teal[700],
              unselectedLabelColor: Colors.grey[600],
            ),
            const SizedBox(height: 20),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildServerManagementTab(),
                  _buildClientConnectionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerManagementTab() {
    final isRunning = _serverStatus['isRunning'] as bool? ?? false;
    final port = _serverStatus['port'] as int? ?? 8080;
    final accessCode = _serverStatus['accessCode'] as String? ?? '';
    final activeConnections = _serverStatus['activeConnections'] as int? ?? 0;

    return SingleChildScrollView(
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
                        isRunning ? Icons.cloud_done : Icons.cloud_off,
                        color: isRunning ? Colors.green : Colors.grey,
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
                            isRunning ? 'Running on port $port' : 'Stopped',
                            style: TextStyle(
                              color: isRunning ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: isRunning,
                        onChanged: _isLoading ? null : (value) {
                          if (value) {
                            _startServer();
                          } else {
                            _stopServer();
                          }
                        },
                      ),
                    ],
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile('Access Code', accessCode, Icons.key),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTile('Connections', '$activeConnections', Icons.group),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _shareConnectionInfo,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Connection Info'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

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
                      Icon(Icons.help_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'How to Use Server Management',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Turn on the server using the switch above\n'
                    '2. Share the connection info with other devices\n'
                    '3. Other devices can connect using the access code\n'
                    '4. Monitor active connections in real-time',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientConnectionTab() {
    return SingleChildScrollView(
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
                          Text(
                            'Connection Status',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            _connectionStatus,
                            style: TextStyle(
                              color: _isConnected ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _checkConnectionStatus,
                        tooltip: 'Refresh Status',
                      ),
                    ],
                  ),
                  if (_isConnected) ...[
                    const SizedBox(height: 16),
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
                  Text(
                    'Connect to Server',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  // Server IP
                  TextFormField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Server IP Address',
                      hintText: '192.168.1.100',
                      prefixIcon: Icon(Icons.computer),
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 16),
                  
                  // Port
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8080',
                      prefixIcon: Icon(Icons.settings_ethernet),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 16),
                  
                  // Access Code
                  TextFormField(
                    controller: _accessCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Access Code',
                      hintText: 'Enter access code from server',
                      prefixIcon: Icon(Icons.key),
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConnecting || _isConnected ? null : _connectToServer,
                          icon: const Icon(Icons.wifi),
                          label: const Text('Connect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_isConnected) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnecting ? null : _disconnectFromServer,
                            icon: const Icon(Icons.wifi_off),
                            label: const Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.teal[700]),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
