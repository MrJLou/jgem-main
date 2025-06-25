import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lan_sync_service.dart';
import '../services/lan_client_service.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class LanConnectionDiagnosticsScreen extends StatefulWidget {
  const LanConnectionDiagnosticsScreen({super.key});

  @override
  State<LanConnectionDiagnosticsScreen> createState() =>
      _LanConnectionDiagnosticsScreenState();
}

class _LanConnectionDiagnosticsScreenState
    extends State<LanConnectionDiagnosticsScreen> {
  bool _isRunning = false;
  List<Map<String, dynamic>> _diagnostics = [];
  final _serverIpController = TextEditingController();
  final _portController = TextEditingController(text: '8080');

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIpController.text = prefs.getString('lan_server_ip') ?? '';
    _portController.text = prefs.getString('lan_server_port') ?? '8080';
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _diagnostics.clear();
    });

    final serverIp = _serverIpController.text.trim();
    final port = int.tryParse(_portController.text) ?? 8080;

    try {
      await _addDiagnostic('Starting LAN Connection Diagnostics', 'info');

      // 1. Check local network interfaces
      await _checkNetworkInterfaces();

      // 2. Check if this device has LAN server running
      await _checkLocalServerStatus();

      // 3. Test network connectivity to target IP
      if (serverIp.isNotEmpty) {
        await _testNetworkConnectivity(serverIp, port);
      } else {
        await _addDiagnostic('No server IP provided, skipping connectivity test', 'warning');
      }

      // 4. Scan for available servers
      await _scanForServers();

      // 5. Check firewall and port availability
      await _checkPortAvailability(port);

      await _addDiagnostic('Diagnostics completed', 'success');
    } catch (e) {
      await _addDiagnostic('Diagnostics error: $e', 'error');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _addDiagnostic(String message, String type) async {
    setState(() {
      _diagnostics.add({
        'timestamp': DateTime.now().toIso8601String(),
        'message': message,
        'type': type,
      });
    });
    // Small delay to show progress
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _checkNetworkInterfaces() async {
    try {
      await _addDiagnostic('Checking network interfaces...', 'info');

      final interfaces = await NetworkInterface.list();
      final lanInterfaces = <String>[];

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final info = '${addr.address} (${interface.name})';
            lanInterfaces.add(info);

            if (addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                addr.address.startsWith('172.')) {
              await _addDiagnostic('Found LAN interface: $info', 'success');
            } else if (addr.address == '127.0.0.1') {
              await _addDiagnostic('Found loopback: $info', 'info');
            } else {
              await _addDiagnostic('Found interface: $info', 'info');
            }
          }
        }
      }

      if (lanInterfaces.isEmpty) {
        await _addDiagnostic('No network interfaces found', 'error');
      }
    } catch (e) {
      await _addDiagnostic('Network interface check failed: $e', 'error');
    }
  }

  Future<void> _checkLocalServerStatus() async {
    try {
      await _addDiagnostic('Checking local LAN server status...', 'info');

      final connectionInfo = await LanSyncService.getConnectionInfo();

      if (connectionInfo.containsKey('error')) {
        await _addDiagnostic('Error getting connection info: ${connectionInfo['error']}', 'error');
        return;
      }

      final lanServerEnabled = connectionInfo['lanServerEnabled'] ?? false;
      final port = connectionInfo['port'] ?? 8080;
      final ipAddresses = List<String>.from(connectionInfo['ipAddresses'] ?? []);
      final accessCode = connectionInfo['accessCode'];

      if (lanServerEnabled) {
        await _addDiagnostic('Local LAN server is ENABLED on port $port', 'success');
        await _addDiagnostic('Access code: $accessCode', 'info');

        for (final ip in ipAddresses) {
          await _addDiagnostic('Server available at: http://$ip:$port', 'success');
          
          // Test local server connectivity
          try {
            final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
            socket.destroy();
            await _addDiagnostic('Local server socket test PASSED for $ip:$port', 'success');
          } catch (e) {
            await _addDiagnostic('Local server socket test FAILED for $ip:$port: $e', 'error');
          }
        }

        if (ipAddresses.isEmpty) {
          await _addDiagnostic('No IP addresses found for local server', 'warning');
        }
      } else {
        await _addDiagnostic('Local LAN server is DISABLED', 'warning');
      }
    } catch (e) {
      await _addDiagnostic('Local server status check failed: $e', 'error');
    }
  }

  Future<void> _testNetworkConnectivity(String serverIp, int port) async {
    try {
      await _addDiagnostic('Testing connectivity to $serverIp:$port...', 'info');

      // Test basic socket connectivity
      try {
        final socket = await Socket.connect(
          serverIp,
          port,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        await _addDiagnostic('Socket connection to $serverIp:$port SUCCESSFUL', 'success');
      } catch (e) {
        await _addDiagnostic('Socket connection to $serverIp:$port FAILED: $e', 'error');
        return; // No point testing HTTP if socket fails
      }

      // Test HTTP connectivity
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        
        final request = await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
        final response = await request.close();
        
        await _addDiagnostic('HTTP status check returned: ${response.statusCode}', 
            response.statusCode == 200 || response.statusCode == 401 ? 'success' : 'warning');
        
        client.close();
      } catch (e) {
        await _addDiagnostic('HTTP connectivity test failed: $e', 'error');
      }
    } catch (e) {
      await _addDiagnostic('Network connectivity test error: $e', 'error');
    }
  }

  Future<void> _scanForServers() async {
    try {
      await _addDiagnostic('Scanning for available LAN servers...', 'info');

      final foundServers = await LanClientService.scanForServers();

      if (foundServers.isEmpty) {
        await _addDiagnostic('No LAN servers found on network', 'warning');
      } else {
        for (final server in foundServers) {
          final ip = server['ip'];
          final port = server['port'];
          final status = server['status'] ?? 'unknown';
          await _addDiagnostic('Found server at $ip:$port (status: $status)', 'success');
        }
      }
    } catch (e) {
      await _addDiagnostic('Server scan failed: $e', 'error');
    }
  }

  Future<void> _checkPortAvailability(int port) async {
    try {
      await _addDiagnostic('Checking port $port availability...', 'info');

      // Try to bind to the port to see if it's available
      try {
        final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        await server.close();
        await _addDiagnostic('Port $port is available for binding', 'success');
      } catch (e) {
        if (e.toString().contains('Address already in use')) {
          await _addDiagnostic('Port $port is already in use (server may be running)', 'info');
        } else {
          await _addDiagnostic('Port $port binding test failed: $e', 'error');
        }
      }
    } catch (e) {
      await _addDiagnostic('Port availability check failed: $e', 'error');
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
      default:
        return Icons.info;
    }
  }

  void _copyDiagnostics() {
    final diagnosticsText = _diagnostics
        .map((d) => '${d['timestamp']}: [${d['type'].toUpperCase()}] ${d['message']}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: diagnosticsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Connection Diagnostics'),
        actions: [
          if (_diagnostics.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyDiagnostics,
              tooltip: 'Copy diagnostics',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Test Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverIpController,
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address (optional)',
                        hintText: 'e.g., 192.168.1.100',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runDiagnostics,
                      child: _isRunning
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Running Diagnostics...'),
                              ],
                            )
                          : const Text('Run Diagnostics'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Diagnostic Results',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _diagnostics.isEmpty
                          ? const Center(
                              child: Text(
                                'Click "Run Diagnostics" to start testing',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _diagnostics.length,
                              itemBuilder: (context, index) {
                                final diagnostic = _diagnostics[index];
                                final type = diagnostic['type'];
                                final message = diagnostic['message'];
                                final timestamp = diagnostic['timestamp'];

                                return ListTile(
                                  leading: Icon(
                                    _getTypeIcon(type),
                                    color: _getTypeColor(type),
                                  ),
                                  title: Text(message),
                                  subtitle: Text(
                                    DateTime.parse(timestamp).toLocal().toString().substring(11, 19),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
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
