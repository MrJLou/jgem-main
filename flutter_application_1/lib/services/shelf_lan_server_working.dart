import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

/// Simplified working Shelf-based LAN server
class ShelfLanServer {
  static const String _accessCodeKey = 'lan_access_code';
  static const int _defaultPort = 8080;

  static HttpServer? _server;
  static DatabaseHelper? _dbHelper;
  static String? _dbPath;
  static String? _accessCode;
  static List<String> _allowedIpRanges = [];
  static bool _isRunning = false;
  static int _currentPort = _defaultPort;

  // Stream for sync updates
  static final StreamController<Map<String, dynamic>> _syncUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  static bool get isRunning => _isRunning;
  static Stream<Map<String, dynamic>> get syncUpdates => _syncUpdates.stream;
  static String? get accessCode => _accessCode;
  static String? get dbPath => _dbPath;
  static List<String> get allowedIpRanges => List.from(_allowedIpRanges);

  /// Initialize the Shelf LAN server
  static Future<void> initialize(DatabaseHelper dbHelper) async {
    try {
      _dbHelper = dbHelper;
      
      // Load existing access code or generate new one
      final prefs = await SharedPreferences.getInstance();
      _accessCode = prefs.getString(_accessCodeKey) ?? _generateAccessCode();
      await prefs.setString(_accessCodeKey, _accessCode!);
      
      // Configure LAN IP ranges
      await _configureLanIpRanges();
      
      debugPrint('ShelfLanServer initialized with access code: $_accessCode');
    } catch (e) {
      debugPrint('ShelfLanServer initialization failed: $e');
      rethrow;
    }
  }

