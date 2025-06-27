import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../models/patient_bill.dart';
import '../models/medical_record.dart';
import '../models/active_patient_queue_item.dart';
import '../services/auth_service.dart';
import 'enhanced_shelf_lan_server.dart';
import '../models/clinic_service.dart';
import './queue_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/patient_report.dart';

class ApiService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();
  static final QueueService _queueService = QueueService();
  static String? _currentUserRole;
  static const String baseUrl = 'http://localhost:3000'; // Updated to a valid local API base URL

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
    required String email,
    required String contactNumber,
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
        'email': email,
        'contactNumber': contactNumber,
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
      debugPrint('ApiService: Failed to reset password: $e');
      throw Exception(
          'Failed to reset password: Check details or try again later.');
    }
  }

  static Future<User?> getUserSecurityDetails(String username) async {
    try {
      return await _dbHelper.getUserSecurityDetails(username);
    } catch (e) {
      debugPrint('ApiService: Failed to get user security details: $e');
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

  static Future<List<Appointment>> getPatientAppointments(String patientId) async {
    try {
      return await _dbHelper.getPatientAppointments(patientId);
    } catch (e) {
      throw Exception('Failed to load patient appointments: $e');
    }
  }

  static Future<List<Appointment>> getAllAppointments() async {
    try {
      return await _dbHelper.getAllAppointments();
    } catch (e) {
      throw Exception('Failed to load all appointments: $e');
    }
  }

  static Future<List<ActivePatientQueueItem>> getAllQueueItems() async {
    try {
      return await _dbHelper.getAllActiveQueueItems();
    } catch (e) {
      throw Exception('Failed to load all queue items: $e');
    }
  }

  static Future<Appointment> saveAppointment(Appointment appointment) async {
    return await _dbHelper.saveAppointment(appointment);
  }

  static Future<void> updateAppointmentStatus(
      String id, String newStatus) async {
    try {
      await _dbHelper.updateAppointmentStatus(id, newStatus);
      // If appointment is cancelled, remove its scheduled entry from the live queue
      if (newStatus.toLowerCase() == 'cancelled') {
        await _queueService.removeScheduledEntryForAppointment(id);
        debugPrint("ApiService: Appointment $id cancelled, removed from queue.");
      }
    } catch (e) {
      debugPrint("ApiService: Error in updateAppointmentStatus for $id: $e");
      throw Exception('Failed to update status: $e');
    }
  }

  static Future<bool> deleteAppointment(String id) async {
    try {
      await _dbHelper.deleteAppointment(id);
      // If appointment is deleted, also remove its scheduled entry from the live queue
      await _queueService.removeScheduledEntryForAppointment(id);
      debugPrint("ApiService: Appointment $id deleted, removed from queue.");
      return true;
    } catch (e) {
      debugPrint("ApiService: Error in deleteAppointment for $id: $e");
      throw Exception('Failed to delete appointment: $e');
    }
  }

  static Future<List<Appointment>> getAppointmentsForRange(DateTime startDate, DateTime endDate) async {
    try {
      return await _dbHelper.getAppointmentsForRange(startDate, endDate);
    } catch (e) {
      throw Exception('Failed to fetch appointments for range: $e');
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

  static Future<int> updatePatient(Patient patient, {String? source}) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      return await _dbHelper.updatePatient(patient.toJson(), userId: userId, source: source);
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

  static Future<List<MedicalRecord>> getMedicalRecordsByService(
      String serviceId) async {
    final recordsData = await _dbHelper.getMedicalRecordsByService(serviceId);
    return recordsData.map((data) => MedicalRecord.fromJson(data)).toList();
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

  static Future<List<MedicalRecord>> getAllMedicalRecords({int? limit}) async {
    final recordsData = await _dbHelper.getAllMedicalRecords(limit: limit);
    return recordsData.map((data) => MedicalRecord.fromJson(data)).toList();
  }

  static Future<Map<String, int>> getPatientDemographicsForService(
      String serviceId) async {
    return await _dbHelper.getPatientDemographicsForService(serviceId);
  }

  static Future<Map<String, dynamic>> getFinancialDataForService(
      String serviceId) async {
    return await _dbHelper.getFinancialDataForService(serviceId);
  }

  static Future<List<Map<String, dynamic>>> getRecentPatientRecordsForService(
      String serviceId,
      {int limit = 5}) async {
    return await _dbHelper.getRecentPatientRecordsForService(serviceId,
        limit: limit);
  }

  static Future<Map<String, dynamic>> getPatientTrends() async {
    final allAppointments = await _dbHelper.getAllAppointments();
    final allQueueItems = await _dbHelper.getAllActiveQueueItems();
    // Further processing from patient_trends_screen.dart would go here
    // For now, returning raw data
    return {
      'appointments': allAppointments,
      'queueItems': allQueueItems,
    };
  }

  static Future<Map<String, dynamic>> getDemographicsAnalysis() async {
    try {
      final patients = await getPatients();
      if (patients.isEmpty) {
        return {
          'totalPatients': 0,
          'genderDistribution': {'Male': 0, 'Female': 0, 'Other': 0},
          'ageDistribution': {
            '0-18': 0,
            '19-35': 0,
            '36-50': 0,
            '51-65': 0,
            '65+': 0,
          },
        };
      }

      final totalPatients = patients.length;
      final now = DateTime.now();

      final genderDistribution = {'Male': 0, 'Female': 0, 'Other': 0};
      final ageDistribution = {
        '0-18': 0,
        '19-35': 0,
        '36-50': 0,
        '51-65': 0,
        '65+': 0,
      };

      for (final patient in patients) {
        // Gender
        final gender = patient.gender.toLowerCase();
        if (gender == 'male') {
          genderDistribution['Male'] = genderDistribution['Male']! + 1;
        } else if (gender == 'female') {
          genderDistribution['Female'] = genderDistribution['Female']! + 1;
        } else {
          genderDistribution['Other'] = genderDistribution['Other']! + 1;
        }

        // Age
        final birthDate = patient.birthDate;
        int age = now.year - birthDate.year;
        if (now.month < birthDate.month ||
            (now.month == birthDate.month && now.day < birthDate.day)) {
          age--;
        }

        if (age <= 18) {
          ageDistribution['0-18'] = ageDistribution['0-18']! + 1;
        } else if (age <= 35) {
          ageDistribution['19-35'] = ageDistribution['19-35']! + 1;
        } else if (age <= 50) {
          ageDistribution['36-50'] = ageDistribution['36-50']! + 1;
        } else if (age <= 65) {
          ageDistribution['51-65'] = ageDistribution['51-65']! + 1;
        } else {
          ageDistribution['65+'] = ageDistribution['65+']! + 1;
        }
      }

      return {
        'totalPatients': totalPatients,
        'genderDistribution': genderDistribution,
        'ageDistribution': ageDistribution,
      };
    } catch (e) {
      debugPrint("Error fetching demographics analysis: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getTreatmentAnalysis() async {
    try {
      final services = await getClinicServices();
      services.sort((a, b) => b.selectionCount.compareTo(a.selectionCount));

      final Map<String, int> categoryDistribution = {};
      for (final service in services) {
        final category = service.category ?? 'Uncategorized';
        categoryDistribution[category] =
            (categoryDistribution[category] ?? 0) + service.selectionCount;
      }

      return {
        'topServices': services.take(5).toList(),
        'categoryDistribution': categoryDistribution,
        'totalSelections':
            services.fold<int>(0, (sum, item) => sum + item.selectionCount),
      };
    } catch (e) {
      debugPrint("Error fetching treatment analysis: $e");
      rethrow;
    }
  }

  static Future<List<PatientReport>> getRecentClinicVisits(
      {int limit = 10}) async {
    final records = await getAllMedicalRecords(limit: limit);
    final List<PatientReport> reports = [];
    for (final record in records) {
      try {
        final patient = await getPatientById(record.patientId);
        reports.add(PatientReport(record: record, patient: patient));
      } catch (e) {
        // Handle error, e.g., patient not found
        debugPrint('Could not fetch patient for recent visit report: $e');
      }
    }
    return reports;
  }

  static Future<int> getTotalPatientsForService(String serviceId) async {
    return await _dbHelper.getTotalPatientsForService(serviceId);
  }

  // Active Patient Queue Methods
  static Future<ActivePatientQueueItem?> getActiveQueueItem(
      String queueEntryId) async {
    try {
      // _dbHelper.getActiveQueueItem already returns ActivePatientQueueItem? or throws an error
      return await _dbHelper.getActiveQueueItem(queueEntryId);
    } catch (e) {
      debugPrint('ApiService: Failed to get active queue item: $e');
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
      debugPrint('ApiService: Failed to update active patient status: $e');
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
      debugPrint('ApiService: Failed to search patients in active queue: $e');
      throw Exception('Failed to search patients in active queue: $e');
    }
  }

  static Future<ActivePatientQueueItem> addToActiveQueue(ActivePatientQueueItem item) async {
    try {
      return await _dbHelper.addToActiveQueue(item);
    } catch (e) {
      debugPrint('ApiService: Failed to add to active queue: $e');
      throw Exception('Failed to add patient to active queue: $e');
    }
  }

  // Clinic Service Methods
  static Future<List<ClinicService>> getClinicServices() async {
    try {
      return await _dbHelper.getClinicServices();
    } catch (e) {
      debugPrint('ApiService: Failed to get all clinic services: $e');
      throw Exception('Failed to load all clinic services: $e');
    }
  }

  static Future<String> createClinicService(ClinicService service) async {
    try {
      return await _dbHelper.insertClinicService(service.toJson());
    } catch (e) {
      debugPrint('ApiService: Failed to create clinic service: $e');
      throw Exception('Failed to create clinic service: $e');
    }
  }

  static Future<int> updateClinicService(ClinicService service) async {
    try {
      return await _dbHelper.updateClinicService(service.toJson());
    } catch (e) {
      throw Exception('Failed to update clinic service: $e');
    }
  }
  
  static Future<int> deleteClinicService(String id) async {
    try {
      return await _dbHelper.deleteClinicService(id);
    } catch (e) {
      throw Exception('Failed to delete clinic service: $e');
    }
  }
  
  static Future<List<ClinicService>> searchServicesByCategory(String category) async {
    try {
      final servicesData = await _dbHelper.searchServicesByCategory(category);
      return servicesData.map((data) => ClinicService.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Failed to search services by category: $e');
    }
  }

  static Future<void> incrementServiceUsage(List<String> serviceIds) async {
    if (serviceIds.isEmpty) return;
    try {
      await _dbHelper.incrementServiceSelectionCounts(serviceIds);
    } catch (e) {
      debugPrint('ApiService: Failed to increment service usage counts: $e');
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
      debugPrint('================================================');
      debugPrint('DB BROWSER CONNECTION INFORMATION:');
      debugPrint('Database Path: $dbPath');
      debugPrint('Exported Path: $exportedPath');
      debugPrint('To view live changes in DB Browser:');
      debugPrint('1. Open DB Browser for SQLite');
      debugPrint('2. Select "Open Database" and navigate to the path above');
      debugPrint('3. Set to "Read and Write" mode');
      debugPrint('4. Check "Keep updating the SQL view as the database changes"');
      debugPrint('================================================');
    } catch (e) {
      // Handle gracefully if setup fails
      debugPrint(
          'DB Browser setup info: Unable to access external storage. Using internal storage instead.');
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = join(appDir.path, 'patient_management.db');
      debugPrint('Database Path: $dbPath');
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
      await _dbHelper.database; // Ensure database is initialized      // Initialize Enhanced Shelf LAN server for database access
      try {
        await EnhancedShelfServer.initialize(_dbHelper);
        debugPrint('Enhanced Shelf LAN server initialized successfully');
      } catch (e) {
        debugPrint('Enhanced Shelf LAN server initialization failed: $e');
        // Continue execution even if this fails
      }

      // Try to set up DB Browser view, but don't fail if it doesn't work
      try {
        await setupLiveDbBrowserView();
      } catch (e) {
        debugPrint('DB Browser setup not available on this platform: $e');
        // Continue execution even if this fails
      }

      // Schedule periodic sync
      _startPeriodicSync();
    } catch (e) {
      // More detailed error information for debugging
      final errorDetails = e.toString();
      debugPrint('Database initialization failed with error: $errorDetails');
      
      // Provide more specific error messages based on the type of failure
      if (errorDetails.contains('network') || errorDetails.contains('NetworkInfo') || errorDetails.contains('wifi')) {
        throw Exception('Database initialization error: Network interface access failed during LAN setup. This may be due to network permissions or unavailable network interface. LAN features will be limited. Original error: $e');
      } else if (errorDetails.contains('path') || errorDetails.contains('directory') || errorDetails.contains('FileSystemException')) {
        throw Exception('Database initialization error: File system access failed during database setup. Check directory permissions and available storage space. Original error: $e');
      } else if (errorDetails.contains('SharedPreferences')) {
        throw Exception('Database initialization error: Failed to access app settings storage. This may be due to storage permissions. Original error: $e');
      } else if (errorDetails.contains('getApplicationDocumentsDirectory')) {
        throw Exception('Database initialization error: Cannot access documents directory. Check app permissions and available storage. Original error: $e');
      } else {
        throw Exception('Database initialization error: $e');
      }
    }
  }

  // Start periodic synchronization
  static void _startPeriodicSync() {
    Future.delayed(const Duration(minutes: 5), () async {
      try {
        await synchronizeDatabase();
      } catch (e) {
        debugPrint('Periodic sync error: $e');
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

  static Future<List<User>> getUsers() async {
    try {
      return await _dbHelper.getUsers();
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  static Future<User?> getUserById(String id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableUsers,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return User.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: Failed to get user by ID: $e');
      return null;
    }
  }

  static Future<Map<String, int>> getDashboardStatistics() async {
    try {
      return await _dbHelper.getDashboardStatistics();
    } catch (e) {
      debugPrint('ApiService: Failed to get dashboard statistics: $e');
      throw Exception('Failed to get dashboard statistics: $e');
    }
  }

  /// Resets the entire database, except for the admin user.
  static Future<void> resetDatabase() async {
    try {
      await _dbHelper.resetDatabase();
    } catch (e) {
      throw Exception('Failed to reset database: $e');
    }
  }

  // Method to create a new appointment
  static Future<String> createAppointment(Appointment appointment) async {
    try {
      // Generate a unique ID for the appointment
      final newId = 'appointment-${DateTime.now().millisecondsSinceEpoch}';
      final appointmentWithId = appointment.copyWith(id: newId);
      
      // This calls DatabaseHelper.insertAppointment, which returns an Appointment
      final savedAppointment = await _dbHelper.insertAppointment(appointmentWithId); 
      return savedAppointment.id;
    } catch (e) {
      debugPrint('Error in ApiService.createAppointment: $e');
      throw Exception('Failed to create appointment: $e');
    }
  }

  static Future<Map<String, dynamic>?> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          // Add any additional headers here (e.g., authorization)
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('API Error: $e');
      }
      return null;
    }
  }

  // Service Metrics
  static Future<int> getServiceTimesAvailed(String serviceId) async {
    try {
      return await _dbHelper.getServiceSelectionCount(serviceId);
    } catch (e) {
      debugPrint('ApiService: Failed to get service times availed: $e');
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> getServiceUsageTrend(String serviceId) async {
    try {
      return await _dbHelper.getServiceUsageTrend(serviceId);
    } catch (e) {
      debugPrint('ApiService: Failed to get service usage trend: $e');
      return [];
    }
  }

  static Future<List<Patient>> getRecentPatientsForService(String serviceId, {int limit = 5}) async {
    try {
      return await _dbHelper.getRecentPatientsForService(serviceId, limit: limit);
    } catch (e) {
      debugPrint('ApiService: Failed to get recent patients for service: $e');
      return [];
    }
  }

  // Medical Record Methods
  static Future<List<Map<String, dynamic>>> getPatientHistory(String patientId) async {
    try {
      return await _dbHelper.getPatientHistory(patientId);
    } catch (e) {
      throw Exception('Failed to load patient history: $e');
    }
  }

  // Payment Transaction Methods
  static Future<List<Map<String, dynamic>>> getPaymentTransactions() async {
    try {
      return await _dbHelper.getPaymentTransactions();
    } catch (e) {
      throw Exception('Failed to load payment transactions: $e');
    }
  }

  // Patient Bills Methods
  static Future<List<PatientBill>> getPatientBills(String patientId) async {
    try {
      // Get all bills and filter by patientId
      final allBillsData = await _dbHelper.getPatientBills();
      final patientBillsData = allBillsData.where((bill) => 
        bill['patientId'] == patientId).toList();
      
      final bills = <PatientBill>[];
      
      for (final billData in patientBillsData) {
        // Fetch patient data for the bill
        Patient? patient;
        try {
          final patientData = await _dbHelper.getPatient(patientId);
          if (patientData != null) {
            patient = Patient.fromJson(patientData);
          }
        } catch (e) {
          // Continue without patient data if fetch fails
        }
        
        // Get bill items for this bill
        final billItems = await _dbHelper.getBillItems(billData['id']);
        
        // Create a complete bill data map
        final completeBillData = Map<String, dynamic>.from(billData);
        completeBillData['billItems'] = billItems;
        
        bills.add(PatientBill.fromMap(completeBillData, patient));
      }
      
      return bills;
    } catch (e) {
      throw Exception('Failed to load patient bills: $e');
    }
  }

  static Future<List<PatientBill>> getAllPatientBills() async {
    try {
      final billsData = await _dbHelper.getPatientBills();
      final bills = <PatientBill>[];
      
      for (final billData in billsData) {
        // Fetch patient data for the bill
        Patient? patient;
        if (billData['patientId'] != null) {
          try {
            final patientData = await _dbHelper.getPatient(billData['patientId']);
            if (patientData != null) {
              patient = Patient.fromJson(patientData);
            }
          } catch (e) {
            // Continue without patient data if fetch fails
          }
        }
        
        // Get bill items for this bill
        final billItems = await _dbHelper.getBillItems(billData['id']);
        
        // Create a complete bill data map
        final completeBillData = Map<String, dynamic>.from(billData);
        completeBillData['billItems'] = billItems;
        
        bills.add(PatientBill.fromMap(completeBillData, patient));
      }
      
      return bills;
    } catch (e) {
      throw Exception('Failed to load all patient bills: $e');
    }
  }

  static Future<List<PatientReport>> getPatientReportsForService(String serviceId, {int limit = 10}) async {
    try {
      // Get all medical records and filter by service
      final allRecords = await getAllMedicalRecords(limit: limit * 2); // Get more records to filter
      final List<PatientReport> reports = [];
      
      for (final record in allRecords) {
        // Check if this record includes the specific service
        if (record.selectedServices != null) {
          bool includesService = record.selectedServices!.any((service) => 
            service['id']?.toString() == serviceId.toString());
          
          if (includesService) {
            try {
              final patient = await getPatientById(record.patientId);
              reports.add(PatientReport(record: record, patient: patient));
              
              // Stop when we have enough reports
              if (reports.length >= limit) break;
            } catch (e) {
              debugPrint('Could not fetch patient ${record.patientId} for service report: $e');
            }
          }
        }
      }
      
      return reports;
    } catch (e) {
      debugPrint('ApiService: Failed to get patient reports for service: $e');
      return [];
    }
  }
}
