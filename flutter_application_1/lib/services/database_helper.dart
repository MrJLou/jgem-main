import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/appointment.dart';
import 'package:http/http.dart' as http;

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  final String _databaseName = 'patient_management.db';
  final int _databaseVersion = 1;

  // Database sync settings
  final String _syncUrl =
      'http://192.168.1.100:8000/sync'; // Change to your server IP
  final String _deviceId = DateTime.now().millisecondsSinceEpoch.toString();
  final String _syncTimeKey = 'last_sync_time';

  // Tables
  final String tableUsers = 'users';
  final String tablePatients = 'patients';
  final String tableAppointments = 'appointments';
  final String tableMedicalRecords = 'medical_records';
  final String tableSyncLog = 'sync_log';

  // Getters for database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path;

    try {
      // Try to get a platform-appropriate directory
      if (!kIsWeb && Platform.isAndroid) {
        // Try to use external storage on Android if available
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            path = join(externalDir.path, _databaseName);
          } else {
            final docDir = await getApplicationDocumentsDirectory();
            path = join(docDir.path, _databaseName);
          }
        } catch (e) {
          // Fallback to app documents directory
          final docDir = await getApplicationDocumentsDirectory();
          path = join(docDir.path, _databaseName);
        }
      } else {
        // For iOS, desktop, web
        final docDir = await getApplicationDocumentsDirectory();
        path = join(docDir.path, _databaseName);
      }
    } catch (e) {
      // Ultimate fallback
      final docDir = await getApplicationDocumentsDirectory();
      path = join(docDir.path, _databaseName);
      print('Using default database path: $path');
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE $tableUsers (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        fullName TEXT NOT NULL,
        role TEXT NOT NULL,
        securityQuestion TEXT NOT NULL,
        securityAnswer TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Patients table
    await db.execute('''
      CREATE TABLE $tablePatients (
        id TEXT PRIMARY KEY,
        fullName TEXT NOT NULL,
        birthDate TEXT NOT NULL,
        gender TEXT NOT NULL,
        contactNumber TEXT,
        address TEXT,
        bloodType TEXT,
        allergies TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Appointments table
    await db.execute('''
      CREATE TABLE $tableAppointments (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        patientName TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        doctor TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id)
      )
    ''');

    // Medical Records table
    await db.execute('''
      CREATE TABLE $tableMedicalRecords (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        recordType TEXT NOT NULL,
        recordDate TEXT NOT NULL,
        diagnosis TEXT,
        treatment TEXT,
        prescription TEXT,
        labResults TEXT,
        notes TEXT,
        doctorId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id),
        FOREIGN KEY (doctorId) REFERENCES $tableUsers (id)
      )
    ''');

    // Sync Log table for tracking changes
    await db.execute('''
      CREATE TABLE $tableSyncLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT NOT NULL,
        recordId TEXT NOT NULL,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create admin user by default
    await _createDefaultAdmin(db);
  }

  // Database upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Example migration for future versions
    }
  }

  // Create default admin user
  Future<void> _createDefaultAdmin(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Hash the default admin password
    final String hashedPassword = AuthService.hashPassword('admin123');

    await db.insert(tableUsers, {
      'id': 'admin-${DateTime.now().millisecondsSinceEpoch}',
      'username': 'admin',
      'password': hashedPassword, // Store hashed password
      'fullName': 'System Administrator',
      'role': 'admin',
      'securityQuestion': 'What is the default password?',
      'securityAnswer': 'admin123',
      'createdAt': now
    });
  }

  // USER MANAGEMENT METHODS

  // Insert user
  Future<User> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    user['id'] = 'user-${DateTime.now().millisecondsSinceEpoch}';
    user['createdAt'] = DateTime.now().toIso8601String();

    await db.insert(tableUsers, user);
    await _logChange(tableUsers, user['id'], 'insert');

    return User.fromJson(user);
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUsers,
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  // Update user
  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    final result = await db.update(
      tableUsers,
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );

    await _logChange(tableUsers, user['id'], 'update');
    return result;
  }

  // Delete user
  Future<int> deleteUser(String id) async {
    final db = await database;
    final result = await db.delete(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logChange(tableUsers, id, 'delete');
    return result;
  }

  // Get all users
  Future<List<User>> getUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableUsers);

    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  // Authentication
  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    final db = await database;

    // First retrieve the user to get the hashed password
    final List<Map<String, dynamic>> result = await db.query(
      tableUsers,
      where: 'username = ?',
      whereArgs: [username],
    );

    if (result.isEmpty) {
      return null; // User not found
    }

    final user = result.first;
    final String hashedPassword = user['password'];

    // Verify the password using bcrypt
    final bool isPasswordValid =
        AuthService.verifyPassword(password, hashedPassword);

    if (isPasswordValid) {
      return {
        'token': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'user': user,
      };
    }

    return null; // Password didn't match
  }

  // Update the resetPassword method to use bcrypt
  Future<bool> resetPassword(String username, String securityQuestion,
      String securityAnswer, String newPassword) async {
    final db = await database;

    // First verify security question and answer
    final List<Map<String, dynamic>> users = await db.query(
      tableUsers,
      where: 'username = ? AND securityQuestion = ?',
      whereArgs: [username, securityQuestion],
    );

    if (users.isEmpty) {
      return false;
    }

    // Verify security answer (which might be hashed)
    final savedAnswer = users.first['securityAnswer'];
    bool isAnswerCorrect;

    // Check if the answer is hashed
    if (savedAnswer.startsWith('\$2')) {
      // BCrypt hash starts with $2
      isAnswerCorrect =
          AuthService.verifySecurityAnswer(securityAnswer, savedAnswer);
    } else {
      // Plain text comparison (for backward compatibility)
      isAnswerCorrect = securityAnswer.trim().toLowerCase() ==
          savedAnswer.trim().toLowerCase();
    }

    if (!isAnswerCorrect) {
      return false;
    }

    // Hash the new password
    final String hashedPassword = AuthService.hashPassword(newPassword);

    // Update with hashed password
    await db.update(
      tableUsers,
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [users.first['id']],
    );

    await _logChange(tableUsers, users.first['id'], 'update');
    return true;
  }

  // PATIENT MANAGEMENT METHODS

  // Insert patient
  Future<String> insertPatient(Map<String, dynamic> patient) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    patient['id'] = 'patient-${DateTime.now().millisecondsSinceEpoch}';
    patient['createdAt'] = now;
    patient['updatedAt'] = now;

    await db.insert(tablePatients, patient);
    await _logChange(tablePatients, patient['id'], 'insert');

    return patient['id'];
  }

  // Update patient
  Future<int> updatePatient(Map<String, dynamic> patient) async {
    final db = await database;
    patient['updatedAt'] = DateTime.now().toIso8601String();

    final result = await db.update(
      tablePatients,
      patient,
      where: 'id = ?',
      whereArgs: [patient['id']],
    );

    await _logChange(tablePatients, patient['id'], 'update');
    return result;
  }

  // Delete patient
  Future<int> deletePatient(String id) async {
    final db = await database;
    final result = await db.delete(
      tablePatients,
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logChange(tablePatients, id, 'delete');
    return result;
  }

  // Get patient by ID
  Future<Map<String, dynamic>?> getPatient(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tablePatients,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Get all patients
  Future<List<Map<String, dynamic>>> getPatients() async {
    final db = await database;
    return await db.query(tablePatients);
  }

  // Search patients
  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final db = await database;
    return await db.query(
      tablePatients,
      where: 'fullName LIKE ?',
      whereArgs: ['%$query%'],
    );
  }

  // APPOINTMENT MANAGEMENT METHODS

  // Insert appointment
  Future<Appointment> insertAppointment(Appointment appointment) async {
    final db = await database;
    final appointmentMap = appointment.toJson();

    // Generate ID if not provided
    if (appointmentMap['id'] == null) {
      appointmentMap['id'] =
          'appointment-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Set created time if not provided
    if (appointmentMap['createdAt'] == null) {
      appointmentMap['createdAt'] = DateTime.now().toIso8601String();
    }

    await db.insert(tableAppointments, appointmentMap);
    await _logChange(tableAppointments, appointmentMap['id'], 'insert');

    return Appointment.fromJson(appointmentMap);
  }

  // Update appointment
  Future<int> updateAppointment(Appointment appointment) async {
    final db = await database;
    final appointmentMap = appointment.toJson();

    final result = await db.update(
      tableAppointments,
      appointmentMap,
      where: 'id = ?',
      whereArgs: [appointmentMap['id']],
    );

    await _logChange(tableAppointments, appointmentMap['id'], 'update');
    return result;
  }

  // Update appointment status
  Future<int> updateAppointmentStatus(String id, String status) async {
    final db = await database;
    final result = await db.update(
      tableAppointments,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logChange(tableAppointments, id, 'update');
    return result;
  }

  // Delete appointment
  Future<int> deleteAppointment(String id) async {
    final db = await database;
    final result = await db.delete(
      tableAppointments,
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logChange(tableAppointments, id, 'delete');
    return result;
  }

  // Get appointments by date
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> maps = await db.query(
      tableAppointments,
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );

    return List.generate(maps.length, (i) {
      return Appointment.fromJson(maps[i]);
    });
  }

  // Get appointments by patient
  Future<List<Appointment>> getPatientAppointments(String patientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableAppointments,
      where: 'patientId = ?',
      whereArgs: [patientId],
    );

    return List.generate(maps.length, (i) {
      return Appointment.fromJson(maps[i]);
    });
  }

  // MEDICAL RECORDS METHODS

  // Insert medical record
  Future<String> insertMedicalRecord(Map<String, dynamic> record) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    record['id'] = 'record-${DateTime.now().millisecondsSinceEpoch}';
    record['createdAt'] = now;
    record['updatedAt'] = now;

    await db.insert(tableMedicalRecords, record);
    await _logChange(tableMedicalRecords, record['id'], 'insert');

    return record['id'];
  }

  // Update medical record
  Future<int> updateMedicalRecord(Map<String, dynamic> record) async {
    final db = await database;
    record['updatedAt'] = DateTime.now().toIso8601String();

    final result = await db.update(
      tableMedicalRecords,
      record,
      where: 'id = ?',
      whereArgs: [record['id']],
    );

    await _logChange(tableMedicalRecords, record['id'], 'update');
    return result;
  }

  // Get medical records by patient
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(
      String patientId) async {
    final db = await database;
    return await db.query(
      tableMedicalRecords,
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'recordDate DESC',
    );
  }

  // DATABASE SYNCHRONIZATION METHODS

  // Log changes for synchronization
  Future<void> _logChange(
      String tableName, String recordId, String action) async {
    final db = await database;
    await db.insert(tableSyncLog, {
      'tableName': tableName,
      'recordId': recordId,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  // Get pending changes for sync
  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    final db = await database;
    return await db.query(
      tableSyncLog,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  // Mark changes as synced
  Future<void> markChangesAsSynced(List<int> ids) async {
    final db = await database;
    final batch = db.batch();

    for (int id in ids) {
      batch.update(
        tableSyncLog,
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit();
  }

  // Sync with server
  Future<bool> syncWithServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTime =
          prefs.getString(_syncTimeKey) ?? '1970-01-01T00:00:00.000Z';

      // Get pending changes
      final pendingChanges = await getPendingChanges();
      final changeIds = pendingChanges.map((c) => c['id'] as int).toList();

      // Prepare data for sending
      final syncData = {
        'deviceId': _deviceId,
        'lastSyncTime': lastSyncTime,
        'changes': pendingChanges,
      };

      // Send changes to server
      final response = await http.post(
        Uri.parse(_syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(syncData),
      );

      if (response.statusCode == 200) {
        // Process server response
        final serverData = jsonDecode(response.body);

        // Apply server changes locally
        await _applyServerChanges(serverData['changes']);

        // Mark local changes as synced
        await markChangesAsSynced(changeIds);

        // Update last sync time
        await prefs.setString(_syncTimeKey, DateTime.now().toIso8601String());

        return true;
      }
      return false;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }

  // Apply changes from server
  Future<void> _applyServerChanges(List<dynamic> changes) async {
    final db = await database;
    final batch = db.batch();

    for (final change in changes) {
      final String tableName = change['tableName'];
      final String recordId = change['recordId'];
      final String action = change['action'];
      final Map<String, dynamic> data = change['data'];

      switch (action) {
        case 'insert':
          batch.insert(tableName, data);
          break;
        case 'update':
          batch.update(
            tableName,
            data,
            where: 'id = ?',
            whereArgs: [recordId],
          );
          break;
        case 'delete':
          batch.delete(
            tableName,
            where: 'id = ?',
            whereArgs: [recordId],
          );
          break;
      }
    }

    await batch.commit();
  }

  // Export database for sharing - platform-safe implementation
  Future<String> exportDatabase() async {
    try {
      // Get current database path
      final db = await database;
      final String dbPath = db.path;

      // Try to copy to a shared location if possible
      if (!kIsWeb && Platform.isAndroid) {
        try {
          Directory? directory;

          // Try to use external storage if available
          try {
            directory = await getExternalStorageDirectory();
          } catch (e) {
            print('External storage not available: $e');
            // Fall back to application documents directory
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            final exportPath = join(directory.path, 'exported_$_databaseName');
            final File dbFile = File(dbPath);

            if (await dbFile.exists()) {
              await dbFile.copy(exportPath);
              return exportPath;
            }
          }
        } catch (e) {
          print('Error exporting to external location: $e');
          // Continue with original path
        }
      }

      // Return original path if we couldn't copy
      return dbPath;
    } catch (e) {
      print('Database export error: $e');
      throw Exception('Failed to export database: $e');
    }
  }

  // Safe implementation for network sharing info
  Future<Map<String, String>> getNetworkSharingInfo() async {
    final Map<String, String> info = {};

    try {
      // Get device IP addresses safely
      if (!kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isMacOS ||
              Platform.isWindows ||
              Platform.isLinux)) {
        try {
          final interfaces = await NetworkInterface.list();
          final ipAddresses = <String>[];

          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4) {
                ipAddresses.add('${addr.address} (${interface.name})');
              }
            }
          }

          info['ipAddresses'] = ipAddresses.join(', ');
        } catch (e) {
          info['ipAddresses'] = 'Unable to determine IP: $e';
        }
      } else {
        info['ipAddresses'] = 'IP detection not supported on this platform';
      }

      // Get database path safely
      try {
        final dbPath = await exportDatabase();
        info['databasePath'] = dbPath;
      } catch (e) {
        info['databasePath'] = 'Unable to share database: $e';
      }

      return info;
    } catch (e) {
      return {
        'error': 'Failed to get network sharing info: $e',
        'ipAddresses': 'Unknown',
        'databasePath': 'Unknown'
      };
    }
  }

  // Platform-safe version of setupLiveDbBrowserView
  Future<Map<String, String>> setupLiveDbBrowserView() async {
    try {
      // Get database path safely
      final dbPath = await exportDatabase();

      // Return instructions as a map
      return {
        'status': 'success',
        'databasePath': dbPath,
        'instructions': '''
To view live changes in DB Browser:
1. Open DB Browser for SQLite
2. Select "Open Database" and navigate to: $dbPath
3. Set to "Read and Write" mode
4. Check "Keep updating the SQL view as the database changes"
'''
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to set up DB Browser view: $e',
      };
    }
  }
}
