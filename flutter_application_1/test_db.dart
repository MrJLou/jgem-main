import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  // Initialize FFI for desktop platforms
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('Testing database initialization...');
  
  try {
    // Test getting the application documents directory
    print('Testing application documents directory...');
    final Directory appDir = await getApplicationDocumentsDirectory();
    print('App documents directory: ${appDir.path}');
    
    // Test creating a database in that directory
    final String dbPath = join(appDir.path, 'test_patient_management.db');
    print('Database path: $dbPath');
    
    // Ensure directory exists
    final Directory dbDir = Directory(dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
      print('Created directory: ${dbDir.path}');
    }
    
    // Test opening the database
    print('Attempting to open database...');
    final database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        print('Creating test table...');
        await db.execute('''
          CREATE TABLE test_table (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');
        
        await db.insert('test_table', {'name': 'Test Entry'});
        print('Test table created and data inserted');
      }
    );
    
    // Test querying the database
    final result = await database.query('test_table');
    print('Query result: $result');
    
    await database.close();
    print('Database test completed successfully!');
    
    // Clean up
    final testFile = File(dbPath);
    if (await testFile.exists()) {
      await testFile.delete();
      print('Test database file deleted');
    }
    
  } catch (e) {
    print('Database test failed: $e');
    exit(1);
  }
}
