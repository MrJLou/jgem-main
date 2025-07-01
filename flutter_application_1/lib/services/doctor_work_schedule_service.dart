import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/doctor_work_schedule.dart';
import 'database_helper.dart';
import 'api_service.dart';

/// Simple service for managing doctor work schedules (arrival/departure times)
class DoctorWorkScheduleService {
  static DatabaseHelper? _dbHelper;
  
  static DatabaseHelper get dbHelper {
    _dbHelper ??= DatabaseHelper();
    return _dbHelper!;
  }

  /// Get work schedule for a specific doctor
  static Future<DoctorSchedule?> getDoctorSchedule(String doctorId) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableDoctorSchedules,
        where: 'doctor_id = ? AND is_active = ?',
        whereArgs: [doctorId, 1],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return DoctorSchedule.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching doctor schedule for $doctorId: $e');
      }
      return null;
    }
  }

  /// Save or update doctor work schedule
  static Future<bool> saveDoctorSchedule(DoctorSchedule schedule) async {
    try {
      final db = await dbHelper.database;
      
      final scheduleWithTimestamp = schedule.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await db.insert(
        DatabaseHelper.tableDoctorSchedules,
        scheduleWithTimestamp.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      if (kDebugMode) {
        print('Saved doctor schedule: ${scheduleWithTimestamp.toString()}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving doctor schedule: $e');
      }
      return false;
    }
  }

  /// Get all doctor work schedules
  static Future<List<DoctorSchedule>> getAllDoctorSchedules() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableDoctorSchedules,
        where: 'is_active = ?',
        whereArgs: [1],
      );
      
      return maps.map((map) => DoctorSchedule.fromJson(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching all doctor schedules: $e');
      }
      return [];
    }
  }

  /// Get doctors currently working (within their arrival/departure times)
  static Future<List<DoctorSchedule>> getDoctorsCurrentlyWorking() async {
    try {
      final allSchedules = await getAllDoctorSchedules();
      return allSchedules.where((schedule) => schedule.isCurrentlyWorking()).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting currently working doctors: $e');
      }
      return [];
    }
  }

  /// Check if doctor is available at a specific time
  static Future<bool> isDoctorAvailableAt(String doctorId, TimeOfDay time) async {
    try {
      final schedule = await getDoctorSchedule(doctorId);
      return schedule?.isTimeWithinWorkHours(time) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking doctor availability: $e');
      }
      return false;
    }
  }

  /// Check if doctor is currently working
  static Future<bool> isDoctorCurrentlyWorking(String doctorId) async {
    try {
      final schedule = await getDoctorSchedule(doctorId);
      return schedule?.isCurrentlyWorking() ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if doctor is currently working: $e');
      }
      return false;
    }
  }

  /// Delete doctor work schedule
  static Future<bool> deleteDoctorSchedule(String doctorId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.update(
        DatabaseHelper.tableDoctorSchedules,
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'doctor_id = ?',
        whereArgs: [doctorId],
      );
      
      return result > 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting doctor schedule: $e');
      }
      return false;
    }
  }

  /// Create default schedule for a new doctor
  static Future<bool> createDefaultScheduleForDoctor(String doctorId, String doctorName) async {
    try {
      final defaultSchedule = DoctorSchedule.createDefault(
        doctorId: doctorId,
        doctorName: doctorName,
      );
      
      return await saveDoctorSchedule(defaultSchedule);
    } catch (e) {
      if (kDebugMode) {
        print('Error creating default schedule for doctor: $e');
      }
      return false;
    }
  }

  /// Initialize schedules for all existing doctors who don't have one
  static Future<void> initializeSchedulesForAllDoctors() async {
    try {
      final users = await ApiService.getUsers();
      final doctors = users.where((user) => user.role.toLowerCase() == 'doctor').toList();
      
      for (final doctor in doctors) {
        final existingSchedule = await getDoctorSchedule(doctor.id);
        if (existingSchedule == null) {
          await createDefaultScheduleForDoctor(doctor.id, doctor.fullName);
          if (kDebugMode) {
            print('Created default schedule for doctor: ${doctor.fullName}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing schedules for all doctors: $e');
      }
    }
  }
}
