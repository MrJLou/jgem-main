import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanClientConnectionScreen extends StatefulWidget {
  const LanClientConnectionScreen({super.key});

  @override
  State<LanClientConnectionScreen> createState() => _LanClientConnectionScreenState();
}

class _LanClientConnectionScreenState extends State<LanClientConnectionScreen> {
  final _serverIpController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _accessCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';
  Map<String, dynamic>? _serverStatus;

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
    super.dispose();
  }

  Future<void> _loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIpController.text = prefs.getString('lan_server_ip') ?? '';
    _portController.text = prefs.getString('lan_server_port') ?? '8080';
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
    await prefs.setString('lan_access_code', _accessCodeController.text);
  }

  Future<void> _connectToServer() async {
    final serverIp = _serverIpController.text.trim();
    final portStr = _portController.text.trim();
    final accessCode = _accessCodeController.text.trim();

    if (serverIp.isEmpty || portStr.isEmpty || accessCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1024 || port > 65535) {
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
      final connected = await LanClientService.connectToServer(serverIp, port, accessCode);
      
      if (connected) {
        await _saveConnection();
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected successfully';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to LAN server successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Get server status
        await _getServerStatus();
      } else {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Connection failed';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to server. Check IP, port, and access code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Connection error: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Checking connection...';
    });

    try {
      final status = await LanClientService.getServerStatus();
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
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Connection check failed';
        _serverStatus = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getServerStatus() async {
    final status = await LanClientService.getServerStatus();
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
      if (dbPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database downloaded to: $dbPath'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download database'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _disconnect() {
    LanClientService.disconnect();
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _serverStatus = null;
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
                              _buildStatusRow('Last Updated', _serverStatus!['timestamp'] ?? 'Unknown'),
                              if (_serverStatus!['allowedNetworks'] != null)
                                _buildStatusRow('Allowed Networks', 
                                  (_serverStatus!['allowedNetworks'] as List).join(', ')),
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
                              '3. Once connected, you can download the latest database',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '4. Use DB Browser for SQLite to view the downloaded database',
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