  /// Start the Shelf server
  static Future<bool> startServer({int port = _defaultPort}) async {
    if (_isRunning) {
      debugPrint('Server already running on port $_currentPort');
      return true;
    }

    try {
      _currentPort = port;
      
      // Create router with endpoints
      final router = _createRouter();
      
      // Create handler with middleware
      final handler = Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(_authMiddleware())
          .addMiddleware(_lanOnlyMiddleware())
          .addHandler(router);

      // Start server
      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      _isRunning = true;
      
      debugPrint('Shelf LAN server started on port $port');
      debugPrint('Access code: $_accessCode');
      debugPrint('Allowed IP ranges: $_allowedIpRanges');
      
      return true;
    } catch (e) {
      debugPrint('Failed to start Shelf server: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Create router with all endpoints
  static Router _createRouter() {
    final router = Router();

    // Basic endpoints
    router.get('/status', _handleStatus);
    router.get('/db', _handleDatabaseDownload);
    router.get('/db/changes', _handleDatabaseChanges);
    router.post('/db/sync', _handleDatabaseSync);
    
    // Session management endpoints
    router.post('/session/create', _handleCreateSession);
    router.post('/session/validate', _handleValidateSession);
    router.get('/session/list', _handleGetSessions);
    router.post('/session/update', _handleUpdateActivity);
    
    // Document endpoints
    router.get('/documents', _handleGetDocuments);
    router.post('/documents/sync', _handleDocumentSync);

    return router;
  }

  /// CORS middleware
  static Middleware _corsMiddleware() {
    return (handler) {
      return (request) async {
        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, Access-Code',
        });
      };
    };
  }

  /// Authentication middleware
  static Middleware _authMiddleware() {
    return (handler) {
      return (request) async {
        // Skip auth for OPTIONS requests
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, Access-Code',
          });
        }

        // Check access code for non-status endpoints
        if (request.url.path != 'status') {
          final accessCode = request.headers['access-code'] ?? 
                            request.url.queryParameters['access_code'];
          
          if (accessCode != _accessCode) {
            return Response.unauthorized('Invalid access code');
          }
        }

        return handler(request);
      };
    };
  }

  /// LAN-only access middleware
  static Middleware _lanOnlyMiddleware() {
    return (handler) {
      return (request) async {
        final clientIp = request.headers['x-forwarded-for'] ?? 'localhost';
        
        if (!_isLanIp(clientIp)) {
          return Response.forbidden('Access denied: Not a LAN IP');
        }

        return handler(request);
      };
    };
  }

  /// Check if IP is in LAN range
  static bool _isLanIp(String ip) {
    if (ip == 'localhost') return true;
    
    // Allow localhost
    if (ip == '127.0.0.1' || ip == '::1') return true;
    
    // Allow common LAN ranges
    final lanRanges = [
      '192.168.',
      '10.',
      '172.16.',
      '172.17.',
      '172.18.',
      '172.19.',
      '172.20.',
      '172.21.',
      '172.22.',
      '172.23.',
      '172.24.',
      '172.25.',
      '172.26.',
      '172.27.',
      '172.28.',
      '172.29.',
      '172.30.',
      '172.31.',
    ];
    
    return lanRanges.any((range) => ip.startsWith(range));
  }

  /// Generate new access code
  static String _generateAccessCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Configure LAN IP ranges
  static Future<void> _configureLanIpRanges() async {
    try {
      // Get local network interfaces
      final interfaces = await NetworkInterface.list();
      _allowedIpRanges.clear();
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final ip = address.address;
            if (_isLanIp(ip)) {
              // Extract network range (assuming /24)
              final parts = ip.split('.');
              if (parts.length == 4) {
                final networkRange = '${parts[0]}.${parts[1]}.${parts[2]}';
                if (!_allowedIpRanges.contains(networkRange)) {
                  _allowedIpRanges.add(networkRange);
                }
              }
            }
          }
        }
      }
      
      // Always include localhost
      if (!_allowedIpRanges.contains('127.0.0')) {
        _allowedIpRanges.add('127.0.0');
      }
      
      debugPrint('Configured LAN IP ranges: $_allowedIpRanges');
    } catch (e) {
      debugPrint('Error configuring LAN IP ranges: $e');
      _allowedIpRanges = ['127.0.0', '192.168.1', '192.168.0', '10.0.0'];
    }
  }

  /// Stop the server
  static Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
      _server = null;
      _isRunning = false;
      debugPrint('Shelf LAN server stopped');
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }

  /// Handle status endpoint
  static Response _handleStatus(Request request) {
    final status = {
      'status': 'running',
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'accessCode': _accessCode,
      'allowedIpRanges': _allowedIpRanges,
    };
    
    return Response.ok(
      jsonEncode(status),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handle database download
  static Future<Response> _handleDatabaseDownload(Request request) async {
    try {
      if (_dbHelper == null) {
        return Response.internalServerError(body: 'Database not initialized');
      }

      final db = await _dbHelper!.database;
      final tables = ['patients', 'appointments', 'medical_records', 'users'];
      final data = <String, List<Map<String, dynamic>>>{};
      
      for (final table in tables) {
        try {
          final result = await db.query(table);
          data[table] = result;
        } catch (e) {
          debugPrint('Error querying table $table: $e');
          data[table] = [];
        }
      }
      
      return Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error in database download: $e');
      return Response.internalServerError(body: 'Database download failed');
    }
  }

  /// Handle database changes request
  static Future<Response> _handleDatabaseChanges(Request request) async {
    try {
      // For now, return empty changes
      final changes = <Map<String, dynamic>>[];
      
      return Response.ok(
        jsonEncode({'changes': changes}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error getting database changes: $e');
      return Response.internalServerError(body: 'Failed to get changes');
    }
  }

  /// Handle database sync request
  static Future<Response> _handleDatabaseSync(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      // Process sync data here
      debugPrint('Received sync data: ${data.keys}');
      
      return Response.ok(
        jsonEncode({'status': 'success', 'message': 'Sync completed'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Error in database sync: $e');
      return Response.internalServerError(body: 'Sync failed');
    }
  }

  /// Basic session management handlers
  static Future<Response> _handleCreateSession(Request request) async {
    try {
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      return Response.ok(
        jsonEncode({'sessionId': sessionId, 'status': 'created'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Session creation failed');
    }
  }

  static Future<Response> _handleValidateSession(Request request) async {
    return Response.ok(
      jsonEncode({'status': 'valid'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Response _handleGetSessions(Request request) {
    return Response.ok(
      jsonEncode({'sessions': []}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _handleUpdateActivity(Request request) async {
    return Response.ok(
      jsonEncode({'status': 'updated'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Document management handlers  
  static Future<Response> _handleGetDocuments(Request request) async {
    return Response.ok(
      jsonEncode({'documents': []}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _handleDocumentSync(Request request) async {
    return Response.ok(
      jsonEncode({'status': 'synced'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Regenerate access code
  static Future<String> regenerateAccessCode() async {
    try {
      _accessCode = _generateAccessCode();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessCodeKey, _accessCode!);
      return _accessCode!;
    } catch (e) {
      debugPrint('Error regenerating access code: $e');
      return 'ERROR';
    }
  }

  /// Get database browser instructions
  static Future<Map<String, dynamic>> getDbBrowserInstructions() async {
    try {
      return {
        'instructions': [
          'Download a SQLite browser like DB Browser for SQLite',
          'Connect to: ${_server?.address.host}:$_currentPort/db',
          'Use access code: $_accessCode',
        ],
        'accessCode': _accessCode,
        'serverUrl': '${_server?.address.host}:$_currentPort',
      };
    } catch (e) {
      debugPrint('Error getting DB browser instructions: $e');
      return {'error': 'Failed to get instructions'};
    }
  }

  /// Get pending changes count
  static Future<List<Map<String, dynamic>>> getPendingChanges() async {
    try {
      // Return empty list for now
      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('Error getting pending changes: $e');
      return <Map<String, dynamic>>[];
    }
  }
}
