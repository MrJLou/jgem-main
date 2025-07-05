import 'package:flutter_application_1/models/patient.dart';
import 'package:sqflite/sqflite.dart';
import '../models/clinic_service.dart';
import 'database_helper.dart';

class ClinicServiceDatabaseService {
  final DatabaseHelper dbHelper;

  ClinicServiceDatabaseService(this.dbHelper);

  Future<List<ClinicService>> getClinicServices() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(DatabaseHelper.tableClinicServices);
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) {
      return ClinicService.fromJson(maps[i]);
    });
  }

  Future<String> insertClinicService(Map<String, dynamic> service) async {
    final db = await dbHelper.database;
    // Ensure ID is present or generate one if not
    String id =
        service['id'] ?? 'service-${DateTime.now().millisecondsSinceEpoch}';
    Map<String, dynamic> serviceToInsert = {...service, 'id': id};

    await db.insert(
      DatabaseHelper.tableClinicServices,
      serviceToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<int> updateClinicService(ClinicService service) async {
    final db = await dbHelper.database;
    return await db.update(
      DatabaseHelper.tableClinicServices,
      service.toJson(),
      where: 'id = ?',
      whereArgs: [service.id],
    );
  }

  Future<int> deleteClinicService(String id) async {
    final db = await dbHelper.database;
    return await db.delete(
      DatabaseHelper.tableClinicServices,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ClinicService>> searchServicesByCategory(String category) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableClinicServices,
      where: 'category LIKE ?',
      whereArgs: ['%$category%'],
    );
    return List.generate(maps.length, (i) {
      return ClinicService.fromJson(maps[i]);
    });
  }

  Future<void> incrementServiceSelectionCounts(List<String> serviceIds) async {
    if (serviceIds.isEmpty) {
      return;
    }
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (String id in serviceIds) {
        await txn.rawUpdate(
          'UPDATE ${DatabaseHelper.tableClinicServices} SET selectionCount = selectionCount + 1 WHERE id = ?',
          [id],
        );
      }
    });
  }

  Future<int> getServiceSelectionCount(String serviceId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tableClinicServices,
      columns: ['selectionCount'],
      where: 'id = ?',
      whereArgs: [serviceId],
    );
    if (result.isNotEmpty) {
      return result.first['selectionCount'] as int? ?? 0;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getServiceUsageTrend(
      String serviceId) async {
    final db = await dbHelper.database;
    final sixMonthsAgo =
        DateTime.now().subtract(const Duration(days: 180));
    final result = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', recordDate) as month,
        COUNT(*) as count
      FROM ${DatabaseHelper.tableMedicalRecords}
      WHERE (serviceId = ? OR selectedServices LIKE ?) AND recordDate >= ?
      GROUP BY month
      ORDER BY month ASC
    ''', [serviceId, '%"id":"$serviceId"%', sixMonthsAgo.toIso8601String()]);
    return result;
  }

  Future<List<Patient>> getRecentPatientsForService(String serviceId,
      {int limit = 5}) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('''
      SELECT p.*
      FROM ${DatabaseHelper.tablePatients} p
      INNER JOIN ${DatabaseHelper.tableMedicalRecords} mr ON p.id = mr.patientId
      WHERE mr.serviceId = ? OR mr.selectedServices LIKE ?
      ORDER BY mr.recordDate DESC
      LIMIT ?
    ''', [serviceId, '%"id":"$serviceId"%', limit]);

    if (result.isEmpty) {
      return [];
    }
    return result.map((json) => Patient.fromJson(json)).toList();
  }
} 