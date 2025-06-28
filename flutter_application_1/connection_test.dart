import 'dart:io';
import 'dart:convert';
import 'lib/services/database_helper.dart';
import 'lib/services/enhanced_shelf_lan_server.dart';
import 'lib/services/socket_service.dart';

/// Comprehensive connection test for host and client functionality
class ConnectionTest {
  static late DatabaseHelper _dbHelper;
  static const int testPort = 8080;
  
  static Future<void> main() async {
    print('🔍 Starting comprehensive connection test for flutter_application_1...\n');
    
    try {
      // Initialize database
      await _initializeDatabase();
      
      // Test 1: Network interface detection
      await _testNetworkInterfaces();
      
      // Test 2: Host server capabilities
      await _testHostServer();
      
      // Test 3: Client connection capabilities
      await _testClientConnection();
      
      // Test 4: Firewall and port accessibility
      await _testFirewallAndPorts();
      
      // Test 5: Cross-device communication simulation
      await _testCrossDeviceCommunication();
      
      print('\n✅ All connection tests completed!');
      
    } catch (e) {
      print('❌ Connection test failed: $e');
      exit(1);
    }
  }
  
  static Future<void> _initializeDatabase() async {
    print('📁 Initializing database...');
    _dbHelper = DatabaseHelper();
    await _dbHelper.database;
    
    // Initialize services
    await EnhancedShelfServer.initialize(_dbHelper);
    await SocketService.initialize(_dbHelper);
    
    print('✅ Database and services initialized');
  }
  
