import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/user_database_service.dart';
import 'package:flutter_application_1/services/patient_database_service.dart';
import 'package:flutter_application_1/services/appointment_database_service.dart';
import 'package:flutter_application_1/services/clinic_service_database_service.dart';
import 'package:flutter_application_1/services/document_tracking_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/appointment.dart';
import '../models/active_patient_queue_item.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic_service.dart';
import '../models/patient.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal() {
    userDbService = UserDatabaseService(this);
    patientDbService = PatientDatabaseService(this);
    appointmentDbService = AppointmentDatabaseService(this);
    clinicServiceDbService = ClinicServiceDatabaseService(this);
    documentTrackingService = DocumentTrackingService(this);
  }

  // Instance variables for the database and its path
  Database? _instanceDatabase;
  String? _instanceDbPath;

  static const String _databaseName = 'patient_management.db';
  static const int _databaseVersion = 34;

  // Tables
  static const String tableUsers = 'users';
  static const String tablePatients = 'patients';
  static const String tablePatientHistory = 'patient_history';
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
  late final AppointmentDatabaseService appointmentDbService;
  late final ClinicServiceDatabaseService clinicServiceDbService;
  late final DocumentTrackingService documentTrackingService;

  // Getter for database instance
  Future<Database> get database async {
    if (_instanceDatabase != null && _instanceDatabase!.isOpen) {
      return _instanceDatabase!;
    }

    if (_dbOpenCompleter != null) {
      return _dbOpenCompleter!.future;
    }

    _dbOpenCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _instanceDatabase = db;
      _dbOpenCompleter!.complete(db);
    } catch (e) {
      debugPrint('DATABASE_HELPER: Database initialization failed: $e');
      _dbOpenCompleter!.completeError(e);
      _dbOpenCompleter = null;
      _instanceDatabase = null;
      rethrow;
    }
    return _dbOpenCompleter!.future;
  }

  Future<List<ClinicService>> getClinicServices() {
    return clinicServiceDbService.getClinicServices();
  }

  Future<String> insertClinicService(Map<String, dynamic> service) {
    return clinicServiceDbService.insertClinicService(service);
  }

  Future<int> getServiceSelectionCount(String serviceId) {
    return clinicServiceDbService.getServiceSelectionCount(serviceId);
  }

  Future<List<Map<String, dynamic>>> getServiceUsageTrend(String serviceId) {
    return clinicServiceDbService.getServiceUsageTrend(serviceId);
  }

  Future<List<Patient>> getRecentPatientsForService(String serviceId,
      {int limit = 5}) {
    return clinicServiceDbService.getRecentPatientsForService(serviceId,
        limit: limit);
  }

  // Public getter for the current database path
  Future<String?> get currentDatabasePath async {
    if (_instanceDbPath == null) {
      await database;
    }
    return _instanceDbPath;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path; // Will be assigned in one of the branches below
    final String projectRoot = Directory
        .current.path; // e.g., /path/to/jgem-main/flutter_application_1
    final String workspaceRootDirectoryPath =
        Directory(projectRoot).parent.path; // e.g., /path/to/jgem-main

    // Path with .db extension (from _databaseName constant)
    final String workspaceDatabasePathWithDbExt = normalize(
        join(workspaceRootDirectoryPath, DatabaseHelper._databaseName));
    final File workspaceDatabaseFileWithDbExt =
        File(workspaceDatabasePathWithDbExt);

    // Path without .db (e.g., 'patient_management')
    final String dbNameWithoutExtension =
        DatabaseHelper._databaseName.endsWith('.db')
            ? DatabaseHelper._databaseName
                .substring(0, DatabaseHelper._databaseName.length - 3)
            : DatabaseHelper._databaseName;
    final String workspaceDatabasePathWithoutDbExt =
        normalize(join(workspaceRootDirectoryPath, dbNameWithoutExtension));
    final File workspaceDatabaseFileWithoutDbExt =
        File(workspaceDatabasePathWithoutDbExt);

    if (await workspaceDatabaseFileWithDbExt.exists()) {
      path = workspaceDatabasePathWithDbExt;
      debugPrint(
          'DATABASE_HELPER: [GLOBAL_WORKSPACE] Using database from workspace root (with .db ext): $path');
    } else if (await workspaceDatabaseFileWithoutDbExt.exists()) {
      path = workspaceDatabasePathWithoutDbExt;
      debugPrint(
          'DATABASE_HELPER: [GLOBAL_WORKSPACE] Using database from workspace root (WITHOUT .db ext): $path');
    } else {
      debugPrint(
          'DATABASE_HELPER: Database not found in workspace root (tried with/without .db: $workspaceDatabasePathWithDbExt AND $workspaceDatabasePathWithoutDbExt). Trying platform-specific locations.');

      // Platform-specific fallback logic
      if (!kIsWeb && Platform.isWindows) {
        final String projectDatabasesSubfolderPath = normalize(
            join(projectRoot, 'databases', DatabaseHelper._databaseName));
        final File projectDbFileInSubfolder =
            File(projectDatabasesSubfolderPath);

        if (await projectDbFileInSubfolder.exists()) {
          path = projectDatabasesSubfolderPath;
          debugPrint(
              'DATABASE_HELPER: [WINDOWS_PROJECT_DATABASES] Using database from project_root/databases/: $path');
        } else {
          try {
            final Directory docDir = await getApplicationDocumentsDirectory();
            path = join(docDir.path, DatabaseHelper._databaseName);
            debugPrint(
                'DATABASE_HELPER: [WINDOWS_APP_DOCS] Using app documents directory for database: $path');
          } catch (e) {
            path = normalize(join(
                projectRoot,
                DatabaseHelper
                    ._databaseName)); // Fallback to project root itself
            debugPrint(
                'DATABASE_HELPER: [WINDOWS_PROJECT_ROOT_FALLBACK] Using project root (app docs failed): $path. Error: $e');
          }
        }
      } else if (!kIsWeb && Platform.isAndroid) {
        try {
          Directory? storageDir;
          try {
            storageDir = await getExternalStorageDirectory();
          } catch (e) {
            debugPrint(
                'DATABASE_HELPER: [ANDROID_DEBUG] Failed to get external storage, trying app docs. Error: $e');
          }

          if (storageDir != null) {
            String potentialPath =
                join(storageDir.path, DatabaseHelper._databaseName);
            final File externalDbFile = File(potentialPath);
            if (await externalDbFile.exists()) {
              path = potentialPath;
              debugPrint(
                  'DATABASE_HELPER: [ANDROID_EXTERNAL_STORAGE] Using existing database from external storage: $path');
            } else {
              debugPrint(
                  'DATABASE_HELPER: [ANDROID_INFO] DB not in external storage ($potentialPath) or dir unavailable. Defaulting to app documents dir.');
              final docDir = await getApplicationDocumentsDirectory();
              path = join(docDir.path, DatabaseHelper._databaseName);
              debugPrint(
                  'DATABASE_HELPER: [ANDROID_APP_DOCS] Using app documents directory (external check done): $path');
            }
          } else {
            // externalDir was null
            final docDir = await getApplicationDocumentsDirectory();
            path = join(docDir.path, DatabaseHelper._databaseName);
            debugPrint(
                'DATABASE_HELPER: [ANDROID_APP_DOCS] Using app documents directory (externalDir was null): $path');
          }
        } catch (e) {
          path = normalize(join(projectRoot, DatabaseHelper._databaseName));
          debugPrint(
              'DATABASE_HELPER: [ANDROID_PROJECT_ROOT_FALLBACK] Using project root (all other paths failed): $path. Error: $e');
        }
      } else if (!kIsWeb &&
          (Platform.isIOS || Platform.isLinux || Platform.isMacOS)) {
        try {
          final docDir = await getApplicationDocumentsDirectory();
          path = join(docDir.path, DatabaseHelper._databaseName);
          debugPrint(
              'DATABASE_HELPER: [${Platform.operatingSystem.toUpperCase()}_APP_DOCS] Using app documents directory: $path');
        } catch (e) {
          path = normalize(join(projectRoot,
              DatabaseHelper._databaseName)); // Fallback to project root
          debugPrint(
              'DATABASE_HELPER: [${Platform.operatingSystem.toUpperCase()}_PROJECT_ROOT_FALLBACK] Using project root (app docs failed): $path. Error: $e');
        }
      } else {
        if (kIsWeb) {
          debugPrint(
              'DATABASE_HELPER: [WEB] Web platform detected. Database name: "${DatabaseHelper._databaseName}" will be used by sqflite_common_ffi_web (typically IndexedDB).');
          path = DatabaseHelper
              ._databaseName; // For web, path is usually just the name for IndexedDB.
        } else {
          debugPrint(
              'DATABASE_HELPER: [UNKNOWN_PLATFORM] Using project root as a last resort for database: $projectRoot/${DatabaseHelper._databaseName}');
          path = normalize(join(projectRoot, DatabaseHelper._databaseName));
        }
      }
    }

    _instanceDbPath = path; // Store the determined path

    // Ensure the directory exists before opening the database
    try {
      final Directory directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        debugPrint(
            'DATABASE_HELPER: Created directory for database at ${directory.path}');
      }

      // Verify directory is writable
      final testFile = File(join(directory.path, 'test_write.tmp'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        debugPrint('DATABASE_HELPER: Directory is writable');
      } catch (e) {
        debugPrint('DATABASE_HELPER: Directory write test failed: $e');
        throw Exception(
            'Database directory is not writable: ${directory.path}');
      }
    } catch (e) {
      debugPrint(
          'DATABASE_HELPER: Error creating or verifying directory for database. Error: $e');
      throw Exception('Failed to prepare database directory: $e');
    }
    debugPrint(
        '================================================================================');
    debugPrint('DATABASE_HELPER: FINAL DATABASE PATH TO BE OPENED:');
    debugPrint(_instanceDbPath);
    debugPrint(
        '================================================================================');

    // --- DEVELOPMENT ONLY: Force delete database to ensure _onCreate runs ---
    // --- END DEVELOPMENT ONLY SECTION ---

    Database openedDb;
    try {
      openedDb = await openDatabase(
        _instanceDbPath!,
        version: DatabaseHelper._databaseVersion, // Updated usage
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // onOpen: (db) async { // Alternative place to clear, but doing it after ensures table exists
        //   print('DATABASE_HELPER: Clearing active_patient_queue onOpen.');
        //   await db.delete(DatabaseHelper.tableActivePatientQueue); // Updated usage
        // }
      );
    } catch (e) {
      debugPrint(
          'DATABASE_HELPER: Failed to open database at $_instanceDbPath');
      debugPrint('DATABASE_HELPER: Error details: $e');

      // Try to recover by using a different path or cleaning up
      if (e.toString().contains('unable to open database file')) {
        debugPrint(
            'DATABASE_HELPER: Attempting recovery by trying alternative path...');

        // Try alternative path in user's temp directory
        try {
          final tempDir = Directory.systemTemp;
          final altPath = join(
              tempDir.path, 'flutter_app_db', DatabaseHelper._databaseName);
          final altDirectory = Directory(dirname(altPath));

          if (!await altDirectory.exists()) {
            await altDirectory.create(recursive: true);
          }

          debugPrint('DATABASE_HELPER: Trying alternative path: $altPath');
          _instanceDbPath = altPath;

          openedDb = await openDatabase(
            altPath,
            version: DatabaseHelper._databaseVersion,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          );

          debugPrint(
              'DATABASE_HELPER: Successfully opened database at alternative path');
        } catch (altError) {
          debugPrint(
              'DATABASE_HELPER: Alternative path also failed: $altError');
          throw Exception(
              'Unable to open database at any location. Original error: $e, Alternative error: $altError');
        }
      } else {
        rethrow;
      }
    }

    // Clear the active_patient_queue table every time the database is initialized
    // This ensures it starts fresh for the day.
    // print(
    //     'DATABASE_HELPER: Clearing ${DatabaseHelper.tableActivePatientQueue} after DB open/creation/upgrade.'); // Updated usage
    // await openedDb
    //     .delete(DatabaseHelper.tableActivePatientQueue); // Updated usage
    // print(
    //     'DATABASE_HELPER: ${DatabaseHelper.tableActivePatientQueue} cleared.'); // Updated usage

    return openedDb;
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE $tableUsers (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        password TEXT,
        role TEXT,
        fullName TEXT,
        email TEXT,
        contactNumber TEXT,
        securityQuestion1 TEXT,
        securityAnswer1 TEXT,
        securityQuestion2 TEXT,
        securityAnswer2 TEXT,
        securityQuestion3 TEXT,
        securityAnswer3 TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT 
      )
    ''');
    debugPrint('DATABASE_HELPER: Created $tableUsers table');

    // Patients table
    await db.execute('''
      CREATE TABLE $tablePatients (
        id TEXT PRIMARY KEY,
        fullName TEXT,
        birthDate TEXT,
        gender TEXT,
        contactNumber TEXT,
        email TEXT,
        address TEXT,
        bloodType TEXT,
        allergies TEXT,
        currentMedications TEXT,
        medicalHistory TEXT,
        emergencyContactName TEXT,
        emergencyContactNumber TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        registrationDate TEXT
      )
    ''');
    debugPrint('DATABASE_HELPER: Created $tablePatients table');

    // Patient History table
    await db.execute('''
      CREATE TABLE $tablePatientHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientId TEXT NOT NULL,
        fieldName TEXT NOT NULL,
        oldValue TEXT,
        newValue TEXT,
        updatedAt TEXT NOT NULL,
        updatedByUserId TEXT,
        sourceOfChange TEXT,
        FOREIGN KEY (patientId) REFERENCES $tablePatients(id) ON DELETE CASCADE,
        FOREIGN KEY (updatedByUserId) REFERENCES $tableUsers(id) ON DELETE SET NULL
      )
    ''');
    debugPrint('DATABASE_HELPER: Created $tablePatientHistory table');

    // Appointments table
    await db.execute('''
      CREATE TABLE $tableAppointments (
        id TEXT PRIMARY KEY,
        patientId TEXT,
        date TEXT,
        time TEXT,
        doctorId TEXT,
        consultationType TEXT,
        durationMinutes INTEGER,
        status TEXT,
        consultationStartedAt TEXT,
        servedAt TEXT,
        selectedServices TEXT,
        totalPrice REAL,
        paymentStatus TEXT,
        originalAppointmentId TEXT,
        cancelledAt TEXT,
        cancellationReason TEXT,
        notes TEXT,
        isWalkIn INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY (patientId) REFERENCES $tablePatients(id) ON DELETE CASCADE,
        FOREIGN KEY (doctorId) REFERENCES $tableUsers(id)
      )
    ''');
    debugPrint('DATABASE_HELPER: Created $tableAppointments table');

    // Medical Records table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableMedicalRecords} (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        appointmentId TEXT,
        serviceId TEXT, -- Will be deprecated
        selectedServices TEXT, -- New field for multiple services
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
        defaultPrice REAL,
        selectionCount INTEGER DEFAULT 0 NOT NULL 
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

    // Patient Bills table (MODIFIED FOR INVOICING)
    await db.execute('''
      CREATE TABLE $tablePatientBills (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        invoiceNumber TEXT UNIQUE, 
        billDate TEXT NOT NULL,
        dueDate TEXT,
        subtotal REAL,
        discountAmount REAL DEFAULT 0.0,
        taxAmount REAL DEFAULT 0.0,
        totalAmount REAL NOT NULL,
        status TEXT NOT NULL, 
        notes TEXT,
        createdByUserId TEXT, 
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE,
        FOREIGN KEY (createdByUserId) REFERENCES $tableUsers (id) 
      )
    ''');
    debugPrint(
        'DATABASE_HELPER: Created $tablePatientBills table (schema updated for invoicing)');

    // Bill Items table (Ensure this definition is present and correct)
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
    debugPrint('DATABASE_HELPER: Created $tableBillItems table');

    // Payments table (MODIFIED - added invoiceNumber link, ensured billId is present)
    await db.execute('''
      CREATE TABLE $tablePayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        billId TEXT NOT NULL, 
        patientId TEXT NOT NULL,
        patientName TEXT NOT NULL, 
        invoiceNumber TEXT, 
        referenceNumber TEXT UNIQUE NOT NULL, 
        paymentDate TEXT NOT NULL,
        amountPaid REAL NOT NULL,
        totalBillAmount REAL, 
        paymentMethod TEXT NOT NULL, 
        receivedByUserId TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE CASCADE, 
        FOREIGN KEY (patientId) REFERENCES $tablePatients (id),
        FOREIGN KEY (receivedByUserId) REFERENCES $tableUsers (id)
      )
    ''');
    debugPrint(
        'DATABASE_HELPER: Created $tablePayments table (schema updated)');

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

    // Generated Documents table for tracking PDFs and other documents
    await db.execute('''
      CREATE TABLE generated_documents (
        id TEXT PRIMARY KEY,
        documentType TEXT NOT NULL,
        relatedTable TEXT,
        relatedRecordId TEXT,
        fileName TEXT NOT NULL,
        filePath TEXT,
        fileSize INTEGER,
        documentData TEXT,
        generatedAt TEXT NOT NULL,
        generatedByUserId TEXT,
        synced INTEGER DEFAULT 0,
        metadata TEXT,
        FOREIGN KEY (generatedByUserId) REFERENCES $tableUsers (id)
      )
    ''');

    // Create indexes for efficient querying
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_type ON generated_documents (documentType)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_related ON generated_documents (relatedTable, relatedRecordId)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_generated ON generated_documents (generatedAt)
    ''');
    debugPrint(
        'DATABASE_HELPER: Created generated_documents table with indexes');

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
        queueNumber INTEGER NOT NULL,
        gender TEXT,
        age INTEGER,
        conditionOrPurpose TEXT,
        selectedServices TEXT,
        totalPrice REAL,
        status TEXT NOT NULL,
        paymentStatus TEXT,
        createdAt TEXT NOT NULL,
        addedByUserId TEXT,
        servedAt TEXT,
        removedAt TEXT,
        consultationStartedAt TEXT,
        originalAppointmentId TEXT,
        doctorId TEXT,
        doctorName TEXT,
        isWalkIn INTEGER DEFAULT 0 NOT NULL
      )
    ''');
    debugPrint('DATABASE_HELPER: Table $tableActivePatientQueue created');

    // Create admin user by default
    await _createDefaultAdmin(db);

    // Seed initial clinic services
    await _seedInitialClinicServices(db); // Added call to seed services

    // Create Indexes (for new databases v7+)
    await _createIndexes(db);

    debugPrint("DATABASE_HELPER: All tables created in batch.");
  }

  // Database upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        "DATABASE_HELPER: Upgrading database from version $oldVersion to $newVersion");

    if (oldVersion < 23) {
      // A consolidated block for migrations that should have happened before v23
      debugPrint("DATABASE_HELPER: Applying migrations for versions < 23.");
      // This creates tables that might be missing in very old versions.
      await db.execute(
          ''' CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableMedicalRecords} (id TEXT PRIMARY KEY, patientId TEXT NOT NULL, appointmentId TEXT, serviceId TEXT, recordType TEXT NOT NULL, recordDate TEXT NOT NULL, diagnosis TEXT, treatment TEXT, prescription TEXT, labResults TEXT, notes TEXT, doctorId TEXT NOT NULL, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL, FOREIGN KEY (patientId) REFERENCES ${DatabaseHelper.tablePatients} (id) ON DELETE CASCADE, FOREIGN KEY (appointmentId) REFERENCES ${DatabaseHelper.tableAppointments} (id) ON DELETE SET NULL, FOREIGN KEY (serviceId) REFERENCES ${DatabaseHelper.tableClinicServices} (id) ON DELETE SET NULL, FOREIGN KEY (doctorId) REFERENCES ${DatabaseHelper.tableUsers} (id)) ''');
      await db.execute(
          ''' CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableClinicServices} (id TEXT PRIMARY KEY, serviceName TEXT NOT NULL UNIQUE, description TEXT, category TEXT, defaultPrice REAL, selectionCount INTEGER DEFAULT 0 NOT NULL) ''');
      await db.execute(
          ''' CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableUserActivityLog} (id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT NOT NULL, actionDescription TEXT NOT NULL, targetRecordId TEXT, targetTable TEXT, timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, details TEXT, FOREIGN KEY (userId) REFERENCES $tableUsers (id)) ''');
      await db.execute(
          ''' CREATE TABLE IF NOT EXISTS $tablePatientBills (id TEXT PRIMARY KEY, patientId TEXT NOT NULL, billDate TEXT NOT NULL, totalAmount REAL NOT NULL, status TEXT NOT NULL, notes TEXT, FOREIGN KEY (patientId) REFERENCES $tablePatients (id) ON DELETE CASCADE) ''');
      await db.execute(
          ''' CREATE TABLE IF NOT EXISTS $tableBillItems (id INTEGER PRIMARY KEY AUTOINCREMENT, billId TEXT NOT NULL, serviceId TEXT, description TEXT NOT NULL, quantity INTEGER NOT NULL DEFAULT 1, unitPrice REAL NOT NULL, itemTotal REAL NOT NULL, FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE CASCADE, FOREIGN KEY (serviceId) REFERENCES $tableClinicServices (id)) ''');
      await db.execute(
          ''' CREATE TABLE IF NOT EXISTS $tablePayments (id INTEGER PRIMARY KEY AUTOINCREMENT, billId TEXT, patientId TEXT NOT NULL, referenceNumber TEXT UNIQUE NOT NULL, paymentDate TEXT NOT NULL, amountPaid REAL NOT NULL, paymentMethod TEXT NOT NULL, receivedByUserId TEXT NOT NULL, notes TEXT, FOREIGN KEY (billId) REFERENCES $tablePatientBills (id) ON DELETE SET NULL, FOREIGN KEY (patientId) REFERENCES $tablePatients (id), FOREIGN KEY (receivedByUserId) REFERENCES $tableUsers (id)) ''');

      // Add columns that were introduced over time before v23
      await _addColumnIfNotExists(
          db, tableAppointments, 'originalAppointmentId', 'TEXT');
      await _addColumnIfNotExists(
          db, tableAppointments, 'consultationStartedAt', 'TEXT');
      await _addColumnIfNotExists(db, tableAppointments, 'servedAt', 'TEXT');
      await _addColumnIfNotExists(
          db, tableAppointments, 'selectedServices', 'TEXT');
      await _addColumnIfNotExists(db, tableAppointments, 'totalPrice', 'REAL');
      await _addColumnIfNotExists(
          db, tableAppointments, 'paymentStatus', 'TEXT');
      await _addColumnIfNotExists(db, tablePayments, 'totalBillAmount', 'REAL');
      await _addColumnIfNotExists(db, tablePayments, 'invoiceNumber', 'TEXT');
    }

    if (oldVersion < 24) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 24: Modifying $tablePatientBills and $tablePayments for enhanced invoicing.");
      await _addColumnIfNotExists(
          db, tablePatientBills, 'invoiceNumber', 'TEXT');
      await _addColumnIfNotExists(db, tablePatientBills, 'dueDate', 'TEXT');
      await _addColumnIfNotExists(db, tablePatientBills, 'subtotal', 'REAL');
      await _addColumnIfNotExists(
          db, tablePatientBills, 'discountAmount', 'REAL DEFAULT 0.0');
      await _addColumnIfNotExists(
          db, tablePatientBills, 'taxAmount', 'REAL DEFAULT 0.0');
      await _addColumnIfNotExists(db, tablePatientBills, 'createdByUserId',
          'TEXT REFERENCES $tableUsers(id)');

      try {
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_invoiceNumber ON $tablePatientBills (invoiceNumber) WHERE invoiceNumber IS NOT NULL;');
      } catch (e) {
        debugPrint(
            "DATABASE_HELPER: Warning - Could not create unique index on $tablePatientBills(invoiceNumber). This might be due to existing data. $e");
      }

      await _addColumnIfNotExists(db, tablePayments, 'invoiceNumber', 'TEXT');
      await _addColumnIfNotExists(db, tablePayments, 'totalBillAmount', 'REAL');
    }

    if (oldVersion < 25) {
      await _addColumnIfNotExists(
          db, tableActivePatientQueue, 'doctorId', 'TEXT');
      await _addColumnIfNotExists(
          db, tableActivePatientQueue, 'doctorName', 'TEXT');
    }

    if (oldVersion < 26) {
      await _addColumnIfNotExists(db, tableAppointments, 'cancelledAt', 'TEXT');
    }

    if (oldVersion < 27) {
      // This migration ensures columns from the Appointment model are present.
      // The error "no column named cancelledAt" suggests a schema mismatch.
      await _addColumnIfNotExists(db, tableAppointments, 'cancelledAt', 'TEXT');
      await _addColumnIfNotExists(
          db, tableAppointments, 'cancellationReason', 'TEXT');
      await _addColumnIfNotExists(db, tableAppointments, 'notes', 'TEXT');
      await _addColumnIfNotExists(
          db, tableAppointments, 'isWalkIn', 'INTEGER DEFAULT 0');
    }

    if (oldVersion < 28) {
      await _addColumnIfNotExists(db, tableActivePatientQueue, 'isWalkIn',
          'INTEGER DEFAULT 0 NOT NULL');
    }

    if (oldVersion < 29) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 29: Seeding new clinic services.");
      await _seedInitialClinicServicesWithExecutor(db);
    }

    if (oldVersion < 30) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 30: Recreating patients table with simplified schema.");
      await db.execute('DROP TABLE IF EXISTS $tablePatients');
      await db.execute('''
        CREATE TABLE $tablePatients (
          id TEXT PRIMARY KEY,
          fullName TEXT,
          birthDate TEXT,
          gender TEXT,
          contactNumber TEXT,
          email TEXT,
          address TEXT,
          bloodType TEXT,
          allergies TEXT,
          currentMedications TEXT,
          medicalHistory TEXT,
          emergencyContactName TEXT,
          emergencyContactNumber TEXT,
          createdAt TEXT,
          updatedAt TEXT 
        )
      ''');
    }

    if (oldVersion < 31) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 31: Adding registrationDate to patients table.");
      await _addColumnIfNotExists(
          db, tablePatients, 'registrationDate', 'TEXT');
    }

    if (oldVersion < 32) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 32: Adding patient_history table.");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tablePatientHistory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patientId TEXT NOT NULL,
          fieldName TEXT NOT NULL,
          oldValue TEXT,
          newValue TEXT,
          updatedAt TEXT NOT NULL,
          updatedByUserId TEXT,
          sourceOfChange TEXT,
          FOREIGN KEY (patientId) REFERENCES $tablePatients(id) ON DELETE CASCADE,
          FOREIGN KEY (updatedByUserId) REFERENCES $tableUsers(id) ON DELETE SET NULL
        )
      ''');
      await _createIndexesForTable(db, tablePatientHistory, {
        'idx_patient_history_patientId': 'patientId',
        'idx_patient_history_updatedAt': 'updatedAt',
      });
    }
    if (oldVersion < 33) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 33: Adding patientName to payments table.");
      await _addColumnIfNotExists(db, tablePayments, 'patientName',
          'TEXT NOT NULL DEFAULT \'Unknown\'');
    }
    if (oldVersion < 34) {
      debugPrint(
          "DATABASE_HELPER: Upgrading to version 34: Adding selectedServices to medical_records table.");
      await _addColumnIfNotExists(
          db, tableMedicalRecords, 'selectedServices', 'TEXT');
    }

    debugPrint(
        "DATABASE_HELPER: Database upgrade from v$oldVersion to v$newVersion complete.");
  }

  Future<void> _addColumnIfNotExists(Database db, String tableName,
      String columnName, String columnType) async {
    var result = await db.rawQuery('PRAGMA table_info($tableName)');
    bool columnExists = result.any((column) => column['name'] == columnName);
    if (!columnExists) {
      await db
          .execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
      debugPrint('DATABASE_HELPER: Added column $columnName to $tableName');
    } else {
      debugPrint(
          'DATABASE_HELPER: Column $columnName already exists in $tableName');
    }
  }

  Future<void> _createIndexesForTable(
      Database db, String tableName, Map<String, String> indexes) async {
    for (var indexName in indexes.keys) {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS $indexName ON $tableName (${indexes[indexName]})');
    }
    debugPrint('DATABASE_HELPER: Created indexes for table $tableName');
  }

  // Create default admin user
  Future<void> _createDefaultAdmin(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Hash the default admin password
    final String hashedPassword = AuthService.hashPassword('admin123');
    final String hashedAnswer1 = AuthService.hashSecurityAnswer('blue');
    final String hashedAnswer2 = AuthService.hashSecurityAnswer('anytown');
    final String hashedAnswer3 = AuthService.hashSecurityAnswer('alex');

    await db.insert(DatabaseHelper.tableUsers, {
      'id': 'admin-${DateTime.now().millisecondsSinceEpoch}',
      'username': 'admin',
      'password': hashedPassword, // Store hashed password
      'fullName': 'System Administrator',
      'role': 'admin',
      'securityQuestion1': 'What is your favorite color?',
      'securityAnswer1': hashedAnswer1,
      'securityQuestion2': 'In what city were you born?',
      'securityAnswer2': hashedAnswer2,
      'securityQuestion3': "What is your oldest sibling's middle name?",
      'securityAnswer3': hashedAnswer3,
      'createdAt': now,
      'isActive': 1
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

  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    return userDbService.authenticateUser(username, password);
  }

  Future<bool> resetPassword(String username, String securityQuestion,
      String securityAnswer, String newPassword) async {
    return userDbService.resetPassword(
        username, securityQuestion, securityAnswer, newPassword);
  }

  // PATIENT MANAGEMENT METHODS (Delegating to PatientDatabaseService)
  Future<String> insertPatient(Map<String, dynamic> patient) async {
    return patientDbService.insertPatient(patient);
  }

  Future<int> updatePatient(Map<String, dynamic> patient,
      {String? userId, String? source}) async {
    return patientDbService.updatePatient(patient,
        userId: userId, source: source);
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
    return patientDbService.findRegisteredPatient(
        patientId: patientId, fullName: fullName);
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

  Future<List<Appointment>> getAllAppointments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableAppointments,
      orderBy: 'date DESC, time DESC',
    );
    return List.generate(maps.length, (i) {
      return Appointment.fromMap(maps[i]);
    });
  }

  Future<List<Appointment>> getAppointmentsForRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

    final List<Map<String, dynamic>> maps = await db.query(
      tableAppointments,
      where: "DATE(date) BETWEEN ? AND ?",
      whereArgs: [startDateStr, endDateStr],
    );

    return List.generate(maps.length, (i) {
      return Appointment.fromMap(maps[i]);
    });
  }

  Future<void> updatePatientQueueFromSync(
      Map<String, dynamic> queueData) async {
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

  // Get all medical records
  Future<List<Map<String, dynamic>>> getAllMedicalRecords({int? limit}) async {
    final db = await database;
    return await db.query(
      DatabaseHelper.tableMedicalRecords,
      orderBy: 'recordDate DESC',
      limit: limit,
    );
  }

  // Get medical records by service
  Future<List<Map<String, dynamic>>> getMedicalRecordsByService(
      String serviceId) async {
    final db = await database;
    // The selectedServices field stores a JSON list of maps.
    // We use LIKE to find records where the serviceId is present as a key-value pair.
    try {
      final results = await db.query(
        DatabaseHelper.tableMedicalRecords,
        where:
            "selectedServices LIKE ? AND selectedServices IS NOT NULL AND selectedServices != ''",
        whereArgs: [
          '%"id":"$serviceId"%'
        ], // Search for the service ID within the JSON string
        orderBy: 'recordDate DESC',
      );
      debugPrint(
          'DatabaseHelper: Found ${results.length} records for service $serviceId');
      return results;
    } catch (e) {
      debugPrint(
          'DatabaseHelper: Error querying medical records by service: $e');
      return [];
    }
  }

  // DATABASE SYNCHRONIZATION METHODS

  // Log changes for synchronization
  Future<void> logChange(String tableName, String recordId, String action,
      {DatabaseExecutor? executor, Map<String, dynamic>? data}) async {
    final exec = executor ?? await database;
    await exec.insert(DatabaseHelper.tableSyncLog, {
      'tableName': tableName,
      'recordId': recordId,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });

    // IMPORTANT: Trigger real-time sync notification for immediate broadcasting
    try {
      await _notifyDatabaseChange(tableName, action, recordId, data: data);
    } catch (e) {
      debugPrint('Failed to send real-time sync notification: $e');
      // Don't fail the main operation if real-time sync fails
    }
  }

  // Helper method to notify LAN sync service of database changes
  Future<void> _notifyDatabaseChange(
      String table, String operation, String recordId,
      {Map<String, dynamic>? data}) async {
    // Use a callback-based approach to avoid circular imports
    if (_onDatabaseChanged != null) {
      try {
        await _onDatabaseChanged!(table, operation, recordId, data);
      } catch (e) {
        debugPrint('Real-time sync notification failed: $e');
      }
    }
  }

  // Static method to register database change callback
  static void setDatabaseChangeCallback(
      Future<void> Function(String table, String operation, String recordId,
              Map<String, dynamic>? data)
          callback) {
    _onDatabaseChanged = callback;
  }

  // Static method to clear database change callback
  static void clearDatabaseChangeCallback() {
    _onDatabaseChanged = null;
  }

  // Static callback for database change notifications (set by LanSyncService)
  static Future<void> Function(String table, String operation, String recordId,
      Map<String, dynamic>? data)? _onDatabaseChanged;

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
    try {
      // Check if sync is enabled
      final prefs = await SharedPreferences.getInstance();
      final syncEnabled = prefs.getBool('sync_enabled') ?? false;

      if (!syncEnabled) {
        debugPrint('Sync disabled in settings');
        return true;
      }

      // Check if we have server connection info
      final serverIp = prefs.getString('lan_server_ip');
      final serverPortValue = prefs.get('lan_server_port');
      final accessCode = prefs.getString('lan_access_code');

      // Handle both int and string values for port
      String? serverPort;
      if (serverPortValue is int) {
        serverPort = serverPortValue.toString();
      } else if (serverPortValue is String) {
        serverPort = serverPortValue;
      }

      if (serverIp == null || serverPort == null || accessCode == null) {
        debugPrint('Sync disabled - no server configured');
        return true;
      }

      // Try to sync with the configured server
      final port = int.tryParse(serverPort) ?? 8080;
      return await _performServerSync(serverIp, port, accessCode);
    } catch (e) {
      debugPrint('Sync error: $e');
      return false;
    }
  }

  // Perform actual server sync
  Future<bool> _performServerSync(
      String serverIp, int port, String accessCode) async {
    try {
      // This is a placeholder for actual sync implementation
      // You can implement the actual sync logic here
      debugPrint('Syncing with server at $serverIp:$port');
      return true;
    } catch (e) {
      debugPrint('Server sync failed: $e');
      return false;
    }
  }

  // Apply changes from server
  // Future<void> _applyServerChanges(List<dynamic> changes) async {
  //   final db = await database;
  //   final batch = db.batch();

  //   for (final change in changes) {
  //     final String tableName = change['tableName'];
  //     final String recordId = change['recordId'];
  //     final String action = change['action'];
  //     final Map<String, dynamic> data = change['data'];

  //     switch (action) {
  //       case 'insert':
  //         batch.insert(tableName, data);
  //         break;
  //       case 'update':
  //         batch.update(
  //           tableName,
  //           data,
  //           where: 'id = ?',
  //           whereArgs: [recordId],
  //         );
  //         break;
  //       case 'delete':
  //         batch.delete(
  //           tableName,
  //           where: 'id = ?',
  //           whereArgs: [recordId],
  //         );
  //         break;
  //     }
  //   }

  //   await batch.commit();
  // }

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
            debugPrint('External storage not available: $e');
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
          debugPrint('Error exporting to external location: $e');
          // Continue with original path
        }
      }

      // Return original path if we couldn't copy
      return dbPath;
    } catch (e) {
      debugPrint('Database export error: $e');
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

    // Indexes for patient_history table
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patient_history_patientId ON $tablePatientHistory (patientId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patient_history_updatedAt ON $tablePatientHistory (updatedAt)');

    debugPrint('DATABASE_HELPER: Ensured all indexes are created.');
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
    await logChange(
        DatabaseHelper.tableActivePatientQueue, item.queueEntryId, 'insert');
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
      await logChange(
          DatabaseHelper.tableActivePatientQueue, queueEntryId, 'delete');
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
      await logChange(
          DatabaseHelper.tableActivePatientQueue, queueEntryId, 'update');
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
      await logChange(
          DatabaseHelper.tableActivePatientQueue, item.queueEntryId, 'update');
    }
    return result;
  }

  /// Gets the current active patient queue, ordered by arrival time.
  /// Optionally filters by status(es).
  /// Now includes queue items from the last 2 days to handle relog visibility issues.
  Future<List<ActivePatientQueueItem>> getActiveQueue(
      {List<String>? statuses}) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Default to fetching only for today unless a broader context is implied by lack of status filter
    // or if a specific date range mechanism is added here later.
    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    // final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
    // final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

    // Filter by today's arrivalTime
    whereClauses.add('DATE(arrivalTime) = DATE(?)');
    whereArgs.add(todayDate); // Using YYYY-MM-DD for DATE() comparison
    // Or, for more precision if arrivalTime is full ISO string:
    // whereClauses.add('arrivalTime >= ? AND arrivalTime <= ?');
    // whereArgs.add(startOfToday);
    // whereArgs.add(endOfToday);

    if (statuses != null && statuses.isNotEmpty) {
      whereClauses.add('status IN (${statuses.map((_) => '?').join(',')})');
      whereArgs.addAll(statuses);
    }

    final String? finalWhereClause =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableActivePatientQueue,
      where: finalWhereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
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

  /// Gets all items from the active queue table.
  Future<List<ActivePatientQueueItem>> getAllActiveQueueItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableActivePatientQueue,
      orderBy: 'arrivalTime DESC',
    );
    return maps.map((item) => ActivePatientQueueItem.fromJson(item)).toList();
  }

  /// Clears all entries from the active_patient_queue table (e.g., at the end of a day).
  Future<int> clearActiveQueue() async {
    final db = await database;
    final count = await db.delete(DatabaseHelper.tableActivePatientQueue);
    // Optionally log this as a bulk operation if needed, though logChange is per-record.
    // For simplicity, not logging each deletion during a clear.
    debugPrint(
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
    debugPrint(
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
  /// including 'billId' (optional, but crucial for updating invoice status),
  /// 'patientId', 'referenceNumber', 'paymentDate',
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

    final String? billId = paymentData['billId'] as String?;
    late int paymentId;

    await db.transaction((txn) async {
      // 1. Insert into tablePayments
      // The 'id' for payments is AUTOINCREMENT, so we don't set it here.
      paymentId = await txn.insert(DatabaseHelper.tablePayments, paymentData);

      if (paymentId > 0) {
        // Log change for the payment itself
        await logChange(
            DatabaseHelper.tablePayments, paymentId.toString(), 'insert',
            executor: txn);

        // 2. If billId is provided, update the status of the bill in tablePatientBills
        if (billId != null && billId.isNotEmpty) {
          final int updateCount = await txn.update(
            DatabaseHelper.tablePatientBills,
            {'status': 'Paid'},
            where: 'id = ?',
            whereArgs: [billId],
          );
          if (updateCount > 0) {
            debugPrint(
                'DATABASE_HELPER: Updated status to Paid for billId: $billId');
            // Optionally log this change too if your sync logic requires tracking bill status updates
            await logChange(DatabaseHelper.tablePatientBills, billId, 'update',
                executor: txn);
          } else {
            debugPrint(
                'DATABASE_HELPER: Warning - Tried to update status for billId: $billId but no row was updated.');
            // This might happen if the billId is incorrect or already deleted.
          }
        }
      }
    });
    return paymentId;
  }

  Future<int> deleteActiveQueueItemByQueueEntryId(String queueEntryId) async {
    final db = await database;
    try {
      final result = await db.delete(
        tableActivePatientQueue,
        where: 'queueEntryId = ?',
        whereArgs: [queueEntryId],
      );
      debugPrint(
          "DatabaseHelper: Deleted active queue item with queueEntryId: $queueEntryId, rows affected: $result");
      return result;
    } catch (e) {
      debugPrint(
          "DatabaseHelper: Error deleting active queue item with queueEntryId $queueEntryId: $e");
      return 0; // Or throw, depending on error handling strategy
    }
  }

  // Clinic Service Methods (Added/Updated)
  Future<void> incrementServiceSelectionCounts(List<String> serviceIds) async {
    if (serviceIds.isEmpty) {
      return;
    }
    final db = await database;
    try {
      await db.transaction((txn) async {
        for (String id in serviceIds) {
          final List<Map<String, dynamic>> currentService = await txn.query(
            DatabaseHelper.tableClinicServices,
            columns: ['selectionCount'],
            where: 'id = ?',
            whereArgs: [id],
          );

          if (currentService.isNotEmpty) {
            int currentCount =
                currentService.first['selectionCount'] as int? ?? 0;
            await txn.update(
              DatabaseHelper.tableClinicServices,
              {'selectionCount': currentCount + 1},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      });
      debugPrint(
          'DatabaseHelper: Incremented selection count for services: $serviceIds');
    } catch (e) {
      debugPrint(
          'DatabaseHelper: Error incrementing service selection counts: $e');
    }
  }

  // Helper method to check if a service already exists by name (for seeding)
  Future<Map<String, dynamic>?> _getClinicServiceByName(
      DatabaseExecutor db, String name) async {
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'LOWER(serviceName) = LOWER(?)', // Case-insensitive check
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Method to seed initial clinic services
  Future<void> _seedInitialClinicServices(Database db) async {
    return _seedInitialClinicServicesWithExecutor(db);
  }

  Future<void> _seedInitialClinicServicesWithExecutor(
      DatabaseExecutor db) async {
    var uuid = const Uuid();
    final initialServices = [
      // Services from add_to_queue_screen.dart
      {'name': 'Consultation', 'category': 'Consultation', 'price': 500.0},
      {'name': 'Chest X-ray', 'category': 'Laboratory', 'price': 350.0},
      {'name': 'ECG', 'category': 'Laboratory', 'price': 650.0},
      {'name': 'Fasting Blood Sugar', 'category': 'Laboratory', 'price': 150.0},
      {'name': 'Total Cholesterol', 'category': 'Laboratory', 'price': 250.0},
      {'name': 'Triglycerides', 'category': 'Laboratory', 'price': 250.0},
      {
        'name': 'High Density Lipoprotein (HDL)',
        'category': 'Laboratory',
        'price': 250.0
      },
      {
        'name': 'Low Density Lipoprotein (LDL)',
        'category': 'Laboratory',
        'price': 200.0
      },
      {'name': 'Blood Uric Acid', 'category': 'Laboratory', 'price': 200.0},
      {'name': 'Creatinine', 'category': 'Laboratory', 'price': 200.0},
      {
        'name': 'Serum Glutamic Pyruvic Transaminase (SGPT)',
        'category': 'Laboratory',
        'price': 250.0
      },
      {
        'name': 'Serum Glutamic Oxaloacetic Transaminase',
        'category': 'Laboratory',
        'price': 250.0
      },
      {
        'name': 'Very Low Density Lipoprotein (VLDL)',
        'category': 'Laboratory',
        'price': 100.0
      },
      {'name': 'Blood Urea Nitrogen', 'category': 'Laboratory', 'price': 200.0},
      {'name': 'CBC W/ Platelet', 'category': 'Laboratory', 'price': 250.0},
    ];

    for (var serviceData in initialServices) {
      final existingService =
          await _getClinicServiceByName(db, serviceData['name'] as String);
      if (existingService == null) {
        final newService = ClinicService(
          id: uuid.v4(),
          serviceName: serviceData['name'] as String,
          category: serviceData['category'] as String?,
          defaultPrice: serviceData['price'] as double?,
          description: null, // Add a description if available
          selectionCount: 0, // Initial count
        );
        try {
          await db.insert(
            DatabaseHelper.tableClinicServices,
            newService.toJson(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          debugPrint(
              'DATABASE_HELPER: Seeded service: ${newService.serviceName}');
        } catch (e) {
          debugPrint(
              'DATABASE_HELPER: Error seeding service ${newService.serviceName}: $e');
        }
      } else {
        debugPrint(
            'DATABASE_HELPER: Service already exists, not seeding: ${serviceData['name']}');
      }
    }
  }

  // Method to insert invoice, bill items, and payment in a single transaction
  Future<Map<String, String>> recordInvoiceAndPayment({
    String? displayInvoiceNumber,
    required ActivePatientQueueItem patient,
    required List<Map<String, dynamic>>
        billItemsJson, // Using raw Map for items from ActivePatientQueueItem.selectedServices
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double totalAmount, // Final amount for the bill
    required DateTime invoiceDate,
    required DateTime dueDate,
    required String currentUserId,
    required double amountPaidByCustomer, // Actual amount paid by customer
    required String paymentMethod,
    String? paymentNotes,
  }) async {
    final db = await database;

    // Use a transaction to ensure all or nothing
    return await db.transaction<Map<String, String>>((txn) async {
      // Check for an existing unpaid bill for this patient that was created recently.
      // This is a heuristic to find the right bill to associate this payment with.
      List<Map<String, dynamic>> existingUnpaidBills = await txn.query(
        tablePatientBills,
        where: 'patientId = ? AND status = ?',
        whereArgs: [patient.patientId, 'Unpaid'],
        orderBy: 'billDate DESC',
      );

      String billDbId;
      String invoiceNumber;

      if (existingUnpaidBills.isNotEmpty) {
        // Found an unpaid bill, let's use it
        final existingBill = existingUnpaidBills.first;
        billDbId = existingBill['id'] as String;
        invoiceNumber = existingBill['invoiceNumber'] as String;

        // Update the bill status to 'Paid'
        await txn.update(
          tablePatientBills,
          {'status': 'Paid', 'notes': 'Previously unpaid bill now paid.'},
          where: 'id = ?',
          whereArgs: [billDbId],
        );
        debugPrint(
            'DATABASE_HELPER: Found existing unpaid bill $invoiceNumber. Updating status to Paid.');
      } else {
        // No unpaid bill found, create a new one.
        billDbId = 'BILL-${const Uuid().v4()}';
        invoiceNumber = displayInvoiceNumber ??
            'INV-${const Uuid().v4().substring(0, 6).toUpperCase()}';

        Map<String, dynamic> billData = {
          'id': billDbId,
          'patientId': patient.patientId,
          'invoiceNumber': invoiceNumber,
          'billDate': invoiceDate.toIso8601String(),
          'dueDate': dueDate.toIso8601String(),
          'subtotal': subtotal,
          'discountAmount': discountAmount,
          'taxAmount': taxAmount,
          'totalAmount': totalAmount,
          'status': 'Paid',
          'createdByUserId': currentUserId,
          'notes':
              'Invoice for services related to: ${patient.conditionOrPurpose ?? 'Consultation'}'
        };
        await txn.insert(tablePatientBills, billData);

        // Insert bill items
        for (var itemJson in billItemsJson) {
          final unitPrice = (itemJson['price'] as num?)?.toDouble() ?? 0.0;
          final quantity = itemJson['quantity'] as int? ?? 1;
          final itemDescription =
              itemJson['name'] as String? ?? 'Unknown Service';
          final serviceId = itemJson['id'] as String?;

          Map<String, dynamic> billItemData = {
            'billId': billDbId,
            'serviceId': serviceId,
            'description': itemDescription,
            'quantity': quantity,
            'unitPrice': unitPrice,
            'itemTotal': unitPrice * quantity,
          };
          await txn.insert(tableBillItems, billItemData);
        }

        if (billItemsJson.isEmpty &&
            patient.totalPrice != null &&
            patient.totalPrice! > 0) {
          Map<String, dynamic> generalBillItemData = {
            'billId': billDbId,
            'description':
                patient.conditionOrPurpose ?? 'General Clinic Services',
            'quantity': 1,
            'unitPrice': patient.totalPrice,
            'itemTotal': patient.totalPrice,
          };
          await txn.insert(tableBillItems, generalBillItemData);
        }
        debugPrint(
            'DATABASE_HELPER: No existing unpaid bill found. Created new bill $invoiceNumber.');
      }

      // Record the payment associated with the bill (either existing or new)
      final String uuidString = const Uuid().v4().replaceAll('-', '');
      final String paymentReferenceNumber =
          'PAY-${uuidString.substring(0, 8).toUpperCase()}';

      Map<String, dynamic> paymentData = {
        'billId': billDbId,
        'patientId': patient.patientId!,
        'patientName': patient.patientName,
        'invoiceNumber': invoiceNumber,
        'referenceNumber': paymentReferenceNumber,
        'paymentDate': DateTime.now().toIso8601String(),
        'amountPaid': amountPaidByCustomer,
        'totalBillAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'receivedByUserId': currentUserId,
        'notes': paymentNotes ?? 'Payment for Invoice #$invoiceNumber',
      };
      await txn.insert(tablePayments, paymentData);

      debugPrint(
          'DATABASE_HELPER: Successfully recorded payment $paymentReferenceNumber for invoice $invoiceNumber.');

      return {
        'invoiceNumber': invoiceNumber,
        'paymentReferenceNumber': paymentReferenceNumber,
      };
    });
  }

  // Method to record an invoice as unpaid (without payment)
  Future<String> recordUnpaidInvoice({
    required String displayInvoiceNumber, // e.g., "INV-XYZ123"
    required String? patientId,
    required List<Map<String, dynamic>> billItemsJson,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double totalAmount, // Final amount for the bill
    required DateTime invoiceDate,
    required DateTime dueDate,
    required String currentUserId,
    String? notes,
  }) async {
    final db = await database;
    final String billDbId =
        'BILL-${const Uuid().v4()}'; // Internal DB ID for the bill

    await db.transaction((txn) async {
      // 1. Insert into tablePatientBills
      Map<String, dynamic> billData = {
        'id': billDbId,
        'patientId': patientId,
        'invoiceNumber': displayInvoiceNumber,
        'billDate': invoiceDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        'totalAmount': totalAmount,
        'status': 'Unpaid', // Crucial difference: Mark as Unpaid
        'createdByUserId': currentUserId,
        'notes': notes ?? 'Unpaid invoice generated for services.',
      };
      await txn.insert(tablePatientBills, billData);
      await logChange(tablePatientBills, billDbId, 'insert', executor: txn);

      // 2. Insert into tableBillItems
      for (var itemJson in billItemsJson) {
        final unitPrice = (itemJson['price'] as num?)?.toDouble() ??
            (itemJson['unitPrice'] as num?)?.toDouble() ??
            0.0;
        final quantity = itemJson['quantity'] as int? ?? 1;
        final itemDescription = itemJson['name'] as String? ??
            itemJson['description'] as String? ??
            'Unknown Service';
        final serviceId =
            itemJson['id'] as String? ?? itemJson['serviceId'] as String?;
        final itemTotal = (itemJson['itemTotal'] as num?)?.toDouble() ??
            (unitPrice * quantity);

        Map<String, dynamic> billItemData = {
          'billId': billDbId,
          'serviceId': serviceId,
          'description': itemDescription,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'itemTotal': itemTotal,
        };
        await txn.insert(tableBillItems, billItemData);
      }

      if (billItemsJson.isEmpty && totalAmount > 0 && subtotal == 0) {
        Map<String, dynamic> generalBillItemData = {
          'billId': billDbId,
          'description': notes ?? 'General Clinic Services (Unpaid)',
          'quantity': 1,
          'unitPrice': totalAmount,
          'itemTotal': totalAmount,
        };
        await txn.insert(tableBillItems, generalBillItemData);
      }
    });

    debugPrint(
        'DATABASE_HELPER: Successfully recorded UNPAID invoice $displayInvoiceNumber.');
    return displayInvoiceNumber;
  }

  Future<List<Map<String, dynamic>>> getBillItems(String billId) async {
    final db = await database;
    return await db.query(
      tableBillItems,
      where: 'billId = ?',
      whereArgs: [billId],
    );
  }

  // New method to get bill, bill items, and patient details by invoice number
  Future<Map<String, dynamic>?> getPatientBillByInvoiceNumber(
      String invoiceNumber) async {
    final db = await database;
    Map<String, dynamic>? result;

    // 1. Find the bill by invoice number
    final List<Map<String, dynamic>> bills = await db.query(
      tablePatientBills,
      where: 'invoiceNumber = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );

    if (bills.isNotEmpty) {
      final billData = bills.first;
      final String billId = billData['id'] as String;
      final String? patientId = billData['patientId'] as String?;

      List<Map<String, dynamic>> billItemsData = [];
      Map<String, dynamic>? patientData;

      // 2. Fetch bill items for this bill
      billItemsData = await db.query(
        tableBillItems,
        where: 'billId = ?',
        whereArgs: [billId],
      );

      // 3. Fetch patient details if patientId exists
      if (patientId != null && patientId.isNotEmpty) {
        final List<Map<String, dynamic>> patients = await db.query(
          tablePatients,
          where: 'id = ?',
          whereArgs: [patientId],
          limit: 1,
        );
        if (patients.isNotEmpty) {
          patientData = patients.first;
        }
      }

      result = {
        'bill': billData,
        'items': billItemsData,
        'patient':
            patientData, // This can be null if patientId was null or patient not found
      };
    }
    return result;
  }

  /// Resets the database by deleting all records from all tables, except for the admin user and clinic services.
  Future<void> resetDatabase() async {
    final db = await database;
    debugPrint('DATABASE_HELPER: Starting database reset...');

    // ClinicServices is now excluded from this list.
    final List<String> tablesToClear = [
      tablePatients,
      tableAppointments,
      tableMedicalRecords,
      tableUserActivityLog,
      tablePatientBills,
      tableBillItems,
      tablePayments,
      tableSyncLog,
      tablePatientQueue,
      tableActivePatientQueue,
      tablePatientHistory,
    ];

    await db.transaction((txn) async {
      // Clear all specified tables completely
      for (final table in tablesToClear) {
        await txn.delete(table);
        debugPrint('DATABASE_HELPER: Cleared table: $table');
      }

      // Clear users table, but keep the admin
      await txn.delete(
        tableUsers,
        where: "role != ?",
        whereArgs: ['admin'],
      );
      debugPrint('DATABASE_HELPER: Cleared table: $tableUsers (except admin)');

      // Re-seed the initial clinic services to restore them if they were accidentally wiped.
      // This is safe to run multiple times as it checks for existence before inserting.
      await _seedInitialClinicServicesWithExecutor(txn);
      debugPrint(
          'DATABASE_HELPER: Ensured initial clinic services are present.');
    });

    debugPrint('DATABASE_HELPER: Database reset completed successfully.');
  }

  Future<Map<String, int>> getDashboardStatistics() async {
    final db = await database;

    final totalPatients = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tablePatients')) ??
        0;

    final confirmedAppointments = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableAppointments WHERE status = ?',
            ['Confirmed'])) ??
        0;
    final cancelledAppointments = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableAppointments WHERE status = ?',
            ['Cancelled'])) ??
        0;
    final completedAppointments = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableAppointments WHERE status = ?',
            ['Completed'])) ??
        0;

    return {
      'totalPatients': totalPatients,
      'confirmedAppointments': confirmedAppointments,
      'cancelledAppointments': cancelledAppointments,
      'completedAppointments': completedAppointments,
    };
  }

  // Close database
  Future<void> close() async {
    final db = _instanceDatabase;
    if (db != null) {
      await db.close();
      _instanceDatabase = null;
    }
  }

  // Method to get unpaid bills with patient details
  Future<List<Map<String, dynamic>>> getUnpaidBills({
    String? patientIdOrName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String query = '''
      SELECT pb.*, 
             pt.fullName as patient_name,
             pt.contactNumber as patient_contact,
             u.fullName as created_by_user_name
      FROM $tablePatientBills pb
      LEFT JOIN $tablePatients pt ON pb.patientId = pt.id
      LEFT JOIN $tableUsers u ON pb.createdByUserId = u.id
      WHERE pb.status = 'Unpaid'
    ''';

    List<dynamic> arguments = [];

    if (patientIdOrName != null && patientIdOrName.isNotEmpty) {
      query += ' AND (pt.id = ? OR pt.fullName LIKE ?)';
      arguments.add(patientIdOrName);
      arguments.add('%$patientIdOrName%');
    }

    if (startDate != null) {
      query += ' AND DATE(pb.billDate) >= DATE(?)';
      arguments.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      query += ' AND DATE(pb.billDate) <= DATE(?)';
      arguments.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    query += ' ORDER BY pb.billDate DESC';

    debugPrint(
        'DATABASE_HELPER: Executing getUnpaidBills query: $query with args: $arguments');
    final List<Map<String, dynamic>> results =
        await db.rawQuery(query, arguments);
    debugPrint('DATABASE_HELPER: Found ${results.length} unpaid bills');
    return results;
  }

  // Method to get payment transactions with patient details
  Future<List<Map<String, dynamic>>> getPaymentTransactions({
    String? patientIdOrName,
    String? invoiceNumber,
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
  }) async {
    final db = await database;

    String query = '''
      SELECT p.*, 
             pt.fullName as patient_name,
             pt.contactNumber as patient_contact,
             u.fullName as received_by_user_name,
             pb.invoiceNumber as bill_invoice_number,
             pb.totalAmount as bill_total_amount
      FROM $tablePayments p
      LEFT JOIN $tablePatients pt ON p.patientId = pt.id
      LEFT JOIN $tableUsers u ON p.receivedByUserId = u.id
      LEFT JOIN $tablePatientBills pb ON p.billId = pb.id
      WHERE 1=1
    ''';

    List<dynamic> arguments = [];

    if (patientIdOrName != null && patientIdOrName.isNotEmpty) {
      query += ' AND (p.patientId = ? OR pt.fullName LIKE ?)';
      arguments.add(patientIdOrName);
      arguments.add('%$patientIdOrName%');
    }

    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      query += ' AND p.invoiceNumber LIKE ?';
      arguments.add('%$invoiceNumber%');
    }

    if (startDate != null) {
      query += ' AND DATE(p.paymentDate) >= DATE(?)';
      arguments.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      query += ' AND DATE(p.paymentDate) <= DATE(?)';
      arguments.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    if (paymentMethod != null &&
        paymentMethod != 'all' &&
        paymentMethod.isNotEmpty) {
      query += ' AND p.paymentMethod = ?';
      arguments.add(paymentMethod);
    }

    query += ' ORDER BY p.paymentDate DESC';

    debugPrint(
        'DATABASE_HELPER: Executing getPaymentTransactions query: $query with args: $arguments');
    final List<Map<String, dynamic>> results =
        await db.rawQuery(query, arguments);
    debugPrint('DATABASE_HELPER: Found ${results.length} payment transactions');
    return results;
  }

  // Method to get all details for a specific receipt
  Future<Map<String, dynamic>?> getReceiptDetails(
      String paymentReferenceNumber) async {
    final db = await database;

    // First, get the payment details
    final List<Map<String, dynamic>> payments = await db.query(
      tablePayments,
      where: 'referenceNumber = ?',
      whereArgs: [paymentReferenceNumber],
      limit: 1,
    );

    if (payments.isEmpty) {
      return null;
    }

    final payment = payments.first;
    final billId = payment['billId'] as String?;

    if (billId == null) {
      // If there's no billId, we can't fetch items, but we can still return payment info
      return {
        'payment': payment,
        'items': [], // No items to show
      };
    }

    // Now, get the associated bill items
    final List<Map<String, dynamic>> items = await db.query(
      tableBillItems,
      where: 'billId = ?',
      whereArgs: [billId],
    );

    return {
      'payment': payment,
      'items': items,
    };
  }

  // Fetches patient bills, optionally filtered by status
  Future<List<Map<String, dynamic>>> getPatientBills(
      {List<String>? statuses}) async {
    final db = await database;
    try {
      if (statuses != null && statuses.isNotEmpty) {
        // Creates a list of '?' placeholders for the IN clause
        final placeholders = List.filled(statuses.length, '?').join(',');
        return await db.query(
          tablePatientBills,
          where: 'status IN ($placeholders)',
          whereArgs: statuses,
          orderBy: 'invoiceDate DESC',
        );
      } else {
        // Fetch all bills if no status filter is provided
        return await db.query(
          tablePatientBills,
          orderBy: 'invoiceDate DESC',
        );
      }
    } catch (e) {
      debugPrint('Error fetching patient bills from DB: $e');
      return []; // Return empty list on error
    }
  }

  // Method to get a specific service by its ID
  Future<Map<String, dynamic>?> getServiceById(String serviceId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'id = ?',
      whereArgs: [serviceId],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getPatientHistory(String patientId) async {
    final db = await database;
    return await db.query(
      tablePatientHistory,
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'updatedAt DESC',
    );
  }

  Future<int> getTotalPatientsForService(String serviceId) async {
    final db = await database;
    // We search the JSON string for the service ID.
    // This is not perfectly efficient but works for SQLite.
    // The 'id' in the JSON must be wrapped in quotes.
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(DISTINCT patientId) as count FROM $tableMedicalRecords WHERE selectedServices LIKE ? AND selectedServices IS NOT NULL AND selectedServices != ?',
        ['%"id":"$serviceId"%', ''],
      );
      if (result.isNotEmpty && result.first['count'] != null) {
        final count = result.first['count'] as int;
        debugPrint(
            'DatabaseHelper: Found $count unique patients for service $serviceId');
        return count;
      }
      debugPrint('DatabaseHelper: No patients found for service $serviceId');
      return 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Error counting patients for service: $e');
      return 0;
    }
  }

  /// Fetches patient demographics (gender distribution) for a specific service.
  Future<Map<String, int>> getPatientDemographicsForService(
      String serviceId) async {
    final db = await database;
    const query = '''
      SELECT p.gender, COUNT(DISTINCT p.id) as count
      FROM $tableMedicalRecords mr
      JOIN $tablePatients p ON mr.patientId = p.id
      WHERE mr.selectedServices LIKE ?
      GROUP BY p.gender
    ''';
    final result = await db.rawQuery(query, ['%"id":"$serviceId"%']);

    final demographics = <String, int>{'Male': 0, 'Female': 0, 'Other': 0};
    for (final row in result) {
      final gender = row['gender'] as String? ?? 'Other';
      final count = row['count'] as int;
      if (demographics.containsKey(gender)) {
        demographics[gender] = count;
      } else {
        demographics['Other'] = (demographics['Other'] ?? 0) + count;
      }
    }
    return demographics;
  }

  /// Fetches financial data for a specific service, including total revenue
  /// and the number of paid vs. unpaid bills.
  Future<Map<String, dynamic>> getFinancialDataForService(
      String serviceId) async {
    final db = await database;
    const query = '''
      SELECT 
        pb.status, 
        COUNT(DISTINCT pb.id) as bill_count, 
        SUM(bi.unitPrice) as total_revenue
      FROM $tableMedicalRecords mr
      JOIN $tablePatientBills pb ON mr.patientId = pb.patientId 
      JOIN $tableBillItems bi ON pb.id = bi.billId
      WHERE mr.selectedServices LIKE ? AND bi.serviceId = ?
      GROUP BY pb.status
    ''';

    final result = await db.rawQuery(query, ['%"id":"$serviceId"%', serviceId]);

    double totalRevenue = 0;
    int paidBills = 0;
    int unpaidBills = 0;

    for (final row in result) {
      final status = row['status'] as String?;
      final revenue = (row['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final count = row['bill_count'] as int? ?? 0;

      totalRevenue += revenue;
      if (status == 'Paid') {
        paidBills += count;
      } else {
        unpaidBills += count;
      }
    }

    return {
      'totalRevenue': totalRevenue,
      'paidCount': paidBills,
      'unpaidCount': unpaidBills,
    };
  }

  /// Fetches the most recent patients who have availed a specific service.
  Future<List<Map<String, dynamic>>> getRecentPatientRecordsForService(
      String serviceId,
      {int limit = 5}) async {
    final db = await database;
    const query = '''
      SELECT p.fullName, p.id as patientId, mr.recordDate
      FROM $tableMedicalRecords mr
      JOIN $tablePatients p ON mr.patientId = p.id
      WHERE mr.selectedServices LIKE ?
      ORDER BY mr.recordDate DESC
      LIMIT ?
    ''';
    return await db.rawQuery(query, ['%"id":"$serviceId"%', limit]);
  }
}
