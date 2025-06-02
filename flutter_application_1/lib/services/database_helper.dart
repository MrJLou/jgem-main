import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/user_database_service.dart';
import 'package:flutter_application_1/services/patient_database_service.dart';
import 'package:flutter_application_1/services/appointment_database_service.dart'; // Added import
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../models/appointment.dart';
import '../models/active_patient_queue_item.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal() {
    userDbService = UserDatabaseService(this);
    patientDbService = PatientDatabaseService(this);
    appointmentDbService = AppointmentDatabaseService(this); // Initialize AppointmentDatabaseService
  }

  // Instance variables for the database and its path
  Database? _instanceDatabase;
  String? _instanceDbPath;

  static const String _databaseName = 'patient_management.db';
  static const int _databaseVersion = 15;

  // Tables
  static const String tableUsers = 'users';
  static const String tablePatients = 'patients';
  static const String tableAppointments = 'appointments';
  static const String tableMedicalRecords = 'medical_records';
  static const String tableClinicServices = 'clinic_services';
  static const String tableUserActivityLog = 'user_activity_log';
  static const String tablePatientBills = 'patient_bills';
  static const String tableBillItems = 'bill_items';
  static const String tablePayments = 'payments';
  static const String tableSyncLog = 'sync_log';
  static const String tablePatientQueue = 'patient_queue';
  static const String tableActivePatientQueue = 'active_patient_queue';

  // Completer to manage database initialization
  Completer<Database>? _dbOpenCompleter;

  late final UserDatabaseService userDbService;
  late final PatientDatabaseService patientDbService;
  late final AppointmentDatabaseService appointmentDbService; // Declare AppointmentDatabaseService instance

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
      // Use a specific path in the project's parent directory for easier access during development
      path = join(await getDatabasesPath(), _databaseName); // Original usage
      // path = 'C:\\Users\\Bernie\\Documents\\jgem-main\\${DatabaseHelper._databaseName}'; // Updated usage

      // path =
      //     'C:\\Users\\jesie\\Documents\\jgem-softeng\\jgem-main\\${DatabaseHelper._databaseName}'; // Updated usage
      print('DATABASE_HELPER: Using fixed Windows path: $path');
    } else {
      // Existing logic for other platforms (Android, iOS, macOS, Linux)
      try {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              path = join(externalDir.path, DatabaseHelper._databaseName); // Updated usage
            } else {
              final docDir = await getApplicationDocumentsDirectory();
              path = join(docDir.path, DatabaseHelper._databaseName); // Updated usage
            }
          } catch (e) {
            final docDir = await getApplicationDocumentsDirectory();
            path = join(docDir.path, DatabaseHelper._databaseName); // Updated usage
            print(
                'DATABASE_HELPER: Error accessing external storage, using app docs dir. Error: $e');
          }
        } else {
          // For iOS, macOS, Linux (non-Android mobile/desktop)
          final docDir = await getApplicationDocumentsDirectory();
          path = join(docDir.path, DatabaseHelper._databaseName); // Updated usage
        }
      } catch (e) {
        // Ultimate fallback if path_provider fails for some reason on non-Windows
        final docDir = await getApplicationDocumentsDirectory();
        path = join(docDir.path, DatabaseHelper._databaseName); // Updated usage
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

    final openedDb = await openDatabase(
      _instanceDbPath!,
      version: DatabaseHelper._databaseVersion, // Updated usage
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // onOpen: (db) async { // Alternative place to clear, but doing it after ensures table exists
      //   print('DATABASE_HELPER: Clearing active_patient_queue onOpen.');
      //   await db.delete(DatabaseHelper.tableActivePatientQueue); // Updated usage
      // }
    );

    // Clear the active_patient_queue table every time the database is initialized
    // This ensures it starts fresh for the day.
    print(
        'DATABASE_HELPER: Clearing ${DatabaseHelper.tableActivePatientQueue} after DB open/creation/upgrade.'); // Updated usage
    await openedDb.delete(DatabaseHelper.tableActivePatientQueue); // Updated usage
    print('DATABASE_HELPER: ${DatabaseHelper.tableActivePatientQueue} cleared.'); // Updated usage

    return openedDb;
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableUsers} (
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
      CREATE TABLE ${DatabaseHelper.tablePatients} (
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
      CREATE TABLE ${DatabaseHelper.tableAppointments} (
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
        FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id) ON DELETE CASCADE,
        FOREIGN KEY (doctorId) REFERENCES ${DatabaseHelper.tableUsers} (id),
        FOREIGN KEY (serviceId) REFERENCES ${DatabaseHelper.tableClinicServices} (id),
        FOREIGN KEY (createdById) REFERENCES ${DatabaseHelper.tableUsers} (id)
      )
    ''');

    // Medical Records table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableMedicalRecords} (
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
        FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id) ON DELETE CASCADE,
        FOREIGN KEY (appointmentId) REFERENCES ${DatabaseHelper.tableAppointments} (id) ON DELETE SET NULL,
        FOREIGN KEY (serviceId) REFERENCES ${DatabaseHelper.tableClinicServices} (id) ON DELETE SET NULL,
        FOREIGN KEY (doctorId) REFERENCES ${DatabaseHelper.tableUsers} (id)
      )
    ''');

    // Clinic Services table (New)
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableClinicServices} (
        id TEXT PRIMARY KEY,
        serviceName TEXT NOT NULL UNIQUE,
        description TEXT,
        category TEXT,
        defaultPrice REAL
      )
    ''');
    // User Activity Log table (New)
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableUserActivityLog} (
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
        referenceNumber TEXT UNIQUE NOT NULL, -- Added for payment reference
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

    // Patient Queue Reports table (for daily history)
    await db.execute('''
      CREATE TABLE $tablePatientQueue (
        id TEXT PRIMARY KEY,
        reportDate TEXT NOT NULL UNIQUE, -- Ensures one report per day
        totalPatientsInQueue INTEGER NOT NULL, -- Renamed from totalPatients
        patientsServed INTEGER NOT NULL,
        patientsRemoved INTEGER,
        averageWaitTimeMinutes TEXT, -- Renamed from averageWaitTime
        peakHour TEXT,
        queueData TEXT, -- JSON string of List<Map<String, dynamic>> for all patients processed that day
        generatedAt TEXT NOT NULL,
        generatedByUserId TEXT,
        FOREIGN KEY (generatedByUserId) REFERENCES $tableUsers (id)
      )
    ''');

    // Active Patient Queue table (for current day's active queue)
    await db.execute('''
      CREATE TABLE $tableActivePatientQueue (
        queueEntryId TEXT PRIMARY KEY,
        patientId TEXT,
        patientName TEXT NOT NULL,
        arrivalTime TEXT NOT NULL,
        queueNumber INTEGER DEFAULT 0, -- Queue number for daily sequencing
        gender TEXT,
        age INTEGER,
        conditionOrPurpose TEXT,
        selectedServices TEXT, -- JSON string of List<Map<String, dynamic>> for selected services
        totalPrice REAL, -- Total estimated price
        status TEXT NOT NULL, -- 'waiting', 'in_consultation', 'completed', 'removed'
        createdAt TEXT NOT NULL,
        addedByUserId TEXT,
        servedAt TEXT,          -- New field
        removedAt TEXT,         -- New field
        consultationStartedAt TEXT, -- New field
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE SET NULL,
        FOREIGN KEY (addedByUserId) REFERENCES $tableUsers (id) ON DELETE SET NULL
      )
    ''');

    // Create admin user by default
    await _createDefaultAdmin(db);

    // Create Indexes (for new databases v7+)
    await _createIndexes(db);
  }

  // Database upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print(
        'DATABASE_HELPER: Upgrading database from version $oldVersion to $newVersion...');
    if (oldVersion < 2) {
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableUsers, 'securityQuestion1', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableUsers, 'securityAnswer1', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableUsers, 'securityQuestion2', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableUsers, 'securityAnswer2', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableUsers, 'securityQuestion3', 'TEXT NOT NULL DEFAULT \'\'');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableUsers, 'securityAnswer3', 'TEXT NOT NULL DEFAULT \'\'');
    }
    if (oldVersion < 3) {
      // Recreate appointments table with the new schema
      await db.execute('DROP TABLE IF EXISTS ${DatabaseHelper.tableAppointments}');
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableAppointments} (
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
          FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id) ON DELETE CASCADE,
          FOREIGN KEY (doctorId) REFERENCES ${DatabaseHelper.tableUsers} (id),
          FOREIGN KEY (serviceId) REFERENCES ${DatabaseHelper.tableClinicServices} (id),
          FOREIGN KEY (createdById) REFERENCES ${DatabaseHelper.tableUsers} (id)
        )
      ''');
      // Add new columns to medical_records table
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableMedicalRecords, 'appointmentId', 'TEXT');
      await _addColumnIfNotExists(db, DatabaseHelper.tableMedicalRecords, 'serviceId', 'TEXT');
      // If you needed to add FK constraints here to an existing table, it's more complex in SQLite.
      // Typically involves renaming table, creating new table with FK, copying data, deleting old table.
      // For TEXT columns added like this, the FKs in the CREATE TABLE statement (_onCreate) will apply to new DBs.
      // For existing DBs, these columns are just added as TEXT. True FK enforcement would require the complex migration.
    }
    if (oldVersion < 4) {
      // Create clinic_services table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableClinicServices} (
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
        CREATE TABLE ${DatabaseHelper.tableUserActivityLog} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          actionDescription TEXT NOT NULL,
          targetRecordId TEXT,
          targetTable TEXT,
          timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          details TEXT, 
          FOREIGN KEY (userId) REFERENCES ${DatabaseHelper.tableUsers} (id)
        )
      ''');
    }
    if (oldVersion < 6) {
      // Create billing tables
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tablePatientBills} (
          id TEXT PRIMARY KEY,
          patientId TEXT NOT NULL,
          billDate TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          status TEXT NOT NULL, 
          notes TEXT,
          FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableBillItems} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          billId TEXT NOT NULL,
          serviceId TEXT,
          description TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          unitPrice REAL NOT NULL,
          itemTotal REAL NOT NULL, 
          FOREIGN KEY (billId) REFERENCES ${DatabaseHelper.tablePatientBills} (id) ON DELETE CASCADE,
          FOREIGN KEY (serviceId) REFERENCES ${DatabaseHelper.tableClinicServices} (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tablePayments} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          billId TEXT,
          patientId TEXT NOT NULL,
          paymentDate TEXT NOT NULL,
          amountPaid REAL NOT NULL,
          paymentMethod TEXT NOT NULL, 
          receivedByUserId TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (billId) REFERENCES ${DatabaseHelper.tablePatientBills} (id) ON DELETE SET NULL,
          FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id),
          FOREIGN KEY (receivedByUserId) REFERENCES ${DatabaseHelper.tableUsers} (id)
        )
      ''');
    }
    if (oldVersion < 7) {
      // Add indexes if upgrading from a version older than 7
      await _createIndexes(db);
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added Indexes.');
    }
    if (oldVersion < 8) {
      // Create patient queue reports table (for daily history)
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tablePatientQueue} (
          id TEXT PRIMARY KEY,
          reportDate TEXT NOT NULL,
          totalPatients INTEGER NOT NULL,
          patientsServed INTEGER NOT NULL,
          patientsWaiting INTEGER,          -- New Column
          patientsInConsultation INTEGER, -- New Column
          patientsRemoved INTEGER,          -- New Column
          averageWaitTime TEXT,
          peakHour TEXT,
          queueData TEXT NOT NULL,
          generatedAt TEXT NOT NULL,
          exportedToPdf INTEGER DEFAULT 0
        )
      ''');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added Patient Queue Reports table.');
    }
    if (oldVersion < 9) {
      // Active Patient Queue table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableActivePatientQueue} (
          queueEntryId TEXT PRIMARY KEY,
          patientId TEXT,
          patientName TEXT NOT NULL,
          arrivalTime TEXT NOT NULL,
          queueNumber INTEGER DEFAULT 0, -- Queue number for daily sequencing
          gender TEXT,
          age INTEGER,
          conditionOrPurpose TEXT,
          status TEXT NOT NULL, -- 'waiting', 'in_consultation', 'completed', 'removed'
          createdAt TEXT NOT NULL,
          addedByUserId TEXT,
          servedAt TEXT,          -- New field
          removedAt TEXT,         -- New field
          consultationStartedAt TEXT, -- New field
          FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id) ON DELETE SET NULL,
          FOREIGN KEY (addedByUserId) REFERENCES ${DatabaseHelper.tableUsers} (id) ON DELETE SET NULL
        )
      ''');
      // Add indexes for the new table
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_active_patient_queue_status ON ${DatabaseHelper.tableActivePatientQueue} (status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_active_patient_queue_arrival_time ON ${DatabaseHelper.tableActivePatientQueue} (arrivalTime)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_active_patient_queue_patient_id ON ${DatabaseHelper.tableActivePatientQueue} (patientId)');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added Active Patient Queue table and its indexes.');
    }
    if (oldVersion < 10) {
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'servedAt', 'TEXT');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'removedAt', 'TEXT');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'consultationStartedAt', 'TEXT');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'queueNumber', 'INTEGER DEFAULT 0');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added timestamp fields and queue number to Active Patient Queue table.');
    }
    if (oldVersion < 11) {
      // Re-ensure queueNumber column exists, as it might have been missed in a previous upgrade.
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'queueNumber', 'INTEGER DEFAULT 0');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Ensured queueNumber column in Active Patient Queue table.');
    }
    if (oldVersion < 12) {
      await _addColumnIfNotExists(
          db, DatabaseHelper.tablePatientQueue, 'totalPatientsInQueue', 'INTEGER');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tablePatientQueue, 'patientsServed', 'INTEGER');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tablePatientQueue, 'patientsRemoved', 'INTEGER');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tablePatientQueue, 'averageWaitTimeMinutes', 'TEXT');
      await _addColumnIfNotExists(db, DatabaseHelper.tablePatientQueue, 'peakHour', 'TEXT');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added patient status count columns to ${DatabaseHelper.tablePatientQueue}.');
    }
    if (oldVersion < 13) {
      if (oldVersion == 12) {
        print(
            "DATABASE_HELPER: Recreating ${DatabaseHelper.tablePatientQueue} to remove patientsWaiting and patientsInConsultation columns for upgrade from v12 to v13.");
        // 1. Rename the old table
        await db.execute(
            'ALTER TABLE ${DatabaseHelper.tablePatientQueue} RENAME TO ${DatabaseHelper.tablePatientQueue}_old_v12');
        print(
            "DATABASE_HELPER: Renamed ${DatabaseHelper.tablePatientQueue} to ${DatabaseHelper.tablePatientQueue}_old_v12");

        // 2. Create the new table with the correct schema (v13)
        await db.execute('''
          CREATE TABLE ${DatabaseHelper.tablePatientQueue} (
            id TEXT PRIMARY KEY,
            reportDate TEXT NOT NULL UNIQUE,
            totalPatientsInQueue INTEGER NOT NULL,
            patientsServed INTEGER NOT NULL,
            patientsRemoved INTEGER,
            averageWaitTimeMinutes TEXT,
            peakHour TEXT,
            queueData TEXT,
            generatedAt TEXT NOT NULL,
            generatedByUserId TEXT, -- This column allows NULLs implicitly
            FOREIGN KEY (generatedByUserId) REFERENCES ${DatabaseHelper.tableUsers} (id)
          )
        ''');
        print(
            "DATABASE_HELPER: Created new ${DatabaseHelper.tablePatientQueue} with updated schema (v13).");

        // 3. Copy data from the old table to the new table.
        // Assuming patient_queue_old_v12 (the v12 schema) has columns:
        // id, reportDate, totalPatients, patientsServed, patientsWaiting, patientsInConsultation,
        // patientsRemoved, averageWaitTime, peakHour, queueData, generatedAt.
        // It appears generatedByUserId was NOT in the v12 schema.
        // The columns patientsWaiting and patientsInConsultation are intentionally not copied.
        await db.execute('''
          INSERT INTO ${DatabaseHelper.tablePatientQueue} (
            id, reportDate, totalPatientsInQueue, patientsServed, patientsRemoved, 
            averageWaitTimeMinutes, peakHour, queueData, generatedAt, generatedByUserId
          )
          SELECT 
            id, reportDate, 
            totalPatients AS totalPatientsInQueue, 
            patientsServed, 
            patientsRemoved, 
            averageWaitTime AS averageWaitTimeMinutes, 
            peakHour, 
            queueData, 
            generatedAt, 
            NULL AS generatedByUserId -- Provide NULL as this column likely doesn't exist in v12 table
          FROM ${DatabaseHelper.tablePatientQueue}_old_v12
        ''');
        print(
            "DATABASE_HELPER: Copied data from ${DatabaseHelper.tablePatientQueue}_old_v12 to new ${DatabaseHelper.tablePatientQueue}, mapping v12 column names and providing NULL for generatedByUserId.");

        // 4. Drop the old table
        await db.execute('DROP TABLE ${DatabaseHelper.tablePatientQueue}_old_v12');
        print(
            "DATABASE_HELPER: Dropped old table ${DatabaseHelper.tablePatientQueue}_old_v12.");
      } else {
        // If upgrading from a version < 12, the "patientsWaiting" and "patientsInConsultation" columns
        // would not have been added by the "oldVersion < 12" block (as they are commented out).
        // So, for these cases, no specific action is needed for these two columns for v13.
        // However, ensure the other columns from the "< 12" block are present if they weren't already.
        await _addColumnIfNotExists(
            db, DatabaseHelper.tablePatientQueue, 'totalPatientsInQueue', 'INTEGER');
        await _addColumnIfNotExists(
            db, DatabaseHelper.tablePatientQueue, 'patientsServed', 'INTEGER');
        await _addColumnIfNotExists(
            db, DatabaseHelper.tablePatientQueue, 'patientsRemoved', 'INTEGER');
        await _addColumnIfNotExists(
            db, DatabaseHelper.tablePatientQueue, 'averageWaitTimeMinutes', 'TEXT');
        await _addColumnIfNotExists(db, DatabaseHelper.tablePatientQueue, 'peakHour', 'TEXT');
        print(
            "DATABASE_HELPER: Ensured report columns (excluding waiting/inConsultation) for ${DatabaseHelper.tablePatientQueue} for version < 12 upgrading to v13.");
      }
    }
    if (oldVersion < 14) {
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'selectedServices', 'TEXT');
      await _addColumnIfNotExists(
          db, DatabaseHelper.tableActivePatientQueue, 'totalPrice', 'REAL');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added selectedServices and totalPrice to ${DatabaseHelper.tableActivePatientQueue}.');
    }
    if (oldVersion < 15) {
      // Step 1: Add the column as TEXT, allowing NULLs.
      await _addColumnIfNotExists(db, DatabaseHelper.tablePayments, 'referenceNumber', 'TEXT');
      print(
          'DATABASE_HELPER: Upgraded database from v$oldVersion to v$newVersion - Added referenceNumber (TEXT) to ${DatabaseHelper.tablePayments}.');

      // Step 2: Create a UNIQUE INDEX on the new column.
      // This enforces uniqueness for future inserts/updates.
      // Note: If there's existing non-unique data in referenceNumber (which shouldn't be the case if it was just added),
      // this index creation might fail. This assumes the column is new or already contains unique values (or mostly NULLs).
      try {
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_referenceNumber ON ${DatabaseHelper.tablePayments} (referenceNumber)');
        print(
            'DATABASE_HELPER: Created UNIQUE INDEX idx_payments_referenceNumber ON ${DatabaseHelper.tablePayments} (referenceNumber).');
      } catch (e) {
        print(
            'DATABASE_HELPER: Error creating UNIQUE INDEX for referenceNumber. It might already exist or there might be duplicate data if column was partially populated: $e');
        // If this fails, it might be because the index was already created in a previous failed attempt or there's pre-existing duplicate data (unlikely for a newly added column).
      }
      print(
          'DATABASE_HELPER: Application must ensure non-null and unique reference numbers for new entries into ${DatabaseHelper.tablePayments}.');
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

    await db.insert(DatabaseHelper.tableUsers, {
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

  // USER MANAGEMENT METHODS (Delegating to UserDatabaseService)
  Future<User> insertUser(Map<String, dynamic> userMap) async {
    return userDbService.insertUser(userMap);
  }

  Future<User?> getUserByUsername(String username) async {
    return userDbService.getUserByUsername(username);
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    return userDbService.updateUser(user);
  }

  Future<int> deleteUser(String id) async {
    return userDbService.deleteUser(id);
  }

  Future<List<User>> getUsers() async {
    return userDbService.getUsers();
  }

  Future<User?> getUserSecurityDetails(String username) async {
    return userDbService.getUserSecurityDetails(username);
  }

  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    return userDbService.authenticateUser(username, password);
  }

  Future<bool> resetPassword(String username, String securityQuestion, String securityAnswer, String newPassword) async {
    return userDbService.resetPassword(username, securityQuestion, securityAnswer, newPassword);
  }

  // PATIENT MANAGEMENT METHODS (Delegating to PatientDatabaseService)
  Future<String> insertPatient(Map<String, dynamic> patient) async {
    return patientDbService.insertPatient(patient);
  }

  Future<int> updatePatient(Map<String, dynamic> patient) async {
    return patientDbService.updatePatient(patient);
  }

  Future<int> deletePatient(String id) async {
    return patientDbService.deletePatient(id);
  }

  Future<Map<String, dynamic>?> getPatient(String id) async {
    return patientDbService.getPatient(id);
  }

  Future<List<Map<String, dynamic>>> getPatients() async {
    return patientDbService.getPatients();
  }

  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    return patientDbService.searchPatients(query);
  }

  Future<Map<String, dynamic>?> findRegisteredPatient(
      {String? patientId, required String fullName}) async {
    return patientDbService.findRegisteredPatient(patientId: patientId, fullName: fullName);
  }
  
  Future<void> updatePatientFromSync(Map<String, dynamic> patientData) async {
    return patientDbService.updatePatientFromSync(patientData);
  }

  Future<void> enableRealTimeSync(String patientId) async {
    return patientDbService.enableRealTimeSync(patientId);
  }

  Future<bool> needsRealTimeSync(String patientId) async {
    return patientDbService.needsRealTimeSync(patientId);
  }

  // APPOINTMENT MANAGEMENT METHODS (Delegating to AppointmentDatabaseService)
  Future<Appointment> insertAppointment(Appointment appointment) async {
    return appointmentDbService.insertAppointment(appointment);
  }

  Future<int> updateAppointment(Appointment appointment) async {
    return appointmentDbService.updateAppointment(appointment);
  }

  Future<int> updateAppointmentStatus(String id, String status) async {
    return appointmentDbService.updateAppointmentStatus(id, status);
  }

  Future<int> deleteAppointment(String id) async {
    return appointmentDbService.deleteAppointment(id);
  }

  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    return appointmentDbService.getAppointmentsByDate(date);
  }

  Future<List<Appointment>> getPatientAppointments(String patientId) async {
    return appointmentDbService.getPatientAppointments(patientId);
  }
  
  Future<void> updatePatientQueueFromSync(Map<String, dynamic> queueData) async {
      return appointmentDbService.updatePatientQueueFromSync(queueData);
  }

  Future<List<Map<String, dynamic>>> getCurrentPatientQueue() async {
      return appointmentDbService.getCurrentPatientQueue();
  }

  // MEDICAL RECORDS METHODS

  // Insert medical record
  Future<String> insertMedicalRecord(Map<String, dynamic> record) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    record['id'] = 'record-${DateTime.now().millisecondsSinceEpoch}';
    record['createdAt'] = now;
    record['updatedAt'] = now;

    await db.insert(DatabaseHelper.tableMedicalRecords, record);
    await logChange(DatabaseHelper.tableMedicalRecords, record['id'], 'insert');

    return record['id'];
  }

  // Update medical record
  Future<int> updateMedicalRecord(Map<String, dynamic> record) async {
    final db = await database;
    record['updatedAt'] = DateTime.now().toIso8601String();

    final result = await db.update(
      DatabaseHelper.tableMedicalRecords,
      record,
      where: 'id = ?',
      whereArgs: [record['id']],
    );

    await logChange(DatabaseHelper.tableMedicalRecords, record['id'], 'update');
    return result;
  }

  // Get medical records by patient
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(
      String patientId) async {
    final db = await database;
    return await db.query(
      DatabaseHelper.tableMedicalRecords,
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'recordDate DESC',
    );
  }

  // DATABASE SYNCHRONIZATION METHODS

  // Log changes for synchronization
  Future<void> logChange(String tableName, String recordId, String action,
      {DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    await exec.insert(DatabaseHelper.tableSyncLog, {
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
      DatabaseHelper.tableSyncLog,
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
        DatabaseHelper.tableSyncLog,
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit();
  }

  // Sync with server
  Future<bool> syncWithServer() async {
    // Temporarily disable sync to prevent timeout errors
    debugPrint('Sync disabled - no server configured');
    return true; // Return true to avoid error handling
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
      DatabaseHelper.tableUserActivityLog,
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

    await db.insert(DatabaseHelper.tableUserActivityLog, {
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

    // Indexes for active_patient_queue table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_active_patient_queue_status ON $tableActivePatientQueue (status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_active_patient_queue_arrival_time ON $tableActivePatientQueue (arrivalTime)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_active_patient_queue_patient_id ON $tableActivePatientQueue (patientId)');

    print('DATABASE_HELPER: Ensured all indexes are created.');
  }

  // DAILY QUEUE REPORT METHODS

  /// Save daily queue report to database
  Future<String> saveDailyQueueReport(Map<String, dynamic> queueReport) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final reportId =
        'queue_report_${queueReport['reportDate']}_${DateTime.now().millisecondsSinceEpoch}';

    final reportData = {
      'id': reportId,
      'reportDate': queueReport['reportDate'],
      'totalPatientsInQueue': queueReport['totalPatientsInQueue'],
      'patientsServed': queueReport['patientsServed'],
      'patientsRemoved': queueReport['patientsRemoved'],
      'averageWaitTimeMinutes': queueReport['averageWaitTimeMinutes'],
      'peakHour': queueReport['peakHour'],
      'queueData': jsonEncode(queueReport['queueData']),
      'generatedAt': queueReport['generatedAt'] ?? now,
      'generatedByUserId': queueReport['generatedByUserId'],
    };

    await db.insert(DatabaseHelper.tablePatientQueue, reportData);
    await logChange(DatabaseHelper.tablePatientQueue, reportId, 'insert');

    return reportId;
  }

  /// Get daily queue reports
  Future<List<Map<String, dynamic>>> getDailyQueueReports(
      {int limit = 30}) async {
    final db = await database;

    final results = await db.query(
      DatabaseHelper.tablePatientQueue,
      orderBy: 'reportDate DESC',
      limit: limit,
    );

    // Parse the queueData JSON back to objects
    return results.map((report) {
      final reportCopy = Map<String, dynamic>.from(report);
      try {
        reportCopy['queueData'] = jsonDecode(report['queueData'] as String);
      } catch (e) {
        reportCopy['queueData'] = [];
      }
      return reportCopy;
    }).toList();
  }

  /// Get queue report by date
  Future<Map<String, dynamic>?> getQueueReportByDate(String date) async {
    final db = await database;

    final results = await db.query(
      DatabaseHelper.tablePatientQueue,
      where: 'reportDate = ?',
      whereArgs: [date],
      orderBy:
          'generatedAt DESC', // Get the latest one for that date if multiple exist by mistake
      limit: 1,
    );

    if (results.isNotEmpty) {
      final report = Map<String, dynamic>.from(results.first);
      try {
        report['queueData'] = jsonDecode(report['queueData'] as String);
      } catch (e) {
        report['queueData'] = [];
      }
      return report;
    }

    return null;
  }

  /// Mark queue report as exported to PDF
  Future<void> markQueueReportAsExported(String reportId) async {
    final db = await database;

    await db.update(
      DatabaseHelper.tablePatientQueue,
      {'exportedToPdf': 1},
      where: 'id = ?',
      whereArgs: [reportId],
    );

    await logChange(DatabaseHelper.tablePatientQueue, reportId, 'update');
  }

  /// Deletes a specific queue report by its ID.
  Future<int> deleteQueueReport(String reportId) async {
    final db = await database;
    final result = await db.delete(
      DatabaseHelper.tablePatientQueue,
      where: 'id = ?',
      whereArgs: [reportId],
    );
    if (result > 0) {
      await logChange(DatabaseHelper.tablePatientQueue, reportId, 'delete');
    }
    return result;
  }

  /// Delete old queue reports (older than specified days)
  Future<int> deleteOldQueueReports(int daysToKeep) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffDateStr = cutoffDate.toIso8601String().split('T')[0];

    final result = await db.delete(
      DatabaseHelper.tablePatientQueue,
      where: 'reportDate < ?',
      whereArgs: [cutoffDateStr],
    );

    return result;
  }

  // ACTIVE PATIENT QUEUE METHODS

  /// Adds a patient to the active queue.
  Future<ActivePatientQueueItem> addToActiveQueue(
      ActivePatientQueueItem item) async {
    final db = await database;
    await db.insert(DatabaseHelper.tableActivePatientQueue, item.toJson());
    await logChange(DatabaseHelper.tableActivePatientQueue, item.queueEntryId, 'insert');
    return item;
  }

  /// Removes a patient from the active queue by their queueEntryId.
  Future<int> removeFromActiveQueue(String queueEntryId) async {
    final db = await database;
    final result = await db.delete(
      DatabaseHelper.tableActivePatientQueue,
      where: 'queueEntryId = ?',
      whereArgs: [queueEntryId],
    );
    if (result > 0) {
      await logChange(DatabaseHelper.tableActivePatientQueue, queueEntryId, 'delete');
    }
    return result;
  }

  /// Updates the status of a patient in the active queue.
  Future<int> updateActiveQueueItemStatus(
      String queueEntryId, String newStatus) async {
    final db = await database;
    final result = await db.update(
      DatabaseHelper.tableActivePatientQueue,
      {'status': newStatus},
      where: 'queueEntryId = ?',
      whereArgs: [queueEntryId],
    );
    if (result > 0) {
      await logChange(DatabaseHelper.tableActivePatientQueue, queueEntryId, 'update');
    }
    return result;
  }

  /// Updates an entire item in the active queue.
  Future<int> updateActiveQueueItem(ActivePatientQueueItem item) async {
    final db = await database;
    final result = await db.update(
      DatabaseHelper.tableActivePatientQueue,
      item.toJson(),
      where: 'queueEntryId = ?',
      whereArgs: [item.queueEntryId],
    );
    if (result > 0) {
      await logChange(DatabaseHelper.tableActivePatientQueue, item.queueEntryId, 'update');
    }
    return result;
  }

  /// Gets the current active patient queue, ordered by arrival time.
  /// Optionally filters by status(es).
  Future<List<ActivePatientQueueItem>> getActiveQueue(
      {List<String>? statuses}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (statuses != null && statuses.isNotEmpty) {
      whereClause = 'status IN (${statuses.map((_) => '?').join(',')})';
      whereArgs = statuses;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableActivePatientQueue,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'arrivalTime ASC',
    );
    return maps.map((map) => ActivePatientQueueItem.fromJson(map)).toList();
  }

  /// Gets a specific item from the active queue by its ID.
  Future<ActivePatientQueueItem?> getActiveQueueItem(
      String queueEntryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableActivePatientQueue,
      where: 'queueEntryId = ?',
      whereArgs: [queueEntryId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ActivePatientQueueItem.fromJson(maps.first);
    }
    return null;
  }

  /// Gets active queue items within a specific date range
  Future<List<ActivePatientQueueItem>> getActiveQueueByDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableActivePatientQueue,
      where: 'arrivalTime >= ? AND arrivalTime < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'arrivalTime ASC',
    );
    return maps.map((map) => ActivePatientQueueItem.fromJson(map)).toList();
  }

  /// Clears all entries from the active_patient_queue table (e.g., at the end of a day).
  Future<int> clearActiveQueue() async {
    final db = await database;
    final count = await db.delete(DatabaseHelper.tableActivePatientQueue);
    // Optionally log this as a bulk operation if needed, though logChange is per-record.
    // For simplicity, not logging each deletion during a clear.
    print(
        'DATABASE_HELPER: Cleared $count entries from $tableActivePatientQueue.');
    return count;
  }

  /// Checks if a patient is already in the active queue with 'waiting' or 'in_consultation' status.
  Future<bool> isPatientInActiveQueue(
      {String? patientId, required String patientName}) async {
    final db = await database;
    List<Map<String, dynamic>> result;

    if (patientId != null && patientId.isNotEmpty) {
      result = await db.query(
        DatabaseHelper.tableActivePatientQueue,
        where: 'patientId = ? AND (status = ? OR status = ?)',
        whereArgs: [patientId, 'waiting', 'in_consultation'],
        limit: 1,
      );
    } else {
      // Fallback to patientName if patientId is not available or empty
      result = await db.query(
        DatabaseHelper.tableActivePatientQueue,
        where: 'patientName = ? AND (status = ? OR status = ?)',
        whereArgs: [patientName, 'waiting', 'in_consultation'],
        limit: 1,
      );
    }
    return result.isNotEmpty;
  }

  // Add this new method
  Future<int> deleteActiveQueueItemsByDate(DateTime date) async {
    final db = await database;
    final startOfDay =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999)
        .toIso8601String();

    // Assuming arrivalTime is stored as an ISO8601 string.
    // The exact column name for arrival time in active_patient_queue needs to be confirmed.
    // Let's assume it is 'arrivalTime'.
    int count = await db.delete(
      DatabaseHelper.tableActivePatientQueue,
      where: 'arrivalTime >= ? AND arrivalTime <= ?',
      whereArgs: [startOfDay, endOfDay],
    );
    print(
        'DATABASE_HELPER: Deleted $count items from $tableActivePatientQueue for date ${DateFormat('yyyy-MM-dd').format(date)}');
    return count;
  }

  Future<List<Map<String, dynamic>>> searchPayments({
    required String
        reference, // This will now specifically be the referenceNumber
    DateTime? startDate,
    DateTime? endDate,
    String? paymentType,
  }) async {
    final db = await database;

    String query = '''
      SELECT p.*, 
             pt.fullName as patient_name,
             u.fullName as received_by_user_name 
      FROM $tablePayments p
      LEFT JOIN $tablePatients pt ON p.patientId = pt.id
      LEFT JOIN $tableUsers u ON p.receivedByUserId = u.id
      WHERE 1=1
    ''';

    List<dynamic> arguments = [];

    if (reference.isNotEmpty) {
      query += ' AND p.referenceNumber LIKE ?'; // Search by referenceNumber
      arguments.add('%$reference%');
    }

    if (startDate != null) {
      query +=
          ' AND DATE(p.paymentDate) >= DATE(?)'; // Ensure correct date comparison
      arguments.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      query +=
          ' AND DATE(p.paymentDate) <= DATE(?)'; // Ensure correct date comparison
      arguments.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    if (paymentType != null && paymentType != 'all' && paymentType.isNotEmpty) {
      query += ' AND p.paymentMethod = ?';
      arguments.add(paymentType);
    }

    query += ' ORDER BY p.paymentDate DESC';

    final results = await db.rawQuery(query, arguments);
    return results;
  }

  Future<List<Map<String, dynamic>>> searchServices({
    required String searchTerm,
    String? category,
  }) async {
    final db = await database;

    String query = '''
      SELECT * FROM $tableClinicServices
      WHERE (serviceName LIKE ? OR id LIKE ? OR description LIKE ?)
    '''; // Added OR description LIKE ?

    List<dynamic> arguments = [
      '%$searchTerm%',
      '%$searchTerm%',
      '%$searchTerm%'
    ]; // Added argument for description search

    if (category != null &&
        category != 'All Categories' &&
        category.isNotEmpty) {
      // Added isNotEmpty check
      query += ' AND category = ?';
      arguments.add(category);
    }

    query += ' ORDER BY serviceName ASC';

    final results = await db.rawQuery(query, arguments);
    return results;
  }

  Future<int> getActiveQueueCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) FROM $tableActivePatientQueue WHERE status = \'waiting\' OR status = \'in_consultation\'');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Search for patients in the active queue by name (LIKE) or patient ID (exact)
  Future<List<Map<String, dynamic>>> searchActiveQueuePatients(
      String searchTerm) async {
    final db = await database;
    final String likeSearchTerm = '%$searchTerm%';
    // Query for today's active items matching the search term
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final List<Map<String, dynamic>> result = await db.query(
      DatabaseHelper.tableActivePatientQueue,
      where: '(patientName LIKE ? OR patientId = ?) AND DATE(arrivalTime) = ?',
      whereArgs: [likeSearchTerm, searchTerm, todayDate],
    );
    return result;
  }

  // Method to search services by category (case-insensitive, partial match)
  Future<List<Map<String, dynamic>>> searchServicesByCategory(
      String category) async {
    final db = await database;
    final String likeCategory = '%$category%';
    return await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'category LIKE ?',
      whereArgs: [likeCategory],
      orderBy: 'serviceName ASC',
    );
  }

  // Method to search services by name (case-insensitive, partial match)
  Future<List<Map<String, dynamic>>> searchServicesByName(
      String serviceName) async {
    final db = await database;
    final String likeName = '%$serviceName%';
    return await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'serviceName LIKE ?',
      whereArgs: [likeName],
      orderBy: 'serviceName ASC',
    );
  }

  // Method to get a single clinic service by its exact name (case-insensitive)
  Future<Map<String, dynamic>?> getClinicServiceByName(
      String serviceName) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'LOWER(serviceName) = LOWER(?)',
      whereArgs: [serviceName],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Method to get a single clinic service by its ID
  Future<Map<String, dynamic>?> getClinicServiceById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<String> insertClinicService(Map<String, dynamic> service) async {
    final db = await database;
    // Ensure ID is present or generate one if not
    String id =
        service['id'] ?? 'service-${DateTime.now().millisecondsSinceEpoch}';
    Map<String, dynamic> serviceToInsert = {...service, 'id': id};

    await db.insert(
      DatabaseHelper.tableClinicServices,
      serviceToInsert,
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Or .fail if ID must be unique on insert
    );
    return id; // Return the ID of the inserted service
  }

  Future<int> updateClinicService(Map<String, dynamic> service) async {
    final db = await database;
    return await db.update(
      DatabaseHelper.tableClinicServices,
      service,
      where: 'id = ?',
      whereArgs: [service['id']],
    );
  }

  Future<int> deleteClinicService(String id) async {
    final db = await database;
    final result = await db.delete(
      DatabaseHelper.tableClinicServices,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result > 0) {
      await logChange(DatabaseHelper.tableClinicServices, id, 'delete');
    }
    return result;
  }

  // PAYMENTS METHODS (Can be expanded for more complex payment scenarios)

  /// Inserts a new payment record into the database.
  ///
  /// The [paymentData] map should contain all necessary fields for the `payments` table,
  /// including 'billId' (optional), 'patientId', 'referenceNumber', 'paymentDate',
  /// 'amountPaid', 'paymentMethod', and 'receivedByUserId'.
  Future<int> insertPayment(Map<String, dynamic> paymentData) async {
    final db = await database;
    // Ensure essential fields are present
    if (paymentData['patientId'] == null ||
        paymentData['referenceNumber'] == null ||
        paymentData['paymentDate'] == null ||
        paymentData['amountPaid'] == null ||
        paymentData['paymentMethod'] == null ||
        paymentData['receivedByUserId'] == null) {
      throw ArgumentError("Missing essential payment data for insertPayment.");
    }

    // The 'id' for payments is AUTOINCREMENT, so we don't set it here.
    // 'billId' can be null.

    late int paymentId;
    await db.transaction((txn) async {
      paymentId = await txn.insert(DatabaseHelper.tablePayments, paymentData);
      if (paymentId > 0) {
        // Log change using the auto-generated ID
        await logChange(DatabaseHelper.tablePayments, paymentId.toString(), 'insert',
            executor: txn);
      }
    });
    return paymentId;
  }
}
