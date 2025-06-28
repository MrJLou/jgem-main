import 'dart:async';

import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/database_helper.dart';

class UserDatabaseService {
  final DatabaseHelper _dbHelper;

  UserDatabaseService(this._dbHelper);

  // USER MANAGEMENT METHODS

  // Insert user
  Future<User> insertUser(Map<String, dynamic> userMap) async {
    final db = await _dbHelper.database;
    // Ensure correct keys and handle potential nulls for NOT NULL fields
    Map<String, dynamic> dbUserMap = {
      'id': userMap['id'] ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
      'username': userMap['username'],
      'password': userMap[
          'password'], // Assuming password hashing is done before this call
      'fullName': userMap[
          'fullName'], 
      'role': userMap['role'],
      'securityQuestion1':
          userMap['securityQuestion1'] ?? '', 
      'securityAnswer1':
          userMap['securityAnswer1'] ?? '', 
      'securityQuestion2':
          userMap['securityQuestion2'] ?? '', 
      'securityAnswer2':
          userMap['securityAnswer2'] ?? '', 
      'securityQuestion3':
          userMap['securityQuestion3'] ?? '', 
      'securityAnswer3':
          userMap['securityAnswer3'] ?? '', 
      'createdAt': userMap['createdAt'] ?? DateTime.now().toIso8601String(),
    };

    // Validate that essential NOT NULL fields are present after defaults
    if (dbUserMap['username'] == null || dbUserMap['username'].isEmpty) {
      throw Exception("Username cannot be null or empty.");
    }
    if (dbUserMap['password'] == null || dbUserMap['password'].isEmpty) {
      throw Exception("Password cannot be null or empty.");
    }
    if (dbUserMap['fullName'] == null || dbUserMap['fullName'].isEmpty) {
      throw Exception("Full name cannot be null or empty.");
    }
    if (dbUserMap['role'] == null || dbUserMap['role'].isEmpty) {
      throw Exception("Role cannot be null or empty.");
    }

    await db.transaction((txn) async {
      await txn.insert(DatabaseHelper.tableUsers, dbUserMap);
      await _dbHelper.logChange(DatabaseHelper.tableUsers, dbUserMap['id'] as String, 'insert',
          executor: txn);
    });

    return User.fromJson(dbUserMap);
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableUsers,
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  // Get user by ID
  Future<User?> getUserById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableUsers,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  // Update user
  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await _dbHelper.database;
    late int result;
    await db.transaction((txn) async {
      result = await txn.update(
        DatabaseHelper.tableUsers,
        user,
        where: 'id = ?',
        whereArgs: [user['id']],
      );
      if (result > 0) {
        await _dbHelper.logChange(DatabaseHelper.tableUsers, user['id'] as String, 'update',
            executor: txn);
      }
    });
    return result;
  }

  // Delete user
  Future<int> deleteUser(String id) async {
    final db = await _dbHelper.database;
    late int result;
    await db.transaction((txn) async {
      result = await txn.delete(
        DatabaseHelper.tableUsers,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result > 0) {
        await _dbHelper.logChange(DatabaseHelper.tableUsers, id, 'delete', executor: txn);
      }
    });
    return result;
  }

  // Get all users
  Future<List<User>> getUsers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(DatabaseHelper.tableUsers);

    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  // Get user security details (questions and answers, no password)
  Future<User?> getUserSecurityDetails(String username) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableUsers,
      columns: [
        'id',
        'username',
        'fullName',
        'role',
        'securityQuestion1',
        'securityAnswer1',
        'securityQuestion2',
        'securityAnswer2',
        'securityQuestion3',
        'securityAnswer3',
        'createdAt'
      ], 
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  // Authentication
  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> result = await db.query(
      DatabaseHelper.tableUsers,
      where: 'username = ?',
      whereArgs: [username],
    );

    if (result.isEmpty) {
      return null; // User not found
    }

    final userMap = result.first;
    final String hashedPassword = userMap['password'];

    final bool isPasswordValid =
        AuthService.verifyPassword(password, hashedPassword);

    if (isPasswordValid) {
      return {
        'token': 'local-${DateTime.now().millisecondsSinceEpoch}', 
        'user': User.fromJson(userMap), 
      };
    }

    return null; // Password didn't match
  }

  // Update the resetPassword method
  Future<bool> resetPassword(String username, String securityQuestionKey,
      String securityAnswer, String newPassword) async {
    final db = await _dbHelper.database;

    // First, get the user by username only
    final List<Map<String, dynamic>> users = await db.query(
      DatabaseHelper.tableUsers,
      where: 'username = ?', 
      whereArgs: [username],
    );

    if (users.isEmpty) {
      return false; 
    }

    final user = User.fromJson(users.first);
    
    bool isAnswerCorrect = false;
    String? hashedAnswerToVerify;
    String? questionToCheck;

    // Determine which security question and answer to verify based on the key
    switch (securityQuestionKey) {
      case 'securityQuestion1':
        questionToCheck = user.securityQuestion1;
        hashedAnswerToVerify = user.securityAnswer1;
        break;
      case 'securityQuestion2':
        questionToCheck = user.securityQuestion2;
        hashedAnswerToVerify = user.securityAnswer2;
        break;
      case 'securityQuestion3':
        questionToCheck = user.securityQuestion3;
        hashedAnswerToVerify = user.securityAnswer3;
        break;
      default:
        return false; // Invalid security question key
    }

    // Verify that the question exists and the answer is correct
    if (questionToCheck != null && 
        questionToCheck.isNotEmpty && 
        hashedAnswerToVerify != null && 
        hashedAnswerToVerify.isNotEmpty) {
      isAnswerCorrect = AuthService.verifySecurityAnswer(securityAnswer, hashedAnswerToVerify);
    }

    if (!isAnswerCorrect) {
      return false; 
    }

    final String hashedPassword = AuthService.hashPassword(newPassword);

    final int updatedRows = await db.update(
      DatabaseHelper.tableUsers,
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [user.id], // user.id is non-nullable String
    );

    if (updatedRows > 0) {
      await _dbHelper.logChange(DatabaseHelper.tableUsers, user.id, 'update'); // user.id is non-nullable String
      return true;
    }
    
    return false; 
  }
} 