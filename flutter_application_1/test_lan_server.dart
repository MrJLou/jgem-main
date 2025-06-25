import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final String serverIp = '192.168.68.115';
  final int port = 8080;
  final String accessCode = 'xoJDEASe';

  print('=== LAN Server Connectivity Test ===');
  print('Testing connection to $serverIp:$port');
  print('Access Code: $accessCode');
  print('');

  // Test 1: Basic socket connectivity
  print('1. Testing basic socket connectivity...');
  try {
    final socket = await Socket.connect(serverIp, port, timeout: Duration(seconds: 5));
    socket.destroy();
    print('✓ Socket connection successful');
  } catch (e) {
    print('✗ Socket connection failed: $e');
    return;
  }

  // Test 2: HTTP status endpoint (no auth required)
  print('\n2. Testing HTTP status endpoint (no auth)...');
  try {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 10);
    
    final request = await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
    final response = await request.close();
    
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('✓ Status code: ${response.statusCode}');
    print('✓ Response body: $responseBody');
    
    client.close();
  } catch (e) {
    print('✗ HTTP status request failed: $e');
  }

  // Test 3: HTTP status endpoint with auth
  print('\n3. Testing HTTP status endpoint (with auth)...');
  try {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 10);
    
    final request = await client.getUrl(Uri.parse('http://$serverIp:$port/status'));
    request.headers.add('Authorization', 'Bearer $accessCode');
    final response = await request.close();
    
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('✓ Status code: ${response.statusCode}');
    print('✓ Response body: $responseBody');
    
    client.close();
  } catch (e) {
    print('✗ HTTP status request with auth failed: $e');
  }

  // Test 4: Test database endpoint (requires auth)
  print('\n4. Testing database endpoint (requires auth)...');
  try {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 10);
    
    final request = await client.getUrl(Uri.parse('http://$serverIp:$port/db'));
    request.headers.add('Authorization', 'Bearer $accessCode');
    final response = await request.close();
    
    print('✓ DB endpoint status code: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('✓ Database endpoint accessible');
    } else {
      final responseBody = await response.transform(utf8.decoder).join();
      print('✗ DB endpoint error: $responseBody');
    }
    
    client.close();
  } catch (e) {
    print('✗ Database endpoint request failed: $e');
  }

  // Test 5: Check network interfaces
  print('\n5. Checking local network interfaces...');
  try {
    final interfaces = await NetworkInterface.list();
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          print('Interface ${interface.name}: ${addr.address}');
        }
      }
    }
  } catch (e) {
    print('✗ Failed to list network interfaces: $e');
  }

  print('\n=== Test Complete ===');
}
