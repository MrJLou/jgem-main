import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/enhanced_real_time_sync_service.dart';
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

    // Send real-time sync notification for new patient
    try {
      EnhancedRealTimeSyncService.broadcastDatabaseChange('patients', 'insert', patient);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send real-time sync for new patient: $e');
      }
    }

    return patient['id'];
  }

  Future<int> updatePatient(Map<String, dynamic> patient, {String? userId, String? source}) async {
    final db = await _dbHelper.database;
    final patientId = patient['id'];

    // 1. Get current patient state before update
    final List<Map<String, dynamic>> currentStateResult = await db.query(
      DatabaseHelper.tablePatients,
      where: 'id = ?',
      whereArgs: [patientId],
    );

    if (currentStateResult.isEmpty) {
      // Patient does not exist, so we can't update.
      // Alternatively, you could insert it, but for an update, this is an error.
      throw Exception("Patient with ID $patientId not found for update.");
    }
    final Map<String, dynamic> oldPatient = currentStateResult.first;

    // 2. Compare fields and log changes to history table
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    patient.forEach((key, newValue) {
      if (key != 'id' && key != 'createdAt' && key != 'updatedAt') {
        final oldValue = oldPatient[key];
        if (oldValue != newValue) {
          batch.insert(DatabaseHelper.tablePatientHistory, {
            'patientId': patientId,
            'fieldName': key,
            'oldValue': oldValue?.toString(),
            'newValue': newValue?.toString(),
            'updatedAt': now,
            'updatedByUserId': userId,
            'sourceOfChange': source,
          });
        }
      }
    });

    await batch.commit(noResult: true);


    // 3. Update the patient record
    patient['updatedAt'] = now;

    final result = await db.update(
      DatabaseHelper.tablePatients,
      patient,
      where: 'id = ?',
      whereArgs: [patientId],
    );

    // 4. Log the update action itself
    await _dbHelper.logChange(DatabaseHelper.tablePatients, patientId, 'update');

    // Send real-time sync notification for patient update
    try {
      EnhancedRealTimeSyncService.broadcastDatabaseChange('patients', 'update', patient);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send real-time sync for patient update: $e');
      }
    }

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
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePatients,
      orderBy: 'createdAt DESC',
    );
    return maps;
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