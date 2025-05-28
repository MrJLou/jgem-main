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

  // Instance variables for the database and its path
  Database? _instanceDatabase;
  String? _instanceDbPath;

  final String _databaseName = 'patient_management.db';
  final int _databaseVersion = 7;

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
  final String tableClinicServices = 'clinic_services';
  final String tableUserActivityLog = 'user_activity_log';
  final String tablePatientBills = 'patient_bills';
  final String tableBillItems = 'bill_items';
  final String tablePayments = 'payments';
  final String tableSyncLog = 'sync_log';

  // Completer to manage database initialization
  Completer<Database>? _dbOpenCompleter;

  // Getter for database instance
  Future<Database> get database async {
    // 1. If already initialized and open, return immediately.
    if (_instanceDatabase != null && _instanceDatabase!.isOpen) {
      return _instanceDatabase!;
    }

    // 2. If initialization is currently in progress, return its future.
    if (_dbOpenCompleter != null) {
      return _dbOpenCompleter!.future;
    }

    // 3. Start new initialization.
    _dbOpenCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _instanceDatabase = db; // Store the successfully opened database.
      _dbOpenCompleter!.complete(db);
    } catch (e) {
      print('DATABASE_HELPER: Database initialization failed: $e');
      _dbOpenCompleter!.completeError(e);
      // Reset completer AND instanceDatabase on failure to allow a subsequent attempt to re-initialize.
      _dbOpenCompleter = null;
      _instanceDatabase = null;
      rethrow; // Propagate the error.
    }
    // Return the future from the completer.
    return _dbOpenCompleter!.future;
  }

  // Public getter for the current database path
  Future<String?> get currentDatabasePath async {
    if (_instanceDbPath == null) {
      // If path is not set, ensure database is initialized by calling the database getter
      await database;
    }
    return _instanceDbPath;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path;

    // Check if running on Windows and apply custom path
    if (!kIsWeb && Platform.isWindows) {
      path =
          'C:\\Users\\jesie\\Documents\\jgem-softeng\\jgem-main\\$_databaseName';
      print('DATABASE_HELPER: Using custom Windows path: $path');
    } else {
      // Existing logic for other platforms (Android, iOS, macOS, Linux)
      try {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              path = join(externalDir.path, _databaseName);
            } else {
              final docDir = await getApplicationDocumentsDirectory();
              path = join(docDir.path, _databaseName);
            }
          } catch (e) {
            final docDir = await getApplicationDocumentsDirectory();
            path = join(docDir.path, _databaseName);
            print(
                'DATABASE_HELPER: Error accessing external storage, using app docs dir. Error: $e');
          }
        } else {
          // For iOS, macOS, Linux (non-Android mobile/desktop)
          final docDir = await getApplicationDocumentsDirectory();
          path = join(docDir.path, _databaseName);
        }
      } catch (e) {
        // Ultimate fallback if path_provider fails for some reason on non-Windows
        final docDir = await getApplicationDocumentsDirectory();
        path = join(docDir.path, _databaseName);
        print(
            'DATABASE_HELPER: Error determining optimal path, using default app docs dir. Error: $e');
      }
    }

    _instanceDbPath = path; // Store the determined path

    // Ensure the directory exists before opening the database
    try {
      final Directory directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print(
            'DATABASE_HELPER: Created directory for database at ${directory.path}');
      }
    } catch (e) {
      print(
          'DATABASE_HELPER: Error creating directory for database. Error: $e');
      // Depending on the error, you might want to throw it or handle it differently
    }

    print(
        '********************************************************************************');
    print('DATABASE_HELPER: Initializing database at path:');
    print(_instanceDbPath);
    print(
        '********************************************************************************');

    // DEVELOPMENT ONLY: Force delete database to ensure _onCreate runs
    // final dbFile = File(_instanceDbPath!);
    // if (await dbFile.exists()) {
    //   await dbFile.delete();
    //   print(
    //       'DEVELOPMENT: Deleted existing database at $_instanceDbPath to ensure schema recreation.');
    // }
    // END DEVELOPMENT ONLY SECTION

    return await openDatabase(
      _instanceDbPath!,
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
        securityQuestion1 TEXT NOT NULL,
        securityAnswer1 TEXT NOT NULL,
        securityQuestion2 TEXT NOT NULL,
        securityAnswer2 TEXT NOT NULL,
        securityQuestion3 TEXT NOT NULL,
        securityAnswer3 TEXT NOT NULL,
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

    // Appointments table (Updated Schema)
    await db.execute('''
      CREATE TABLE $tableAppointments (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        doctorId TEXT NOT NULL, 
        serviceId TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        createdById TEXT NOT NULL, 
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE,
        FOREIGN KEY (doctorId) REFERENCES $tableUsers (id),
        FOREIGN KEY (serviceId) REFERENCES $tableClinicServices (id),
        FOREIGN KEY (createdById) REFERENCES $tableUsers (id)
      )
    ''');

    // Medical Records table
    await db.execute('''
      CREATE TABLE $tableMedicalRecords (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        appointmentId TEXT,
        serviceId TEXT,
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
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE,
        FOREIGN KEY (appointmentId) REFERENCES $tableAppointments (id) ON DELETE SET NULL,
        FOREIGN KEY (serviceId) REFERENCES $tableClinicServices (id) ON DELETE SET NULL,
        FOREIGN KEY (doctorId) REFERENCES $tableUsers (id)
      )
    ''');

    // Clinic Services table (New)
    await db.execute('''
      CREATE TABLE $tableClinicServices (
        id TEXT PRIMARY KEY,
        serviceName TEXT NOT NULL UNIQUE,
        description TEXT,
        category TEXT,
        defaultPrice REAL
      )
    ''');
    // User Activity Log table (New)
    await db.execute('''
      CREATE TABLE $tableUserActivityLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        actionDescription TEXT NOT NULL,
        targetRecordId TEXT,
        targetTable TEXT,
        timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        details TEXT, 
        FOREIGN KEY (userId) REFERENCES $tableUsers (id)
      )
    ''');

    // Patient Bills table (New)
    await db.execute('''
      CREATE TABLE $tablePatientBills (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        billDate TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        status TEXT NOT NULL, -- 'Unpaid', 'Paid', 'PartiallyPaid'
        notes TEXT,
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE
      )
    ''');

    // Bill Items table (New)
    await db.execute('''
      CREATE TABLE $tableBillItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        billId TEXT NOT NULL,
        serviceId TEXT,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unitPrice REAL NOT NULL,
        itemTotal REAL NOT NULL, -- quantity * unitPrice
        FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE CASCADE,
        FOREIGN KEY (serviceId) REFERENCES $tableClinicServices (id)
      )
    ''');

    // Payments table (New)
    await db.execute('''
      CREATE TABLE $tablePayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        billId TEXT,
        patientId TEXT NOT NULL,
        paymentDate TEXT NOT NULL,
        amountPaid REAL NOT NULL,
        paymentMethod TEXT NOT NULL, -- 'Cash', 'Card Terminal'
        receivedByUserId TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE SET NULL,
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id),
        FOREIGN KEY (receivedByUserId) REFERENCES $tableUsers (id)
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

    // Create Indexes (for new databases v7+)
    await _createIndexes(db);
  }

  // Database upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      await _addColumnIfNotExists(
          db, tableUsers, 'securityQuestion1', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, tableUsers, 'securityAnswer1', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, tableUsers, 'securityQuestion2', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, tableUsers, 'securityAnswer2', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, tableUsers, 'securityQuestion3', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, tableUsers, 'securityAnswer3', 'TEXT NOT NULL DEFAULT \'\'');
    }
    if (oldVersion < 3) {
      // Recreate appointments table with the new schema
      await db.execute('DROP TABLE IF EXISTS $tableAppointments');
      await db.execute('''
        CREATE TABLE $tableAppointments (
          id TEXT PRIMARY KEY,
          patientId TEXT NOT NULL,
          date TEXT NOT NULL,
          time TEXT NOT NULL,
          doctorId TEXT NOT NULL, 
          serviceId TEXT, 
          status TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL,
          createdById TEXT NOT NULL, 
          FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE,
          FOREIGN KEY (doctorId) REFERENCES $tableUsers (id),
          FOREIGN KEY (serviceId) REFERENCES $tableClinicServices (id),
          FOREIGN KEY (createdById) REFERENCES $tableUsers (id)
        )
      ''');
      // Add new columns to medical_records table
      await _addColumnIfNotExists(
          db, tableMedicalRecords, 'appointmentId', 'TEXT');
      await _addColumnIfNotExists(db, tableMedicalRecords, 'serviceId', 'TEXT');
      // If you needed to add FK constraints here to an existing table, it's more complex in SQLite.
      // Typically involves renaming table, creating new table with FK, copying data, deleting old table.
      // For TEXT columns added like this, the FKs in the CREATE TABLE statement (_onCreate) will apply to new DBs.
      // For existing DBs, these columns are just added as TEXT. True FK enforcement would require the complex migration.
    }
    if (oldVersion < 4) {
      // Create clinic_services table
      await db.execute('''
        CREATE TABLE $tableClinicServices (
          id TEXT PRIMARY KEY,
          serviceName TEXT NOT NULL UNIQUE,
          description TEXT,
          category TEXT,
          defaultPrice REAL
        )
      ''');
      // Note: Foreign key constraints for serviceId in appointments and medical_records
      // should ideally be added here if the tables already exist.
      // However, adding FK constraints to existing tables/columns in SQLite is complex
      // (often requires table recreation: create new, copy data, drop old, rename new).
      // The definitions in _onCreate cover new databases. For existing ones, these will behave as plain TEXT columns
      // unless a more complex migration is done.
      // The existing _onCreate already has the FKs, so new DBs are fine.
      // For existing DBs being upgraded, the serviceId columns were added in v3 as TEXT.
      // To enforce FKs on them now for existing data, one would need to:
      // 1. Read data from appointments/medical_records
      // 2. Drop appointments/medical_records
      // 3. Re-create them using the _onCreate (which includes the FK to clinic_services)
      // 4. Re-insert data (this is complex and error-prone, skipped for this step-by-step)
    }
    if (oldVersion < 5) {
      // Create user_activity_log table
      await db.execute('''
        CREATE TABLE $tableUserActivityLog (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          actionDescription TEXT NOT NULL,
          targetRecordId TEXT,
          targetTable TEXT,
          timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          details TEXT, 
          FOREIGN KEY (userId) REFERENCES $tableUsers (id)
        )
      ''');
    }
    if (oldVersion < 6) {
      // Create billing tables
      await db.execute('''
        CREATE TABLE $tablePatientBills (
          id TEXT PRIMARY KEY,
          patientId TEXT NOT NULL,
          billDate TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          status TEXT NOT NULL, 
          notes TEXT,
          FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE $tableBillItems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          billId TEXT NOT NULL,
          serviceId TEXT,
          description TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          unitPrice REAL NOT NULL,
          itemTotal REAL NOT NULL, 
          FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE CASCADE,
          FOREIGN KEY (serviceId) REFERENCES $tableClinicServices (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE $tablePayments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          billId TEXT,
          patientId TEXT NOT NULL,
          paymentDate TEXT NOT NULL,
          amountPaid REAL NOT NULL,
          paymentMethod TEXT NOT NULL, 
          receivedByUserId TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE SET NULL,
          FOREIGN KEY (patientId) REFERENCES $tablePatients (id),
          FOREIGN KEY (receivedByUserId) REFERENCES $tableUsers (id)
        )
      ''');
    }
    if (oldVersion < 7) {
      // Add indexes if upgrading from a version older than 7
      await _createIndexes(db);
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added Indexes.');
    }
  }

  Future<void> _addColumnIfNotExists(DatabaseExecutor db, String tableName,
      String columnName, String columnTypeWithConstraints) async {
    var result = await db.rawQuery('PRAGMA table_info($tableName)');
    bool columnExists = result.any((column) => column['name'] == columnName);
    if (!columnExists) {
      await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $columnName $columnTypeWithConstraints');
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
      'securityQuestion1': 'What is your favorite color?',
      'securityAnswer1': AuthService.hashSecurityAnswer('blue'),
      'securityQuestion2': 'In what city were you born?',
      'securityAnswer2': AuthService.hashSecurityAnswer('anytown'),
      'securityQuestion3': 'What is your oldest sibling\'s middle name?',
      'securityAnswer3': AuthService.hashSecurityAnswer('alex'),
      'createdAt': now
    });
  }

  // USER MANAGEMENT METHODS

  // Insert user
  Future<User> insertUser(Map<String, dynamic> userMap) async {
    final db = await database;
    // Ensure correct keys and handle potential nulls for NOT NULL fields
    Map<String, dynamic> dbUserMap = {
      'id': userMap['id'] ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
      'username': userMap['username'],
      'password': userMap[
          'password'], // Assuming password hashing is done before this call
      'fullName': userMap[
          'fullName'], // Corrected from 'fullname' if it was a typo source
      'role': userMap['role'],
      'securityQuestion1':
          userMap['securityQuestion1'] ?? '', // Default to empty string if null
      'securityAnswer1':
          userMap['securityAnswer1'] ?? '', // Default to empty string if null
      'securityQuestion2':
          userMap['securityQuestion2'] ?? '', // Default to empty string if null
      'securityAnswer2':
          userMap['securityAnswer2'] ?? '', // Default to empty string if null
      'securityQuestion3':
          userMap['securityQuestion3'] ?? '', // Default to empty string if null
      'securityAnswer3':
          userMap['securityAnswer3'] ?? '', // Default to empty string if null
      'createdAt': userMap['createdAt'] ?? DateTime.now().toIso8601String(),
    };

    // Validate that essential NOT NULL fields are present after defaults
    if (dbUserMap['username'] == null || dbUserMap['username'].isEmpty) {
      throw Exception("Username cannot be null or empty.");
    }
    if (dbUserMap['password'] == null || dbUserMap['password'].isEmpty) {
      throw Exception("Password cannot be null or empty.");
    }
    if (dbUserMap['fullName'] == null || dbUserMap['fullName'].isEmpty) {
      throw Exception("Full name cannot be null or empty.");
    }
    if (dbUserMap['role'] == null || dbUserMap['role'].isEmpty) {
      throw Exception("Role cannot be null or empty.");
    }
    // Security questions/answers are defaulted to empty strings, which SQLite allows for TEXT NOT NULL.

    await db.transaction((txn) async {
      await txn.insert(tableUsers, dbUserMap);
      await _logChange(tableUsers, dbUserMap['id'] as String, 'insert',
          executor: txn);
    });

    return User.fromJson(dbUserMap);
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
    late int result;
    await db.transaction((txn) async {
      result = await txn.update(
        tableUsers,
        user,
        where: 'id = ?',
        whereArgs: [user['id']],
      );
      if (result > 0) {
        // Only log if update was successful
        await _logChange(tableUsers, user['id'] as String, 'update',
            executor: txn);
      }
    });
    return result;
  }

  // Delete user
  Future<int> deleteUser(String id) async {
    final db = await database;
    late int result;
    await db.transaction((txn) async {
      result = await txn.delete(
        tableUsers,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result > 0) {
        // Only log if delete was successful
        await _logChange(tableUsers, id, 'delete', executor: txn);
      }
    });
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

  // Get user security details (questions and answers, no password)
  Future<User?> getUserSecurityDetails(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUsers,
      columns: [
        'id',
        'username',
        'fullName',
        'role',
        'securityQuestion1',
        'securityAnswer1',
        'securityQuestion2',
        'securityAnswer2',
        'securityQuestion3',
        'securityAnswer3',
        'createdAt'
      ], // Explicitly list columns, excluding password
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
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
      where: 'username = ? AND securityQuestion1 = ?',
      whereArgs: [username, securityQuestion],
    );

    if (users.isEmpty) {
      return false;
    }

    // Verify security answer (which might be hashed)
    final savedAnswer = users.first['securityAnswer1'];
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
  Future<void> _logChange(String tableName, String recordId, String action,
      {DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    await exec.insert(tableSyncLog, {
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

  // Get user activity logs
  Future<List<Map<String, dynamic>>> getUserActivityLogs() async {
    final db = await database;
    return await db.query(
      tableUserActivityLog,
      orderBy: 'timestamp DESC',
      limit: 100, // Limit to most recent 100 logs
    );
  }

  // Log user activity with UTC+8 timestamp
  Future<void> logUserActivity(String userId, String actionDescription,
      {String? targetRecordId, String? targetTable, String? details}) async {
    final db = await database;

    // Create timestamp in UTC+8
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));

    await db.insert(tableUserActivityLog, {
      'userId': userId,
      'actionDescription': actionDescription,
      'targetRecordId': targetRecordId,
      'targetTable': targetTable,
      'timestamp': now.toIso8601String(),
      'details': details,
    });
  }

  // Create indexes (helper method)
  Future<void> _createIndexes(Database db) async {
    // Indexes for users table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_username ON $tableUsers (username)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_role ON $tableUsers (role)');

    // Indexes for patients table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patients_fullName ON $tablePatients (fullName)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patients_birthDate ON $tablePatients (birthDate)');

    // Indexes for appointments table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appointments_patientId ON $tableAppointments (patientId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appointments_doctorId ON $tableAppointments (doctorId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appointments_date ON $tableAppointments (date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appointments_status ON $tableAppointments (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appointments_serviceId ON $tableAppointments (serviceId)');

    // Indexes for medical_records table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medical_records_patientId ON $tableMedicalRecords (patientId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medical_records_doctorId ON $tableMedicalRecords (doctorId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medical_records_recordType ON $tableMedicalRecords (recordType)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medical_records_recordDate ON $tableMedicalRecords (recordDate)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medical_records_appointmentId ON $tableMedicalRecords (appointmentId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medical_records_serviceId ON $tableMedicalRecords (serviceId)');

    // Indexes for clinic_services table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clinic_services_serviceName ON $tableClinicServices (serviceName)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clinic_services_category ON $tableClinicServices (category)');

    // Indexes for user_activity_log table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_activity_log_userId ON $tableUserActivityLog (userId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_activity_log_timestamp ON $tableUserActivityLog (timestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_activity_log_targetTable ON $tableUserActivityLog (targetTable)');

    // Indexes for patient_bills table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patient_bills_patientId ON $tablePatientBills (patientId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patient_bills_status ON $tablePatientBills (status)');

    // Indexes for bill_items table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_billId ON $tableBillItems (billId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_items_serviceId ON $tableBillItems (serviceId)');

    // Indexes for payments table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_billId ON $tablePayments (billId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_patientId ON $tablePayments (patientId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_receivedByUserId ON $tablePayments (receivedByUserId)');

    // Indexes for sync_log table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_tableName_recordId ON $tableSyncLog (tableName, recordId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_synced ON $tableSyncLog (synced)');

    print('DATABASE_HELPER: Ensured all indexes are created.');
  }
}
