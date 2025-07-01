import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/doctor_availability.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'api_service.dart';

/// Service for managing doctor availability schedules and the "Today Doctor" feature
class DoctorAvailabilityService {
  static DatabaseHelper? _dbHelper;
  
  static DatabaseHelper get dbHelper {
    _dbHelper ??= DatabaseHelper();
    return _dbHelper!;
  }

  /// Get all doctor availability records
  static Future<List<DoctorAvailability>> getAllDoctorAvailability() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'doctor_availability',
        where: 'isActive = ?',
        whereArgs: [1],
      );
      
      return maps.map((map) => DoctorAvailability.fromJson(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching doctor availability: $e');
      }
      return [];
    }
  }

  /// Get availability for a specific doctor
  static Future<DoctorAvailability?> getDoctorAvailability(String doctorId) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'doctor_availability',
        where: 'doctorId = ? AND isActive = ?',
        whereArgs: [doctorId, 1],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return DoctorAvailability.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching doctor availability for $doctorId: $e');
      }
      return null;
    }
  }

  /// Save or update doctor availability
  static Future<bool> saveDoctorAvailability(DoctorAvailability availability) async {
    try {
      final db = await dbHelper.database;
      final now = DateTime.now();
      
      final availabilityWithTimestamp = availability.copyWith(
        updatedAt: now,
      );
      
      await db.insert(
        'doctor_availability',
        availabilityWithTimestamp.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving doctor availability: $e');
      }
      return false;
    }
  }

  /// Get doctors available today
  static Future<List<TodayDoctorInfo>> getTodayAvailableDoctors() async {
    final today = DateTime.now();
    return getDoctorsAvailableOnDate(today);
  }

  /// Get doctors available on a specific date
  static Future<List<TodayDoctorInfo>> getDoctorsAvailableOnDate(DateTime date) async {
    try {
      final dayOfWeek = DayOfWeek.fromDateTime(date);
      final allAvailability = await getAllDoctorAvailability();
      final availableDoctors = <TodayDoctorInfo>[];
      
      for (final availability in allAvailability) {
        final daySchedule = availability.getScheduleForDay(dayOfWeek);
        if (daySchedule != null && daySchedule.isAvailable) {
          // Get doctor details
          final doctor = await ApiService.getUserById(availability.doctorId);
          if (doctor != null) {
            availableDoctors.add(TodayDoctorInfo(
              doctor: doctor,
              availability: availability,
              daySchedule: daySchedule,
              date: date,
            ));
          }
        }
      }
      
      // Sort by doctor name
      availableDoctors.sort((a, b) => a.doctor.fullName.compareTo(b.doctor.fullName));
      
      return availableDoctors;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting doctors available on date: $e');
      }
      return [];
    }
  }

  /// Initialize default availability for all existing doctors
  static Future<void> initializeDefaultAvailabilityForAllDoctors() async {
    try {
      final allUsers = await ApiService.getUsers();
      final doctors = allUsers.where((user) => user.role.toLowerCase() == 'doctor').toList();
      
      for (final doctor in doctors) {
        final existingAvailability = await getDoctorAvailability(doctor.id);
        if (existingAvailability == null) {
          final defaultAvailability = DoctorAvailability.createDefault(
            doctorId: doctor.id,
            doctorName: doctor.fullName,
          );
          await saveDoctorAvailability(defaultAvailability);
          
          if (kDebugMode) {
            print('Created default availability for doctor: ${doctor.fullName}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing default availability: $e');
      }
    }
  }

  /// Get today's doctor summary for the dashboard
  static Future<TodayDoctorSummary> getTodayDoctorSummary() async {
    final today = DateTime.now();
    return getDoctorSummaryForDate(today);
  }

  /// Get doctor summary for a specific date
  static Future<TodayDoctorSummary> getDoctorSummaryForDate(DateTime date) async {
    try {
      final dayOfWeek = DayOfWeek.fromDateTime(date);
      final allAvailability = await getAllDoctorAvailability();
      
      final availableDoctors = <TodayDoctorInfo>[];
      final unavailableDoctors = <TodayDoctorInfo>[];
      
      for (final availability in allAvailability) {
        final doctor = await ApiService.getUserById(availability.doctorId);
        if (doctor == null) continue;
        
        final daySchedule = availability.getScheduleForDay(dayOfWeek);
        final doctorInfo = TodayDoctorInfo(
          doctor: doctor,
          availability: availability,
          daySchedule: daySchedule,
          date: date,
        );
        
        if (daySchedule != null && daySchedule.isAvailable) {
          availableDoctors.add(doctorInfo);
        } else {
          unavailableDoctors.add(doctorInfo);
        }
      }
      
      return TodayDoctorSummary(
        date: date,
        dayOfWeek: dayOfWeek,
        availableDoctors: availableDoctors,
        unavailableDoctors: unavailableDoctors,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting doctor summary for date: $e');
      }
      return TodayDoctorSummary(
        date: date,
        dayOfWeek: DayOfWeek.fromDateTime(date),
        availableDoctors: [],
        unavailableDoctors: [],
      );
    }
  }

  /// Check if doctor is available at a specific date and time
  static Future<bool> isDoctorAvailableAt(String doctorId, DateTime dateTime) async {
    try {
      final availability = await getDoctorAvailability(doctorId);
      if (availability == null) return false;
      
      final dayOfWeek = DayOfWeek.fromDateTime(dateTime);
      final daySchedule = availability.getScheduleForDay(dayOfWeek);
      
      return daySchedule?.isAvailableAtTime(dateTime) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking doctor availability: $e');
      }
      return false;
    }
  }

  /// Get next available appointment slot for a doctor
  static Future<DateTime?> getNextAvailableSlot(String doctorId, {DateTime? fromDate}) async {
    try {
      final startDate = fromDate ?? DateTime.now();
      final availability = await getDoctorAvailability(doctorId);
      if (availability == null) return null;
      
      // Check the next 30 days
      for (int i = 0; i < 30; i++) {
        final checkDate = startDate.add(Duration(days: i));
        final dayOfWeek = DayOfWeek.fromDateTime(checkDate);
        final daySchedule = availability.getScheduleForDay(dayOfWeek);
        
        if (daySchedule != null && daySchedule.isAvailable) {
          // Find first available 30-minute slot
          final workingHours = daySchedule.getWorkingHours();
          if (workingHours != null) {
            var currentTime = DateTime(
              checkDate.year,
              checkDate.month,
              checkDate.day,
              workingHours.startHour,
              workingHours.startMinute,
            );
            
            final endTime = DateTime(
              checkDate.year,
              checkDate.month,
              checkDate.day,
              workingHours.endHour,
              workingHours.endMinute,
            );
            
            while (currentTime.isBefore(endTime)) {
              if (currentTime.isAfter(DateTime.now()) &&
                  daySchedule.isAvailableAtTime(currentTime)) {
                // TODO: Check against existing appointments
                return currentTime;
              }
              currentTime = currentTime.add(const Duration(minutes: 30));
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting next available slot: $e');
      }
      return null;
    }
  }

  /// Update doctor's schedule for a specific day
  static Future<bool> updateDoctorDaySchedule(
    String doctorId,
    DayOfWeek dayOfWeek,
    DaySchedule newSchedule,
  ) async {
    try {
      final availability = await getDoctorAvailability(doctorId);
      if (availability == null) return false;
      
      final updatedSchedule = Map<DayOfWeek, DaySchedule>.from(availability.weeklySchedule);
      updatedSchedule[dayOfWeek] = newSchedule;
      
      final updatedAvailability = availability.copyWith(
        weeklySchedule: updatedSchedule,
        updatedAt: DateTime.now(),
      );
      
      return await saveDoctorAvailability(updatedAvailability);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating doctor day schedule: $e');
      }
      return false;
    }
  }
}

/// Information about a doctor for a specific day
class TodayDoctorInfo {
  final User doctor;
  final DoctorAvailability availability;
  final DaySchedule? daySchedule;
  final DateTime date;

  TodayDoctorInfo({
    required this.doctor,
    required this.availability,
    required this.daySchedule,
    required this.date,
  });

  bool get isAvailable => daySchedule?.isAvailable ?? false;
  
  TimeSlot? get workingHours => daySchedule?.getWorkingHours();
  
  String get workingHoursDisplay {
    if (!isAvailable) return 'Not Available';
    
    final hours = workingHours;
    if (hours == null) return 'Schedule not set';
    
    return hours.formatTimeRange();
  }

  String get statusDisplay {
    if (!isAvailable) return 'Off Duty';
    if (daySchedule?.notes?.isNotEmpty == true) return daySchedule!.notes!;
    return 'Available';
  }
}

/// Summary of doctor availability for a specific date
class TodayDoctorSummary {
  final DateTime date;
  final DayOfWeek dayOfWeek;
  final List<TodayDoctorInfo> availableDoctors;
  final List<TodayDoctorInfo> unavailableDoctors;

  TodayDoctorSummary({
    required this.date,
    required this.dayOfWeek,
    required this.availableDoctors,
    required this.unavailableDoctors,
  });

  int get totalDoctors => availableDoctors.length + unavailableDoctors.length;
  
  int get availableCount => availableDoctors.length;
  
  int get unavailableCount => unavailableDoctors.length;
  
  bool get hasAvailableDoctors => availableDoctors.isNotEmpty;
  
  String get dayDisplayName => dayOfWeek.displayName;
  
  /// Get a summary string for display
  String getSummaryText() {
    if (totalDoctors == 0) return 'No doctors scheduled';
    
    final available = availableCount;
    final total = totalDoctors;
    
    if (available == 0) return 'No doctors available today';
    if (available == total) return 'All $total doctors available';
    
    return '$available of $total doctors available';
  }
}
