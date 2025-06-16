import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
// You might need to import Patient model if it's used for return types or specific casting
// import '../models/patient.dart'; 

class PatientDatabaseService {
  final DatabaseHelper _dbHelper;

  PatientDatabaseService(this._dbHelper);

  // PATIENT MANAGEMENT METHODS

  Future<String> insertPatient(Map<String, dynamic> patient) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    patient['id'] = 'patient-${DateTime.now().millisecondsSinceEpoch}';
    patient['createdAt'] = now;
    patient['updatedAt'] = now;

    await db.insert(DatabaseHelper.tablePatients, patient);
    await _dbHelper.logChange(DatabaseHelper.tablePatients, patient['id'], 'insert');

    return patient['id'];
  }

  Future<int> updatePatient(Map<String, dynamic> patient) async {
    final db = await _dbHelper.database;
    patient['updatedAt'] = DateTime.now().toIso8601String();

    final result = await db.update(
      DatabaseHelper.tablePatients,
      patient,
      where: 'id = ?',
      whereArgs: [patient['id']],
    );

    await _dbHelper.logChange(DatabaseHelper.tablePatients, patient['id'], 'update');
    return result;
  }

  Future<int> deletePatient(String id) async {
    final db = await _dbHelper.database;
    final result = await db.delete(
      DatabaseHelper.tablePatients,
      where: 'id = ?',
      whereArgs: [id],
    );

    await _dbHelper.logChange(DatabaseHelper.tablePatients, id, 'delete');
    return result;
  }

  Future<Map<String, dynamic>?> getPatient(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePatients,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getPatients() async {
    final db = await _dbHelper.database;
    return await db.query(DatabaseHelper.tablePatients);
  }
  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final db = await _dbHelper.database;
    return await db.query(
      DatabaseHelper.tablePatients,
      where: 'fullName LIKE ? OR id LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
  }

  Future<Map<String, dynamic>?> findRegisteredPatient(
      {String? patientId, required String fullName}) async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> maps = [];

    if (patientId != null && patientId.isNotEmpty) {
      maps = await db.query(
        DatabaseHelper.tablePatients,
        where: 'id = ?',
        whereArgs: [patientId],
        limit: 1,
      );
    }

    if (maps.isEmpty && fullName.isNotEmpty) {
      maps = await db.query(
        DatabaseHelper.tablePatients,
        where: 'fullName = ?',
        whereArgs: [fullName],
        limit: 1,
      );
    }

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Related patient sync/utility methods from DatabaseHelper that operate on tablePatients

  Future<void> updatePatientFromSync(Map<String, dynamic> patientData) async {
    final db = await _dbHelper.database;
    try {
      await db.update(
        DatabaseHelper.tablePatients,
        patientData,
        where: 'id = ?',
        whereArgs: [patientData['id']],
      );
      await _dbHelper.logUserActivity(
        'SYNC_SYSTEM',
        'Patient information updated via real-time sync',
        targetRecordId: patientData['id']?.toString(),
        targetTable: DatabaseHelper.tablePatients,
        details: 'Real-time sync update from another device',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error updating patient info from sync: $e');
      } // Consider a more robust logging/error handling
      rethrow;
    }
  }

  Future<void> enableRealTimeSync(String patientId) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePatients,
      {
        'realTimeSyncEnabled': 1,
        'lastSyncTime': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }

  Future<bool> needsRealTimeSync(String patientId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tablePatients,
      where:
          'id = ? AND (realTimeSyncEnabled IS NULL OR realTimeSyncEnabled = 0)',
      whereArgs: [patientId],
      limit: 1,
    );
    return result.isNotEmpty;
  }
} 