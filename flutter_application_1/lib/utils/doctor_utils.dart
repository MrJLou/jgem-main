import '../services/api_service.dart';

/// Utility class for doctor-related operations
class DoctorUtils {
  static Map<String, String> _doctorIdToNameCache = {};
  static bool _cacheInitialized = false;

  /// Initialize the doctor name cache
  static Future<void> initializeDoctorCache() async {
    if (_cacheInitialized) return;
    
    try {
      final users = await ApiService.getUsers();
      final doctors = users.where((user) => user.role.toLowerCase() == 'doctor');
      
      _doctorIdToNameCache.clear();
      for (final doctor in doctors) {
        _doctorIdToNameCache[doctor.id] = 'Dr. ${doctor.fullName}';
      }
      
      _cacheInitialized = true;
    } catch (e) {
      // Handle error silently and use fallback
      _cacheInitialized = false;
    }
  }

  /// Get doctor name by ID, with fallback to ID if not found
  static String getDoctorDisplayName(String doctorId) {
    if (!_cacheInitialized) {
      // Return a loading state or try to initialize
      initializeDoctorCache();
      return 'Dr. (Loading...)';
    }
    
    return _doctorIdToNameCache[doctorId] ?? 'Doctor ID: $doctorId';
  }

  /// Get doctor name by ID with async initialization
  static Future<String> getDoctorDisplayNameAsync(String doctorId) async {
    if (!_cacheInitialized) {
      await initializeDoctorCache();
    }
    
    return _doctorIdToNameCache[doctorId] ?? 'Doctor ID: $doctorId';
  }

  /// Refresh the doctor cache
  static Future<void> refreshCache() async {
    _cacheInitialized = false;
    await initializeDoctorCache();
  }

  /// Check if a doctor ID exists in the cache
  static bool isDoctorInCache(String doctorId) {
    return _doctorIdToNameCache.containsKey(doctorId);
  }
}