  static Future<void> _testNetworkInterfaces() async {
    print('\n🌐 Testing network interface detection...');
    
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      print('Found ${interfaces.length} network interfaces:');
      
      for (final interface in interfaces) {
        print('  Interface: ${interface.name}');
        for (final addr in interface.addresses) {
          print('    IP: ${addr.address}');
          
          // Check if this is a LAN IP
          final isLan = _isLanIp(addr.address);
          print('    Type: ${isLan ? 'LAN' : 'Other'}');
          
          if (isLan && addr.address.startsWith('192.168.68.')) {
            print('    ⭐ Primary network detected!');
          }
        }
      }
      
      // Get the actual server IP that would be used
      final serverInfo = await EnhancedShelfServer.getConnectionInfo();
      print('\n🎯 Server would use IP: ${serverInfo['serverIp']}');
      
    } catch (e) {
      print('❌ Network interface test failed: $e');
      rethrow;
    }
  }
  
  static Future<void> _testHostServer() async {
    print('\n🏠 Testing host server functionality...');
    
    try {
      // Start the server
      final serverStarted = await SocketService.startHosting(port: testPort);
      
      if (serverStarted) {
        print('✅ Server started successfully on port $testPort');
        
        // Get connection info
        final connectionInfo = await SocketService.getHostConnectionInfo();
        print('📋 Connection details:');
        print('  Server IP: ${connectionInfo['serverIp']}');
        print('  Port: ${connectionInfo['port']}');
        print('  Access Code: ${connectionInfo['accessCode']}');
        print('  URL: ${connectionInfo['url']}');
        
        // Test HTTP endpoint
        await _testHttpEndpoint(connectionInfo);
        
        // Wait a moment for server to fully initialize
        await Future.delayed(const Duration(seconds: 2));
        
      } else {
        print('❌ Failed to start server');
        throw Exception('Server startup failed');
      }
      
    } catch (e) {
      print('❌ Host server test failed: $e');
      rethrow;
    }
  }
  
  static Future<void> _testHttpEndpoint(Map<String, dynamic> connectionInfo) async {
    print('\n📡 Testing HTTP endpoints...');
    
    try {
      final client = HttpClient();
      
      // Test status endpoint
      final statusUrl = '${connectionInfo['url']}/status';
      print('Testing: $statusUrl');
      
      final request = await client.getUrl(Uri.parse(statusUrl));
      request.headers.set('X-Access-Code', connectionInfo['accessCode']);
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final status = json.decode(responseBody);
        print('✅ Status endpoint working');
        print('  Server status: ${status['status']}');
        print('  Tables: ${status['tables']?.length ?? 0}');
      } else {
        print('⚠️  Status endpoint returned: ${response.statusCode}');
      }
      
      client.close();
      
    } catch (e) {
      print('❌ HTTP endpoint test failed: $e');
    }
  }
  
  static Future<void> _testClientConnection() async {
    print('\n📱 Testing client connection functionality...');
    
    try {
      // Get the connection info from our running server
      final connectionInfo = await SocketService.getHostConnectionInfo();
      
      // Test connecting as a client to our own server
      final connected = await SocketService.connect(
        connectionInfo['serverIp'],
        connectionInfo['port'],
        connectionInfo['accessCode'],
      );
      
      if (connected) {
        print('✅ Client connection successful');
        
        // Test manual sync
        final syncResult = await SocketService.manualSync();
        print('✅ Manual sync test: ${syncResult ? 'Success' : 'Failed'}');
        
        // Get connection status
        final status = SocketService.getConnectionStatus();
        print('📊 Connection status:');
        status.forEach((key, value) => print('  $key: $value'));
        
      } else {
        print('❌ Client connection failed');
      }
      
    } catch (e) {
      print('❌ Client connection test failed: $e');
    }
  }
  
  static Future<void> _testFirewallAndPorts() async {
    print('\n🔥 Testing firewall and port accessibility...');
    
    try {
      // Test if port is actually accessible from outside
      final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, testPort + 1);
      print('✅ Port ${testPort + 1} is available for binding');
      await serverSocket.close();
      
      // Test actual server port
      try {
        final client = HttpClient();
        final connectionInfo = await SocketService.getHostConnectionInfo();
        
        final request = await client.getUrl(Uri.parse('${connectionInfo['url']}/status'));
        request.headers.set('X-Access-Code', connectionInfo['accessCode']);
        
        final response = await request.close();
        
        if (response.statusCode == 200) {
          print('✅ Server port $testPort is accessible via HTTP');
        } else {
          print('⚠️  Server responded with status: ${response.statusCode}');
        }
        
        client.close();
      } catch (e) {
        print('❌ Server port accessibility test failed: $e');
      }
      
    } catch (e) {
      print('❌ Port binding test failed: $e');
      print('💡 This might indicate a firewall or permission issue');
    }
  }
  
  static Future<void> _testCrossDeviceCommunication() async {
    print('\n🔄 Testing cross-device communication simulation...');
    
    try {
      // Simulate database changes and verify they would be broadcast
      print('📝 Simulating database change...');
      
      // Create a test record
      final testData = {
        'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Connection Test Patient',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Notify the server of a database change
      await EnhancedShelfServer.onDatabaseChange(
        'patients',
        'INSERT',
        testData['id'] as String,
        testData,
      );
      
      print('✅ Database change notification sent');
      
      // Check server statistics
      final stats = EnhancedShelfServer.getServerStatistics();
      print('📈 Server statistics:');
      stats.forEach((key, value) => print('  $key: $value'));
      
    } catch (e) {
      print('❌ Cross-device communication test failed: $e');
    }
  }
  
  static bool _isLanIp(String ip) {
    if (ip == 'localhost' || ip == '127.0.0.1') return true;
    if (ip.startsWith('192.168.68.')) return true; // Your specific network
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        return second != null && second >= 16 && second <= 31;
      }
    }
    return false;
  }
  
  static Future<void> cleanup() async {
    print('\n🧹 Cleaning up test environment...');
    
    try {
      await SocketService.disconnect();
      await SocketService.stopHosting();
      print('✅ Cleanup completed');
    } catch (e) {
      print('⚠️  Cleanup warning: $e');
    }
  }
}

// Run the test when executed directly
void main() async {
  await ConnectionTest.main();
  await ConnectionTest.cleanup();
}
