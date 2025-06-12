import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/models/appointment.dart';
import 'package:flutter_application_1/services/database_helper.dart';

class AppointmentDatabaseService {
  final DatabaseHelper _dbHelper;

  AppointmentDatabaseService(this._dbHelper);

  // APPOINTMENT MANAGEMENT METHODS

  Future<Appointment> insertAppointment(Appointment appointment) async {
    final db = await _dbHelper.database;
    final appointmentMap = appointment.toMap();

    // Generate a unique ID if not provided
    if (appointmentMap['id'] == null || appointmentMap['id'].isEmpty) {
      appointmentMap['id'] = 'appointment-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}';
    }
    
    // Ensure createdAt is set
    if (appointmentMap['createdAt'] == null) {
      appointmentMap['createdAt'] = DateTime.now().toIso8601String();
    }

    try {
      // Check if ID already exists
      final existingAppointment = await db.query(
        DatabaseHelper.tableAppointments,
        where: 'id = ?',
        whereArgs: [appointmentMap['id']],
        limit: 1
      );

      if (existingAppointment.isNotEmpty) {
        // Generate a new unique ID
        appointmentMap['id'] = 'appointment-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}-${DateTime.now().second}';
      }

      await db.insert(DatabaseHelper.tableAppointments, appointmentMap);
      await _dbHelper.logChange(DatabaseHelper.tableAppointments, appointmentMap['id'], 'insert');
      return Appointment.fromMap(appointmentMap);
    } catch (e) {
      debugPrint('Error in insertAppointment: $e');
      throw Exception('Failed to insert appointment: $e');
    }
  }

  Future<int> updateAppointment(Appointment appointment) async {
    final db = await _dbHelper.database;
    final appointmentMap = appointment.toMap();

    final result = await db.update(
      DatabaseHelper.tableAppointments,
      appointmentMap,
      where: 'id = ?',
      whereArgs: [appointmentMap['id']],
    );

    await _dbHelper.logChange(DatabaseHelper.tableAppointments, appointmentMap['id'], 'update');
    return result;
  }

  Future<int> updateAppointmentStatus(String id, String status) async {
    final db = await _dbHelper.database;
    final result = await db.update(
      DatabaseHelper.tableAppointments,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _dbHelper.logChange(DatabaseHelper.tableAppointments, id, 'update');
    return result;
  }

  Future<int> deleteAppointment(String id) async {
    final db = await _dbHelper.database;
    final result = await db.delete(
      DatabaseHelper.tableAppointments,
      where: 'id = ?',
      whereArgs: [id],
    );

    await _dbHelper.logChange(DatabaseHelper.tableAppointments, id, 'delete');
    return result;
  }

  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableAppointments,
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );

    return List.generate(maps.length, (i) {
      return Appointment.fromMap(maps[i]);
    });
  }

  Future<List<Appointment>> getPatientAppointments(String patientId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableAppointments,
      where: 'patientId = ?',
      whereArgs: [patientId],
    );

    return List.generate(maps.length, (i) {
      return Appointment.fromMap(maps[i]);
    });
  }

  // ADDED: Get a single appointment by its ID
  Future<Appointment?> getAppointmentById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableAppointments,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Appointment.fromMap(maps.first);
    }
    return null;
  }

  // REAL-TIME SYNC METHODS FOR APPOINTMENT/QUEUE (Subset of original)
  Future<void> updatePatientQueueFromSync(Map<String, dynamic> queueData) async {
    final db = await _dbHelper.database;
    try {
      if (queueData.containsKey('appointmentId')) {
        await db.update(
          DatabaseHelper.tableAppointments,
          queueData,
          where: 'id = ?',
          whereArgs: [queueData['appointmentId']],
        );
        await _dbHelper.logUserActivity(
          'SYNC_SYSTEM',
          'Patient queue (appointment) updated via real-time sync',
          targetRecordId: queueData['appointmentId']?.toString(),
          targetTable: DatabaseHelper.tableAppointments,
          details: 'Real-time sync update from another device',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating patient queue from sync: $e');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCurrentPatientQueue() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return await db.rawQuery('''
      SELECT a.*, p.fullName as patientFullName, p.contactNumber as patientContactNumber 
      FROM ${DatabaseHelper.tableAppointments} a
      LEFT JOIN ${DatabaseHelper.tablePatients} p ON a.patientId = p.id
      WHERE DATE(a.date) = ? 
      AND a.status != 'Cancelled'
      ORDER BY a.time ASC
    ''', [todayStr]);
  }
} 