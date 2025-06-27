import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/enhanced_shelf_lan_server.dart';
import 'dart:convert';
import 'dart:async';

class ServerManagementScreen extends StatefulWidget {
  const ServerManagementScreen({super.key});

  @override
  State<ServerManagementScreen> createState() => _ServerManagementScreenState();
}

class _ServerManagementScreenState extends State<ServerManagementScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _serverStatus = {};
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _updateServerStatus();
    // Refresh status every 3 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _updateServerStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _updateServerStatus() {
    if (mounted) {
      setState(() {
        _serverStatus = EnhancedShelfServer.getServerStatus();
      });
    }
  }

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

  void _shareConnectionInfo() {
    final connectionInfo = EnhancedShelfServer.getConnectionInfo();
    
    if (connectionInfo.containsKey('error')) {
      _showError(connectionInfo['error']);
      return;
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(connectionInfo);
    Clipboard.setData(ClipboardData(text: jsonString));
    _showSuccess('Connection info copied to clipboard');
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

  Color _getStatusColor() {
    final isRunning = _serverStatus['isRunning'] as bool? ?? false;
    return isRunning ? Colors.green : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _serverStatus['isRunning'] as bool? ?? false;
    final port = _serverStatus['port'] as int? ?? 8080;
    final accessCode = _serverStatus['accessCode'] as String? ?? '';
    final activeConnections = _serverStatus['activeConnections'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateServerStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                          isRunning ? Icons.cloud_done : Icons.cloud_off,
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
                              isRunning ? 'Running' : 'Stopped',
                              style: TextStyle(
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
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
                            child: _buildInfoTile(
                              'Port',
                              port.toString(),
                              Icons.network_wifi,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoTile(
                              'Connections',
                              activeConnections.toString(),
                              Icons.link,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              'Access Code',
                              accessCode,
                              Icons.security,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoTile(
                              'DB Sync',
                              'Active',
                              Icons.sync,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (isRunning) ...[
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
                      Text(
                        'Share this information with other devices to connect:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _shareConnectionInfo,
                        icon: const Icon(Icons.share),
                        label: const Text('Copy Connection Info'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Real-time Sync Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database Sync Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: EnhancedShelfServer.syncUpdates,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text('No sync activity yet');
                          }

                          final update = snapshot.data!;
                          final table = update['table'] ?? 'Unknown';
                          final operation = update['operation'] ?? 'Unknown';
                          final timestamp = update['timestamp'] ?? '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sync, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Last Sync: $operation on $table',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Time: ${timestamp.split('T').last.split('.').first}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
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
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'How Database Sync Works',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• When you start the server, your database becomes available to other devices\n'
                      '• Any changes (add, edit, delete) are automatically synced to connected devices\n'
                      '• Other devices can connect using the IP address and access code\n'
                      '• All patient records, appointments, and data stay synchronized in real-time',
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
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
