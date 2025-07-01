import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class BackupService {
  static DatabaseHelper? _dbHelper;

  /// Initialize the backup service with database helper
  static void initialize(DatabaseHelper dbHelper) {
    _dbHelper = dbHelper;
  }

  /// Get backup directory relative to project root (jgem-main/Backups) with monthly organization
  static Future<Directory> getBackupDirectory([String? customPath]) async {
    Directory baseDir;

    if (customPath != null && customPath.isNotEmpty) {
      baseDir = Directory(customPath);
    } else {
      // Find the project root directory (jgem-main folder)
      final projectRoot = await _findProjectRoot();
      baseDir = Directory(path.join(projectRoot, 'Backups'));
      
      debugPrint('BackupService: Using project-relative backup path: ${baseDir.path}');
    }

    // Create monthly subfolder for organization
    final now = DateTime.now();
    final monthlyFolder = DateFormat('yyyy-MM').format(now);
    final monthlyDir = Directory(path.join(baseDir.path, monthlyFolder));

    // Create directories if they don't exist
    if (!await monthlyDir.exists()) {
      await monthlyDir.create(recursive: true);
      debugPrint('BackupService: Created monthly backup directory: ${monthlyDir.path}');
    }

    return monthlyDir;
  }

  /// Create a backup of the database
  static Future<BackupResult> createBackup({String? customBackupPath, String? backupName}) async {
    try {
      if (_dbHelper == null) {
        throw Exception('Backup service not initialized. Call BackupService.initialize() first.');
      }

      // Get current database path
      final dbPath = await _dbHelper!.currentDatabasePath;
      if (dbPath == null) {
        throw Exception('Database path not found');
      }

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('Database file not found at path: $dbPath');
      }

      // Get backup directory
      final backupDir = await getBackupDirectory(customBackupPath);
      
      // Generate backup filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      String finalBackupName;
      
      if (backupName?.isNotEmpty == true) {
        // Remove .db extension from custom name if it exists, then add timestamp and .db
        String cleanName = backupName!;
        if (cleanName.toLowerCase().endsWith('.db')) {
          cleanName = cleanName.substring(0, cleanName.length - 3);
        }
        finalBackupName = '${cleanName}_$timestamp.db';
      } else {
        finalBackupName = 'backup_$timestamp.db';
      }
      
      final backupFile = File(path.join(backupDir.path, finalBackupName));

      // Copy database file to backup location
      await dbFile.copy(backupFile.path);

      // Remove user sessions from the backup to prevent authentication conflicts
      await _cleanUserSessionsFromBackup(backupFile.path);

      // Verify backup integrity after cleaning
      if (!await backupFile.exists()) {
        throw Exception('Backup file was not created successfully');
      }

      final backupSize = await backupFile.length();
      debugPrint('BackupService: Backup size after session cleanup: $backupSize bytes');

      // Get updated metadata after cleanup
      final cleanedTableCount = await _getTableCountFromFile(backupFile.path);
      final cleanedRecordCount = await _getTotalRecordCountFromFile(backupFile.path);
      
      // Verify backup can be opened and contains expected data (without sessions)
      await _validateBackupIntegrity(backupFile.path, cleanedTableCount, cleanedRecordCount);

      // Create backup metadata
      final metadata = BackupMetadata(
        fileName: finalBackupName,
        filePath: backupFile.path,
        timestamp: DateTime.now(),
        originalDbPath: dbPath,
        fileSize: backupSize,
        status: BackupStatus.success,
        type: BackupType.manual,
      );

      // Save metadata to JSON file in a separate metadata subfolder
      await _saveBackupMetadata(metadata, backupDir);

      return BackupResult(
        success: true,
        metadata: metadata,
        message: 'Backup created successfully',
      );

    } catch (e) {
      debugPrint('Error creating backup: $e');
      return BackupResult(
        success: false,
        error: e.toString(),
        message: 'Failed to create backup: $e',
      );
    }
  }

  /// Get list of available backups across all monthly folders
  static Future<List<BackupMetadata>> getAvailableBackups([String? customBackupPath]) async {
    try {
      final backups = <BackupMetadata>[];
      final processedFiles = <String>{}; // Track processed files to avoid duplicates
      Directory baseDir;

      if (customBackupPath != null && customBackupPath.isNotEmpty) {
        baseDir = Directory(customBackupPath);
      } else {
        // Use the same project-relative directory as getBackupDirectory
        final projectRoot = await _findProjectRoot();
        baseDir = Directory(path.join(projectRoot, 'Backups'));
      }

      if (!await baseDir.exists()) {
        return backups;
      }

      // Scan all monthly folders (YYYY-MM format) and the base directory
      await for (final entity in baseDir.list()) {
        if (entity is Directory) {
          // Check if it's a monthly folder (YYYY-MM format)
          final dirName = path.basename(entity.path);
          final monthlyPattern = RegExp(r'^\d{4}-\d{2}$');
          
          if (monthlyPattern.hasMatch(dirName)) {
            // Process monthly folder
            await _processBackupDirectory(entity, backups, processedFiles);
          }
        } else if (entity is File && entity.path.endsWith('.db')) {
          // Process backup files in the root backup directory
          if (!processedFiles.contains(entity.path)) {
            await _processBackupFile(entity, baseDir, backups);
            processedFiles.add(entity.path);
          }
        }
      }

      // Remove duplicates based on file path (just in case)
      final uniqueBackups = <String, BackupMetadata>{};
      for (final backup in backups) {
        uniqueBackups[backup.filePath] = backup;
      }

      // Convert back to list and sort by timestamp (newest first)
      final finalBackups = uniqueBackups.values.toList();
      finalBackups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return finalBackups;
    } catch (e) {
      debugPrint('Error getting available backups: $e');
      return [];
    }
  }

  /// Process a backup directory and add backups to the list
  static Future<void> _processBackupDirectory(Directory directory, List<BackupMetadata> backups, [Set<String>? processedFiles]) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          // Check if we've already processed this file to avoid duplicates
          if (processedFiles == null || !processedFiles.contains(entity.path)) {
            await _processBackupFile(entity, directory, backups);
            processedFiles?.add(entity.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing backup directory ${directory.path}: $e');
    }
  }

  /// Process a single backup file and add it to the list
  static Future<void> _processBackupFile(File dbFile, Directory parentDir, List<BackupMetadata> backups) async {
    try {
      final stats = await dbFile.stat();
      final fileName = path.basename(dbFile.path);
      
      // Create metadata from file info only (no JSON files needed)
      final metadata = BackupMetadata(
          fileName: fileName,
          filePath: dbFile.path,
          timestamp: stats.modified,
          originalDbPath: '',
          fileSize: stats.size,
          status: BackupStatus.success,
          type: BackupType.manual,
        );

      backups.add(metadata);
    } catch (e) {
      debugPrint('Error processing backup file ${dbFile.path}: $e');
    }
  }

  /// Restore database from backup with enhanced error handling and recovery
  static Future<RestoreResult> restoreFromBackup(BackupMetadata backup) async {
    try {
      if (_dbHelper == null) {
        throw Exception('Backup service not initialized. Call BackupService.initialize() first.');
      }

      final backupFile = File(backup.filePath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: ${backup.filePath}');
      }

      // Validate backup file integrity
      final backupStats = await backupFile.stat();
      if (backupStats.size == 0) {
        throw Exception('Backup file is empty or corrupted');
      }

      // Get current database path
      final currentDbPath = await _dbHelper!.currentDatabasePath;
      if (currentDbPath == null) {
        throw Exception('Current database path not found');
      }

      debugPrint('BackupService: Starting full database restoration');
      debugPrint('BackupService: Current database path: $currentDbPath');
      debugPrint('BackupService: Backup file path: ${backup.filePath}');
      debugPrint('BackupService: Backup file size: ${backupStats.size} bytes');

      // Create backup of current database before restoration (with cleanup of old pre-restore backups)
      String? preRestoreBackupPath;
      final currentDbFile = File(currentDbPath);
      if (await currentDbFile.exists()) {
        final backupDir = await getBackupDirectory();
        
        // Clean up old pre-restore backups (keep only 1 most recent)
        await _cleanupOldPreRestoreBackups(backupDir);
        
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
        preRestoreBackupPath = path.join(backupDir.path, 'pre_restore_$timestamp.db');
        await currentDbFile.copy(preRestoreBackupPath);
        debugPrint('BackupService: Current database backed up to: $preRestoreBackupPath');
      }

      // Close current database connection properly with retries
      await _closeDatabaseConnection();

      // Wait for file handles to be released
      await Future.delayed(const Duration(milliseconds: 1000));

      try {
        // Remove the current database file if it exists
        if (await currentDbFile.exists()) {
          await currentDbFile.delete();
          debugPrint('BackupService: Current database file deleted');
        }

        // Wait a bit more to ensure file system has processed the deletion
        await Future.delayed(const Duration(milliseconds: 500));

        // Copy backup file to current database location
        await backupFile.copy(currentDbPath);
        debugPrint('BackupService: Backup file copied to database location');

        // Verify the restored file exists and has the correct size
        final restoredFile = File(currentDbPath);
        if (!await restoredFile.exists()) {
          throw Exception('Restored database file was not created');
        }

        final backupSize = await backupFile.length();
        final restoredSize = await restoredFile.length();
        if (backupSize != restoredSize) {
          throw Exception('Restored database file size mismatch. Expected: $backupSize, Actual: $restoredSize');
        }

        // Test database integrity by attempting to open it
        await _validateRestoredDatabase(currentDbPath);

        // Clean session data after restore to prevent authentication conflicts
        await _cleanSessionDataAfterRestore(currentDbPath);

        // Wait before allowing database reconnection
        await Future.delayed(const Duration(milliseconds: 1000));

        debugPrint('BackupService: Full database restoration completed successfully');

        return RestoreResult(
          success: true,
          message: 'Full database restored successfully from ${backup.fileName}. All data has been replaced with backup content. Application restart is recommended.',
          restoredFrom: backup,
        );

      } catch (restoreError) {
        debugPrint('BackupService: Error during restoration: $restoreError');
        
        // Attempt to restore the pre-restore backup if available
        if (preRestoreBackupPath != null) {
          try {
            final preRestoreFile = File(preRestoreBackupPath);
            if (await preRestoreFile.exists()) {
              await preRestoreFile.copy(currentDbPath);
              debugPrint('BackupService: Restored original database from pre-restore backup');
            }
          } catch (rollbackError) {
            debugPrint('BackupService: Failed to rollback to original database: $rollbackError');
          }
        }
        
        throw restoreError;
      }

    } catch (e) {
      debugPrint('BackupService: Error restoring from backup: $e');
      return RestoreResult(
        success: false,
        error: e.toString(),
        message: 'Failed to restore from backup: $e',
      );
    }
  }

  /// Create a full database backup with complete metadata capture
  /// This method captures the entire database at a given point, ensuring all data can be restored
  static Future<BackupResult> createFullDatabaseBackup({
    String? customBackupPath, 
    String? backupName,
    bool includeSchema = true,
    bool includeData = true,
  }) async {
    try {
      if (_dbHelper == null) {
        throw Exception('Backup service not initialized. Call BackupService.initialize() first.');
      }

      debugPrint('BackupService: Starting full database backup');

      // Get current database path
      final dbPath = await _dbHelper!.currentDatabasePath;
      if (dbPath == null) {
        throw Exception('Database path not found');
      }

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('Database file not found at path: $dbPath');
      }

      // Ensure database is in a consistent state
      final db = await _dbHelper!.database;
      await db.execute('PRAGMA wal_checkpoint(FULL)'); // Force WAL checkpoint
      await db.execute('VACUUM'); // Optimize database file

      // Clean session data from the database before backup to prevent conflicts
      await _cleanSessionDataForBackup(db);

      // Get backup directory
      final backupDir = await getBackupDirectory(customBackupPath);
      
      // Generate backup filename with timestamp and type indicator
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      String finalBackupName;
      
      if (backupName?.isNotEmpty == true) {
        String cleanName = backupName!;
        if (cleanName.toLowerCase().endsWith('.db')) {
          cleanName = cleanName.substring(0, cleanName.length - 3);
        }
        finalBackupName = 'FULL_${cleanName}_$timestamp.db';
      } else {
        finalBackupName = 'FULL_backup_$timestamp.db';
      }
      
      final backupFile = File(path.join(backupDir.path, finalBackupName));

      // Get database metadata before backup
      final dbSize = await dbFile.length();
      final tableCount = await _getTableCount(db);
      final recordCount = await _getTotalRecordCount(db);
      
      debugPrint('BackupService: Database size: $dbSize bytes');
      debugPrint('BackupService: Tables: $tableCount');
      debugPrint('BackupService: Total records: $recordCount');

      // Create the backup file
      await dbFile.copy(backupFile.path);

      // Remove user sessions from the backup to prevent authentication conflicts
      await _cleanUserSessionsFromBackup(backupFile.path);

      // Verify backup integrity after cleaning
      if (!await backupFile.exists()) {
        throw Exception('Backup file was not created successfully');
      }

      final backupSize = await backupFile.length();
      debugPrint('BackupService: Backup size after session cleanup: $backupSize bytes');

      // Get updated metadata after cleanup
      final cleanedTableCount = await _getTableCountFromFile(backupFile.path);
      final cleanedRecordCount = await _getTotalRecordCountFromFile(backupFile.path);
      
      // Verify backup can be opened and contains expected data (without sessions)
      await _validateBackupIntegrity(backupFile.path, cleanedTableCount, cleanedRecordCount);

      // Create enhanced backup metadata
      final metadata = BackupMetadata(
        fileName: finalBackupName,
        filePath: backupFile.path,
        timestamp: DateTime.now(),
        originalDbPath: dbPath,
        fileSize: backupSize,
        status: BackupStatus.success,
        type: BackupType.manual,
        metadata: {
          'backup_type': 'full_database',
          'table_count': tableCount,
          'record_count': recordCount,
          'schema_included': includeSchema,
          'data_included': includeData,
          'database_version': await _getDatabaseVersion(db),
          'backup_method': 'file_copy',
          'integrity_checked': true,
        },
      );

      // Save metadata
      await _saveBackupMetadata(metadata, backupDir);

      debugPrint('BackupService: Full database backup completed successfully');

      return BackupResult(
        success: true,
        metadata: metadata,
        message: 'Full database backup created successfully with ${tableCount} tables and ${recordCount} records',
      );

    } catch (e) {
      debugPrint('BackupService: Error creating full database backup: $e');
      return BackupResult(
        success: false,
        error: e.toString(),
        message: 'Failed to create full database backup: $e',
      );
    }
  }

  /// Migrate and overwrite current database with backup data
  /// (Simplified - now just calls restoreFromBackup to avoid multiple pre-restore backups)
  static Future<RestoreResult> migrateFromBackup(BackupMetadata backup, {
    bool createPreMigrationBackup = true,
    bool validateAfterMigration = true,
  }) async {
    debugPrint('BackupService: Migration requested - using standard restore method to avoid duplicate pre-backups');
    return await restoreFromBackup(backup);
  }

  /// Overwrite current database with backup (simplified alias for standard restore)
  static Future<RestoreResult> overwriteDatabaseWithBackup(BackupMetadata backup) async {
    debugPrint('BackupService: Overwrite requested - using standard restore method to avoid duplicate pre-backups');
    return await restoreFromBackup(backup);
  }

  /// Get table count from database
  static Future<int> _getTableCount(Database db) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total record count across all tables
  static Future<int> _getTotalRecordCount(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    
    int totalRecords = 0;
    for (final table in tables) {
      final tableName = table['name'] as String;
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM "$tableName"');
        final count = Sqflite.firstIntValue(result) ?? 0;
        totalRecords += count;
      } catch (e) {
        debugPrint('BackupService: Error counting records in table $tableName: $e');
      }
    }
    
    return totalRecords;
  }

  /// Get database version
  static Future<int> _getDatabaseVersion(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('BackupService: Error getting database version: $e');
      return 0;
    }
  }

  /// Validate backup integrity by opening and checking content
  static Future<void> _validateBackupIntegrity(String backupPath, int expectedTables, int expectedRecords) async {
    try {
      final db = await openDatabase(
        backupPath,
        readOnly: true,
        singleInstance: false,
      );
      
      // Check table count
      final actualTables = await _getTableCount(db);
      if (actualTables != expectedTables) {
        await db.close();
        throw Exception('Backup integrity check failed - table count mismatch. Expected: $expectedTables, Found: $actualTables');
      }
      
      // Check record count (allow for small variations due to timing)
      final actualRecords = await _getTotalRecordCount(db);
      final recordDifference = (actualRecords - expectedRecords).abs();
      if (recordDifference > (expectedRecords * 0.01)) { // Allow 1% variation
        await db.close();
        throw Exception('Backup integrity check failed - significant record count mismatch. Expected: ~$expectedRecords, Found: $actualRecords');
      }
      
      await db.close();
      debugPrint('BackupService: Backup integrity validation passed');
      
    } catch (e) {
      throw Exception('Backup integrity validation failed: $e');
    }
  }

  /// Close database connection with proper reset for restore operations
  static Future<void> _closeDatabaseConnection() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // Use the proper database reset method
        await _dbHelper!.closeAndResetDatabase();
        debugPrint('BackupService: Database connection closed and reset successfully');
        
        return;
      } catch (e) {
        retryCount++;
        debugPrint('BackupService: Database close attempt $retryCount failed: $e');
        
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        } else {
          debugPrint('BackupService: Warning - Could not close database after $maxRetries attempts');
        }
      }
    }
  }

  /// Validate that the restored database is functional
  static Future<void> _validateRestoredDatabase(String dbPath) async {
    try {
      final db = await openDatabase(
        dbPath,
        readOnly: true,
        singleInstance: false,
      );
      
      // Test basic database operations
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      debugPrint('BackupService: Restored database contains ${tables.length} tables');
      
      // Test a simple query on a core table
      if (tables.any((table) => table['name'] == 'patients')) {
        final patientCount = await db.rawQuery('SELECT COUNT(*) as count FROM patients');
        debugPrint('BackupService: Restored database has ${patientCount.first['count']} patients');
      }
      
      await db.close();
      debugPrint('BackupService: Database integrity validation passed');
      
    } catch (e) {
      throw Exception('Restored database failed integrity check: $e');
    }
  }

  /// Delete a backup file
  static Future<bool> deleteBackup(BackupMetadata backup) async {
    try {
      final backupFile = File(backup.filePath);
      if (await backupFile.exists()) {
        await backupFile.delete();
        debugPrint('BackupService: Deleted backup file: ${backup.filePath}');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Get backup directory size and file count across all monthly folders
  static Future<BackupDirectoryInfo> getBackupDirectoryInfo([String? customBackupPath]) async {
    try {
      Directory baseDir;

      if (customBackupPath != null && customBackupPath.isNotEmpty) {
        baseDir = Directory(customBackupPath);
      } else {
        // Use the same project-relative directory as getBackupDirectory
        final projectRoot = await _findProjectRoot();
        baseDir = Directory(path.join(projectRoot, 'Backups'));
      }
      
      if (!await baseDir.exists()) {
        return BackupDirectoryInfo(
          path: baseDir.path,
          totalSize: 0,
          fileCount: 0,
          lastBackup: null,
        );
      }

      int totalSize = 0;
      int fileCount = 0;
      DateTime? lastBackup;

      // Scan all monthly folders and the base directory
      await for (final entity in baseDir.list()) {
        if (entity is Directory) {
          // Check if it's a monthly folder (YYYY-MM format)
          final dirName = path.basename(entity.path);
          final monthlyPattern = RegExp(r'^\d{4}-\d{2}$');
          
          if (monthlyPattern.hasMatch(dirName)) {
            // Process monthly folder
            await for (final subEntity in entity.list()) {
              if (subEntity is File && subEntity.path.endsWith('.db')) {
                final stats = await subEntity.stat();
                totalSize += stats.size;
                fileCount++;
                
                if (lastBackup == null || stats.modified.isAfter(lastBackup)) {
                  lastBackup = stats.modified;
                }
              }
            }
          }
        } else if (entity is File && entity.path.endsWith('.db')) {
          // Process backup files in the root backup directory
          final stats = await entity.stat();
          totalSize += stats.size;
          fileCount++;
          
          if (lastBackup == null || stats.modified.isAfter(lastBackup)) {
            lastBackup = stats.modified;
          }
        }
      }

      return BackupDirectoryInfo(
        path: baseDir.path,
        totalSize: totalSize,
        fileCount: fileCount,
        lastBackup: lastBackup,
      );
    } catch (e) {
      debugPrint('Error getting backup directory info: $e');
      return BackupDirectoryInfo(
        path: '',
        totalSize: 0,
        fileCount: 0,
        lastBackup: null,
      );
    }
  }

  /// Save backup metadata to JSON file in a separate metadata subfolder
  /// Clean up old backups (keep only specified number of recent backups)
  static Future<void> cleanupOldBackups({int keepCount = 10, String? customBackupPath}) async {
    try {
      final backups = await getAvailableBackups(customBackupPath);
      
      if (backups.length <= keepCount) {
        return; // No cleanup needed
      }

      // Sort by timestamp and keep only the most recent ones
      backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final backupsToDelete = backups.skip(keepCount).toList();

      for (final backup in backupsToDelete) {
        await deleteBackup(backup);
      }

      debugPrint('BackupService: Cleaned up ${backupsToDelete.length} old backup(s)');
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }

  /// Clean up empty monthly folders
  static Future<void> cleanupEmptyMonthlyFolders([String? customBackupPath]) async {
    try {
      Directory baseDir;

      if (customBackupPath != null && customBackupPath.isNotEmpty) {
        baseDir = Directory(customBackupPath);
      } else {
        // Use the same project-relative directory as getBackupDirectory
        final projectRoot = await _findProjectRoot();
        baseDir = Directory(path.join(projectRoot, 'Backups'));
      }

      if (!await baseDir.exists()) {
        return;
      }

      // Check monthly folders and remove empty ones
      await for (final entity in baseDir.list()) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);
          final monthlyPattern = RegExp(r'^\d{4}-\d{2}$');
          
          if (monthlyPattern.hasMatch(dirName)) {
            // Check if the monthly folder is empty
            final List<FileSystemEntity> contents = await entity.list().toList();
            final hasDbFiles = contents.any((item) => 
              item is File && item.path.endsWith('.db'));
            
            if (!hasDbFiles) {
              await entity.delete(recursive: true);
              debugPrint('BackupService: Removed empty monthly folder: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up empty monthly folders: $e');
    }
  }

  /// Clean up any existing metadata folders (from previous backup implementations)
  static Future<void> cleanupMetadataFolders([String? customBackupPath]) async {
    try {
      Directory baseDir;

      if (customBackupPath != null && customBackupPath.isNotEmpty) {
        baseDir = Directory(customBackupPath);
      } else {
        // Use the same project-relative directory as getBackupDirectory
        final projectRoot = await _findProjectRoot();
        baseDir = Directory(path.join(projectRoot, 'Backups'));
      }

      if (!await baseDir.exists()) {
        return;
      }

      int foldersRemoved = 0;

      // Check all directories in the backup folder
      await for (final entity in baseDir.list()) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);
          
          // Check monthly folders for metadata subfolders
          final monthlyPattern = RegExp(r'^\d{4}-\d{2}$');
          if (monthlyPattern.hasMatch(dirName)) {
            final metadataDir = Directory(path.join(entity.path, 'metadata'));
            if (await metadataDir.exists()) {
              await metadataDir.delete(recursive: true);
              foldersRemoved++;
              debugPrint('BackupService: Removed metadata folder: ${metadataDir.path}');
            }
          }
          // Also check for standalone metadata folders
          else if (dirName == 'metadata') {
            await entity.delete(recursive: true);
            foldersRemoved++;
            debugPrint('BackupService: Removed standalone metadata folder: ${entity.path}');
          }
        }
      }

      if (foldersRemoved > 0) {
        debugPrint('BackupService: Cleaned up $foldersRemoved metadata folder(s)');
      }
    } catch (e) {
      debugPrint('Error cleaning up metadata folders: $e');
    }
  }

  /// Find the project root directory (jgem-main folder)
  static Future<String> _findProjectRoot() async {
    try {
      // Start from the current working directory
      Directory currentDir = Directory.current;
      
      // Look for the jgem-main folder by traversing up and down the directory tree
      String? projectRoot = await _searchForProjectRoot(currentDir);
      
      if (projectRoot != null) {
        return projectRoot;
      }
      
      // If not found from current directory, try from the executable path
      // This helps when the app is run from different working directories
      final String executablePath = Platform.resolvedExecutable;
      final Directory executableDir = Directory(path.dirname(executablePath));
      
      projectRoot = await _searchForProjectRoot(executableDir);
      if (projectRoot != null) {
        return projectRoot;
      }
      
      // If still not found, try to find it by looking for pubspec.yaml
      // and checking if parent contains "jgem-main"
      final pubspecPath = await _findFileInAncestors(currentDir, 'pubspec.yaml');
      if (pubspecPath != null) {
        Directory pubspecDir = Directory(path.dirname(pubspecPath));
        // Go up one level from flutter_application_1 to jgem-main
        final parentDir = pubspecDir.parent;
        if (path.basename(parentDir.path).contains('jgem-main') || 
            path.basename(parentDir.path) == 'jgem-main') {
          return parentDir.path;
        }
        
        // If parent doesn't contain jgem-main, use it as fallback
        return parentDir.path;
      }
      
      // Fallback: use current directory's parent if nothing else works
      debugPrint('BackupService: Could not find jgem-main folder, using fallback path');
      return currentDir.parent.path;
      
    } catch (e) {
      debugPrint('BackupService: Error finding project root: $e');
      // Ultimate fallback - use current directory
      return Directory.current.path;
    }
  }
  
  /// Search for project root containing jgem-main folder
  static Future<String?> _searchForProjectRoot(Directory startDir) async {
    try {
      Directory currentDir = startDir;
      
      // Search up the directory tree (max 10 levels to prevent infinite loops)
      for (int i = 0; i < 10; i++) {
        // Check if current directory is or contains jgem-main
        if (path.basename(currentDir.path).contains('jgem-main') || 
            path.basename(currentDir.path) == 'jgem-main') {
          return currentDir.path;
        }
        
        // Check if current directory contains a jgem-main subfolder
        final jgemMainDir = Directory(path.join(currentDir.path, 'jgem-main'));
        if (await jgemMainDir.exists()) {
          return jgemMainDir.path;
        }
        
        // Move up one level
        final parentDir = currentDir.parent;
        if (parentDir.path == currentDir.path) {
          // Reached filesystem root
          break;
        }
        currentDir = parentDir;
      }
      
      return null;
    } catch (e) {
      debugPrint('BackupService: Error in _searchForProjectRoot: $e');
      return null;
    }
  }
  
  /// Find a specific file in ancestor directories
  static Future<String?> _findFileInAncestors(Directory startDir, String fileName) async {
    try {
      Directory currentDir = startDir;
      
      // Search up the directory tree (max 10 levels)
      for (int i = 0; i < 10; i++) {
        final file = File(path.join(currentDir.path, fileName));
        if (await file.exists()) {
          return file.path;
        }
        
        final parentDir = currentDir.parent;
        if (parentDir.path == currentDir.path) {
          // Reached filesystem root
          break;
        }
        currentDir = parentDir;
      }
      
      return null;
    } catch (e) {
      debugPrint('BackupService: Error in _findFileInAncestors: $e');
      return null;
    }
  }

  /// Save backup metadata to JSON file in a separate metadata subfolder
  static Future<void> _saveBackupMetadata(BackupMetadata metadata, Directory backupDir) async {
    try {
      // Create metadata subfolder
      final metadataDir = Directory(path.join(backupDir.path, 'metadata'));
      if (!await metadataDir.exists()) {
        await metadataDir.create(recursive: true);
      }

      // Create metadata file path (same name as backup but with .json extension)
      final dbFileName = path.basenameWithoutExtension(metadata.fileName);
      final metadataFileName = '$dbFileName.json';
      final metadataFile = File(path.join(metadataDir.path, metadataFileName));

      // Write metadata to JSON file
      await metadataFile.writeAsString(metadata.toJson());
      debugPrint('BackupService: Saved metadata to ${metadataFile.path}');
    } catch (e) {
      debugPrint('BackupService: Error saving metadata: $e');
      // Don't throw error as metadata is optional
    }
  }

  /// Clean up old pre-restore backups to prevent accumulation
  /// Keeps only the 1 most recent pre-restore backup
  static Future<void> _cleanupOldPreRestoreBackups(Directory backupDir) async {
    try {
      final preRestoreFiles = <File>[];
      
      // Find all pre-restore backup files
      await for (final entity in backupDir.list()) {
        if (entity is File && path.basename(entity.path).startsWith('pre_restore_')) {
          preRestoreFiles.add(entity);
        }
      }
      
      if (preRestoreFiles.length <= 1) {
        debugPrint('BackupService: Found ${preRestoreFiles.length} pre-restore backups, no cleanup needed');
        return;
      }
      
      // Sort by modification time (newest first)
      preRestoreFiles.sort((a, b) {
        final statA = a.statSync();
        final statB = b.statSync();
        return statB.modified.compareTo(statA.modified);
      });
      
      // Delete all but the 1 most recent
      final filesToDelete = preRestoreFiles.skip(1).toList();
      for (final file in filesToDelete) {
        try {
          await file.delete();
          debugPrint('BackupService: Deleted old pre-restore backup: ${path.basename(file.path)}');
        } catch (e) {
          debugPrint('BackupService: Error deleting old pre-restore backup ${file.path}: $e');
        }
      }
      
      debugPrint('BackupService: Cleaned up ${filesToDelete.length} old pre-restore backups, kept ${preRestoreFiles.length - filesToDelete.length}');
    } catch (e) {
      debugPrint('BackupService: Error cleaning up old pre-restore backups: $e');
      // Don't fail the restore if cleanup fails
    }
  }

  /// Clean session data from database before backup to prevent authentication conflicts
  static Future<void> _cleanSessionDataForBackup(Database db) async {
    try {
      // Clear all user sessions before backup to prevent token conflicts
      await db.delete('user_sessions');
      debugPrint('BackupService: Cleared all user sessions from database before backup');
      
      // Also clear any other ephemeral/session-related data if needed
      // You can add other tables here that shouldn't be backed up
      
    } catch (e) {
      debugPrint('BackupService: Warning - could not clean session data before backup: $e');
      // Don't fail the backup if session cleanup fails
    }
  }

  /// Clean session data after restore to prevent authentication conflicts
  static Future<void> _cleanSessionDataAfterRestore(String dbPath) async {
    try {
      final db = await openDatabase(
        dbPath,
        readOnly: false,
        singleInstance: false,
      );
      
      // Delete all user sessions from the restored database
      final deletedCount = await db.delete('user_sessions');
      await db.close();
      
      debugPrint('BackupService: Cleaned $deletedCount user sessions from restored database to prevent conflicts');
    } catch (e) {
      debugPrint('BackupService: Warning - Could not clean sessions after restore: $e');
      // Don't fail the restore if we can't clean sessions
    }
  }

  /// Clean user sessions from a backup file to prevent authentication conflicts
  static Future<void> _cleanUserSessionsFromBackup(String backupFilePath) async {
    try {
      final backupDb = await openDatabase(
        backupFilePath,
        readOnly: false,
        singleInstance: false,
      );
      
      // Delete all user sessions from the backup
      final deletedCount = await backupDb.delete('user_sessions');
      await backupDb.close();
      
      debugPrint('BackupService: Removed $deletedCount user sessions from backup to prevent conflicts');
    } catch (e) {
      debugPrint('BackupService: Error cleaning user sessions from backup: $e');
      // Don't fail the backup if we can't clean sessions - just warn
    }
  }

  /// Get table count from a database file
  static Future<int> _getTableCountFromFile(String dbFilePath) async {
    try {
      final db = await openDatabase(
        dbFilePath,
        readOnly: true,
        singleInstance: false,
      );
      final count = await _getTableCount(db);
      await db.close();
      return count;
    } catch (e) {
      debugPrint('BackupService: Error getting table count from file: $e');
      return 0;
    }
  }

  /// Get total record count from a database file
  static Future<int> _getTotalRecordCountFromFile(String dbFilePath) async {
    try {
      final db = await openDatabase(
        dbFilePath,
        readOnly: true,
        singleInstance: false,
      );
      final count = await _getTotalRecordCount(db);
      await db.close();
      return count;
    } catch (e) {
      debugPrint('BackupService: Error getting record count from file: $e');
      return 0;
    }
  }

  /// Clean all user sessions from the current database (utility method)
  static Future<bool> cleanAllUserSessions() async {
    try {
      if (_dbHelper == null) {
        throw Exception('Backup service not initialized');
      }

      final db = await _dbHelper!.database;
      final deletedCount = await db.delete('user_sessions');
      
      debugPrint('BackupService: Cleaned $deletedCount user sessions from current database');
      return true;
    } catch (e) {
      debugPrint('BackupService: Error cleaning user sessions: $e');
      return false;
    }
  }
}

/// Backup metadata class
class BackupMetadata {
  final String fileName;
  final String filePath;
  final DateTime timestamp;
  final String originalDbPath;
  final int fileSize;
  final BackupStatus status;
  final BackupType type;
  final String? description;
  final Map<String, dynamic>? metadata;

  BackupMetadata({
    required this.fileName,
    required this.filePath,
    required this.timestamp,
    required this.originalDbPath,
    required this.fileSize,
    required this.status,
    required this.type,
    this.description,
    this.metadata,
  });

  String get formattedSize {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int bytes = fileSize;
    int suffixIndex = 0;
    
    while (bytes >= 1024 && suffixIndex < suffixes.length - 1) {
      bytes ~/= 1024;
      suffixIndex++;
    }
    
    return '$bytes ${suffixes[suffixIndex]}';
  }

  String get formattedTimestamp => DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

  String toJson() {
    return '''{
  "fileName": "$fileName",
  "filePath": "$filePath",
  "timestamp": "${timestamp.toIso8601String()}",
  "originalDbPath": "$originalDbPath",
  "fileSize": $fileSize,
  "status": "${status.name}",
  "type": "${type.name}",
  "description": ${description != null ? '"$description"' : 'null'},
  "metadata": ${metadata != null ? jsonEncode(metadata) : 'null'}
}''';
  }

  static BackupMetadata fromJson(String jsonString) {
    final Map<String, dynamic> json = {};
    
    // Simple JSON parsing (you might want to use dart:convert for more complex cases)
    final lines = jsonString.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty || line.trim().startsWith('{') || line.trim().startsWith('}')) continue;
      
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim().replaceAll('"', '').replaceAll(',', '');
        final value = parts.sublist(1).join(':').trim().replaceAll('"', '').replaceAll(',', '');
        json[key] = value;
      }
    }

    return BackupMetadata(
      fileName: json['fileName'] ?? '',
      filePath: json['filePath'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      originalDbPath: json['originalDbPath'] ?? '',
      fileSize: int.tryParse(json['fileSize'] ?? '0') ?? 0,
      status: BackupStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BackupStatus.success,
      ),
      type: BackupType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BackupType.manual,
      ),
      description: json['description'] == 'null' ? null : json['description'],
      metadata: json['metadata'] == 'null' ? null : (json['metadata'] != null ? jsonDecode(json['metadata']) : null),
    );
  }
}

