import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../models/medical_record.dart';
import '../models/active_patient_queue_item.dart';
import '../services/auth_service.dart';
import '../services/lan_sync_service.dart';
import '../models/clinic_service.dart';

class ApiService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();
  static String? _currentUserRole;

  // Authentication Methods
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final auth = await _dbHelper.authenticateUser(username, password);
      if (auth != null &&
          auth['user'] != null &&
          auth['user'].role != null) {
        _currentUserRole = auth['user'].role;

        // Save to SharedPreferences
        await AuthService.saveLoginCredentials(
          token: auth['token'],
          username: username,
          accessLevel: auth['user'].role,
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

  // Active Patient Queue Methods
  static Future<ActivePatientQueueItem?> getActiveQueueItem(
      String queueEntryId) async {
    try {
      // _dbHelper.getActiveQueueItem already returns ActivePatientQueueItem? or throws an error
      return await _dbHelper.getActiveQueueItem(queueEntryId);
    } catch (e) {
      print('ApiService: Failed to get active queue item: $e');
      // Rethrow or handle as specific exception type if necessary
      throw Exception('Failed to load active queue item: $e');
    }
  }

  static Future<void> updateActivePatientStatus(
      String queueEntryId, String newStatus) async {
    try {
      final originalItem = await _dbHelper.getActiveQueueItem(queueEntryId);

      if (originalItem == null) {
        throw Exception(
            'Active queue item not found with ID: $queueEntryId to update status.');
      }

      // No need for fromJson here, originalItem is already the correct type
      ActivePatientQueueItem updatedItem;
      final now = DateTime.now();
      switch (newStatus.toLowerCase()) {
        case 'waiting':
          updatedItem = originalItem.copyWith(
              status: 'waiting',
              consultationStartedAt: null,
              servedAt: null,
              removedAt: null);
          break;
        case 'in_consultation':
          if (originalItem.status == 'served' ||
              originalItem.status == 'removed') {
            throw Exception(
                'Cannot change status to in_consultation for a patient already served or removed.');
          }
          updatedItem = originalItem.copyWith(
              status: 'in_consultation',
              consultationStartedAt: originalItem.consultationStartedAt ?? now,
              servedAt: null);
          break;
        case 'served':
          if (originalItem.status == 'removed') {
            throw Exception(
                'Cannot change status to served for a patient already removed.');
          }
          updatedItem = originalItem.copyWith(
              status: 'served',
              servedAt: now,
              consultationStartedAt: originalItem.consultationStartedAt ?? now);
          break;
        case 'removed':
          updatedItem =
              originalItem.copyWith(status: 'removed', removedAt: now);
          break;
        default:
          updatedItem = originalItem.copyWith(status: newStatus);
      }

      await _dbHelper.updateActiveQueueItem(updatedItem);
    } catch (e) {
      print('ApiService: Failed to update active patient status: $e');
      // Rethrow or handle as specific exception type if necessary
      throw Exception('Failed to update active patient status: $e');
    }
  }

  static Future<List<ActivePatientQueueItem>> searchPatientsInActiveQueue(
      String searchTerm) async {
    try {
      final List<Map<String, dynamic>> resultsData =
          await _dbHelper.searchActiveQueuePatients(searchTerm);
      return resultsData
          .map((data) => ActivePatientQueueItem.fromJson(data))
          .toList();
    } catch (e) {
      print('ApiService: Failed to search patients in active queue: $e');
      throw Exception('Failed to search patients in active queue: $e');
    }
  }

  // Clinic Service Methods - New Section
  static Future<List<ClinicService>> searchServicesByCategory(
      String category) async {
    try {
      final servicesData = await _dbHelper.searchServicesByCategory(category);
      return servicesData.map((data) => ClinicService.fromJson(data)).toList();
    } catch (e) {
      print('ApiService: Failed to search services by category: $e');
      throw Exception('Failed to search services by category: $e');
    }
  }

  static Future<List<ClinicService>> searchServicesByName(
      String serviceName) async {
    try {
      final servicesData = await _dbHelper.searchServicesByName(serviceName);
      return servicesData.map((data) => ClinicService.fromJson(data)).toList();
    } catch (e) {
      print('ApiService: Failed to search services by name: $e');
      throw Exception('Failed to search services by name: $e');
    }
  }

  static Future<ClinicService?> getClinicServiceById(String id) async {
    try {
      final serviceData = await _dbHelper.getClinicServiceById(id);
      if (serviceData != null) {
        return ClinicService.fromJson(serviceData);
      }
      return null;
    } catch (e) {
      print('ApiService: Failed to get service by ID: $e');
      throw Exception('Failed to get service by ID: $e');
    }
  }

  static Future<ClinicService?> getClinicServiceByName(String name) async {
    try {
      final serviceData = await _dbHelper.getClinicServiceByName(name);
      if (serviceData != null) {
        return ClinicService.fromJson(serviceData);
      }
      return null;
    } catch (e) {
      print('ApiService: Failed to get service by name: $e');
      throw Exception('Failed to get service by name: $e');
    }
  }

  static Future<ClinicService> saveClinicService(ClinicService service) async {
    try {
      // Check if the service already exists by ID (for updates)
      // A more robust way for new services might be to not assign an ID client-side initially,
      // or use a temporary ID format that the backend/DB replaces.
      // For now, if ID looks like a placeholder, we might assume it's new.
      // Or, try to fetch by ID. If it exists, update. Else, insert.

      final existingServiceById =
          await _dbHelper.getClinicServiceById(service.id);

      if (existingServiceById != null) {
        // Update existing service
        await _dbHelper.updateClinicService(service.toJson());
        return service; // Return the updated service
      } else {
        // Insert new service
        // If service.id was a placeholder, _dbHelper.insertClinicService will generate one if not provided in toJson()
        // Or, ensure service.id is a new unique ID before this point.
        // The current _dbHelper.insertClinicService creates an ID if not present.
        String newId = await _dbHelper.insertClinicService(service.toJson());
        return service.copyWith(
            id: newId); // Return service with the new ID from DB
      }
    } catch (e) {
      print('ApiService: Failed to save clinic service: $e');
      throw Exception('Failed to save clinic service: $e');
    }
  }

  static Future<int> deleteClinicService(String id) async {
    try {
      return await _dbHelper.deleteClinicService(id);
    } catch (e) {
      print('ApiService: Failed to delete clinic service: $e');
      throw Exception('Failed to delete clinic service: $e');
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

  static Future<List<Map<String, dynamic>>> searchPayments({
    required String reference,
    DateTime? startDate,
    DateTime? endDate,
    String? paymentType,
  }) async {
    try {
      return await _dbHelper.searchPayments(
        reference: reference,
        startDate: startDate,
        endDate: endDate,
        paymentType: paymentType,
      );
    } catch (e) {
      throw Exception('Failed to search payments: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> searchServices({
    required String searchTerm,
    required String category,
  }) async {
    try {
      return await _dbHelper.searchServices(
        searchTerm: searchTerm,
        category: category == 'All Categories' ? null : category,
      );
    } catch (e) {
      throw Exception('Failed to search services: $e');
    }
  }
}
