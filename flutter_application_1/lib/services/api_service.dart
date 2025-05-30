import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../models/medical_record.dart';
import '../services/auth_service.dart';
import '../services/lan_sync_service.dart';

class ApiService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();
  static String? _currentUserRole;

  // Authentication Methods
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final auth = await _dbHelper.authenticateUser(username, password);      if (auth != null &&
          auth['user'] != null &&
          auth['user']['role'] != null) {
        _currentUserRole = auth['user']['role'];

        // Save to SharedPreferences
        await AuthService.saveLoginCredentials(
          token: auth['token'],
          username: username,
          accessLevel: auth['user']['role'],
        );

        return auth;
      } else {
        throw Exception('Invalid credentials or user data missing');
      }
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  static Future<void> register({
    required String fullName,
    required String username,
    required String password,
    required String role,
    required String securityQuestion1,
    required String securityAnswer1,
    required String securityQuestion2,
    required String securityAnswer2,
    required String securityQuestion3,
    required String securityAnswer3,
  }) async {
    try {
      // Hash the password before storing
      final hashedPassword = AuthService.hashPassword(password);

      await _dbHelper.insertUser({
        'username': username,
        'password': hashedPassword, // Store the hashed password
        'fullName': fullName,
        'role': role,
        'securityQuestion1': securityQuestion1,
        'securityAnswer1': securityAnswer1,
        'securityQuestion2': securityQuestion2,
        'securityAnswer2': securityAnswer2,
        'securityQuestion3': securityQuestion3,
        'securityAnswer3': securityAnswer3,
      });
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  static Future<bool> resetPassword(String username, String questionKey,
      String rawSecurityAnswer, String newPassword) async {
    try {
      // DatabaseHelper.resetPassword expects the RAW security answer for verification.
      return await _dbHelper.resetPassword(
        username,
        questionKey, // Pass the specific question key
        rawSecurityAnswer, // Pass the raw answer
        newPassword,
      );
    } catch (e) {
      print('ApiService: Failed to reset password: $e');
      throw Exception(
          'Failed to reset password: Check details or try again later.');
    }
  }

  static Future<User?> getUserSecurityDetails(String username) async {
    try {
      return await _dbHelper.getUserSecurityDetails(username);
    } catch (e) {
      print('ApiService: Failed to get user security details: $e');
      throw Exception('Failed to retrieve user security information.');
    }
  }
  static Future<void> logout() async {
    _currentUserRole = null;
    await AuthService.clearCredentials();
  }

  // Appointment Methods
  static Future<List<Appointment>> getAppointments(DateTime date) async {
    try {
      return await _dbHelper.getAppointmentsByDate(date);
    } catch (e) {
      throw Exception('Failed to load appointments: $e');
    }
  }

  static Future<Appointment> saveAppointment(Appointment appointment) async {
    try {
      return await _dbHelper.insertAppointment(appointment);
    } catch (e) {
      throw Exception('Failed to save appointment: $e');
    }
  }

  static Future<void> updateAppointmentStatus(
      String id, String newStatus) async {
    try {
      await _dbHelper.updateAppointmentStatus(id, newStatus);
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  static Future<bool> deleteAppointment(String id) async {
    try {
      final result = await _dbHelper.deleteAppointment(id);
      return result > 0;
    } catch (e) {
      throw Exception('Failed to delete appointment: $e');
    }
  }

  // Patient Methods
  static Future<List<Patient>> getPatients() async {
    try {
      final patientsData = await _dbHelper.getPatients();
      return patientsData.map((data) => Patient.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Failed to load patients: $e');
    }
  }

  static Future<Patient> getPatientById(String id) async {
    try {
      final patientData = await _dbHelper.getPatient(id);
      if (patientData != null) {
        return Patient.fromJson(patientData);
      } else {
        throw Exception('Patient not found');
      }
    } catch (e) {
      throw Exception('Failed to load patient: $e');
    }
  }

  static Future<List<Patient>> searchPatients(String query) async {
    try {
      final patientsData = await _dbHelper.searchPatients(query);
      return patientsData.map((data) => Patient.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Failed to search patients: $e');
    }
  }

  static Future<String> createPatient(Patient patient) async {
    try {
      return await _dbHelper.insertPatient(patient.toJson());
    } catch (e) {
      throw Exception('Failed to create patient: $e');
    }
  }

  static Future<int> updatePatient(Patient patient) async {
    try {
      return await _dbHelper.updatePatient(patient.toJson());
    } catch (e) {
      throw Exception('Failed to update patient: $e');
    }
  }

  static Future<int> deletePatient(String id) async {
    try {
      return await _dbHelper.deletePatient(id);
    } catch (e) {
      throw Exception('Failed to delete patient: $e');
    }
  }

  // Medical Record Methods
  static Future<List<MedicalRecord>> getPatientMedicalRecords(
      String patientId) async {
    try {
      final recordsData = await _dbHelper.getPatientMedicalRecords(patientId);
      return recordsData.map((data) => MedicalRecord.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Failed to load medical records: $e');
    }
  }

  static Future<String> createMedicalRecord(MedicalRecord record) async {
    try {
      return await _dbHelper.insertMedicalRecord(record.toJson());
    } catch (e) {
      throw Exception('Failed to create medical record: $e');
    }
  }

  static Future<int> updateMedicalRecord(MedicalRecord record) async {
    try {
      return await _dbHelper.updateMedicalRecord(record.toJson());
    } catch (e) {
      throw Exception('Failed to update medical record: $e');
    }
  }

  // LAN Synchronization Methods
  static Future<bool> synchronizeDatabase() async {
    try {
      return await _dbHelper.syncWithServer();
    } catch (e) {
      throw Exception('Failed to synchronize database: $e');
    }
  }

  static Future<String> exportDatabaseForSharing() async {
    try {
      return await _dbHelper.exportDatabase();
    } catch (e) {
      throw Exception('Failed to export database: $e');
    }
  }

  // DB Browser Live View Helper Methods - Cross-platform safe implementation
  static Future<void> setupLiveDbBrowserView() async {
    try {
      String dbPath;

      // Platform-specific handling for external storage
      if (!kIsWeb && Platform.isAndroid) {
        // Only try to use external storage on Android
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            dbPath = join(externalDir.path, 'patient_management.db');
          } else {
            // Fallback to app documents directory
            final appDir = await getApplicationDocumentsDirectory();
            dbPath = join(appDir.path, 'patient_management.db');
          }
        } catch (e) {
          // Fallback if external storage access fails
          final appDir = await getApplicationDocumentsDirectory();
          dbPath = join(appDir.path, 'patient_management.db');
        }
      } else {
        // For iOS, desktop, web or other platforms
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = join(appDir.path, 'patient_management.db');
      }

      // Export database to accessible location
      final exportedPath = await exportDatabaseForSharing();

      // Print instructions for connecting with DB Browser
      print('================================================');
      print('DB BROWSER CONNECTION INFORMATION:');
      print('Database Path: $dbPath');
      print('Exported Path: $exportedPath');
      print('To view live changes in DB Browser:');
      print('1. Open DB Browser for SQLite');
      print('2. Select "Open Database" and navigate to the path above');
      print('3. Set to "Read and Write" mode');
      print('4. Check "Keep updating the SQL view as the database changes"');
      print('================================================');
    } catch (e) {
      // Handle gracefully if setup fails
      print(
          'DB Browser setup info: Unable to access external storage. Using internal storage instead.');
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = join(appDir.path, 'patient_management.db');
      print('Database Path: $dbPath');
    }
  }

  // Network Sharing Methods - Cross-platform implementation
  static Future<Map<String, String>> getNetworkSharingInfo() async {
    try {
      // Get device network information - works on most platforms
      final interfaces = await NetworkInterface.list();
      final ipAddresses = <String>[];

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            ipAddresses.add(addr.address);
          }
        }
      }

      // Get database path safely
      String dbPath;
      try {
        dbPath = await exportDatabaseForSharing();
      } catch (e) {
        // Fallback to standard path
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = join(appDir.path, 'patient_management.db');
      }

      return {
        'ipAddresses': ipAddresses.join(', '),
        'databasePath': dbPath,
      };
    } catch (e) {
      throw Exception('Failed to get network sharing info: $e');
    }
  } // Initialize database for LAN access - Cross-platform safe implementation

  static Future<void> initializeDatabaseForLan() async {
    try {
      await _dbHelper.database; // Ensure database is initialized

      // Initialize LAN sync service
      try {
        await LanSyncService.initialize(_dbHelper);
        print('LAN sync service initialized successfully');
      } catch (e) {
        print('LAN sync service initialization failed: $e');
        // Continue execution even if this fails
      }

      // Try to set up DB Browser view, but don't fail if it doesn't work
      try {
        await setupLiveDbBrowserView();
      } catch (e) {
        print('DB Browser setup not available on this platform: $e');
        // Continue execution even if this fails
      }

      // Schedule periodic sync
      _startPeriodicSync();
    } catch (e) {
      throw Exception('Database initialization error: $e');
    }
  }

  // Start periodic synchronization
  static void _startPeriodicSync() {
    Future.delayed(const Duration(minutes: 5), () async {
      try {
        await synchronizeDatabase();
      } catch (e) {
        print('Periodic sync error: $e');
      } finally {
        _startPeriodicSync(); // Schedule next sync
      }
    });
  }

  // Check pending changes
  static Future<int> getPendingChangesCount() async {
    try {
      final changes = await _dbHelper.getPendingChanges();
      return changes.length;
    } catch (e) {
      throw Exception('Failed to get pending changes count: $e');
    }
  }

  // User access control
  static bool canPerformAction(String requiredRole) {
    // Check if current user has the required role
    if (_currentUserRole == null) return false;

    // Admin can do everything
    if (_currentUserRole == 'admin') return true;

    // Role-specific permissions
    switch (requiredRole) {
      case 'doctor':
        return _currentUserRole == 'doctor' || _currentUserRole == 'admin';
      case 'nurse':
        return _currentUserRole == 'nurse' ||
            _currentUserRole == 'doctor' ||
            _currentUserRole == 'admin';
      case 'receptionist':
        return _currentUserRole == 'receptionist' ||
            _currentUserRole == 'admin';
      default:
        return _currentUserRole == requiredRole;
    }
  }

  static Future<int> deleteUser(String id) async {
    try {
      // Check if user has admin privileges
      if (_currentUserRole != 'admin') {
        throw Exception('Only administrators can delete users');
      }

      final result = await _dbHelper.deleteUser(id);
      return result;
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