/// Backup result class
class BackupResult {
  final bool success;
  final BackupMetadata? metadata;
  final String? error;
  final String message;

  BackupResult({
    required this.success,
    this.metadata,
    this.error,
    required this.message,
  });
}

/// Restore result class
class RestoreResult {
  final bool success;
  final String? error;
  final String message;
  final BackupMetadata? restoredFrom;

  RestoreResult({
    required this.success,
    this.error,
    required this.message,
    this.restoredFrom,
  });
}

/// Backup directory info
class BackupDirectoryInfo {
  final String path;
  final int totalSize;
  final int fileCount;
  final DateTime? lastBackup;

  BackupDirectoryInfo({
    required this.path,
    required this.totalSize,
    required this.fileCount,
    this.lastBackup,
  });

  String get formattedTotalSize {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int bytes = totalSize;
    int suffixIndex = 0;
    
    while (bytes >= 1024 && suffixIndex < suffixes.length - 1) {
      bytes ~/= 1024;
      suffixIndex++;
    }
    
    return '$bytes ${suffixes[suffixIndex]}';
  }

  String get formattedLastBackup {
    if (lastBackup == null) return 'Never';
    return DateFormat('yyyy-MM-dd HH:mm').format(lastBackup!);
  }
}

/// Backup status enum
enum BackupStatus {
  success,
  failed,
  inProgress,
}

/// Backup type enum
enum BackupType {
  manual,
  automatic,
  scheduled,
}
