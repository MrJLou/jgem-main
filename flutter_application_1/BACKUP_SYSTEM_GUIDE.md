# Database Backup & Restore System

## Overview

The enhanced backup and restore system provides a comprehensive solution for creating, managing, and restoring database backups across different devices and platforms. The system is designed to be dynamic and platform-aware, automatically adjusting paths and behaviors based on the operating system.

## Features

### 🔄 Dynamic Path Management
- **Platform-Aware**: Automatically detects the operating system and uses appropriate default backup locations
- **Custom Folder Selection**: Users can select custom backup folders using a file picker dialog
- **Cross-Device Compatibility**: Works consistently across Windows, macOS, Linux, iOS, and Android

### 💾 Database Backup
- **Real Database Backup**: Creates actual copies of the SQLite database file
- **Timestamp-Based Naming**: Each backup includes creation timestamp for easy identification
- **Custom Naming**: Option to provide custom names for backups (e.g., "Before Update", "Daily Backup")
- **Size Tracking**: Displays file sizes in human-readable format (B, KB, MB, GB)

### 🔄 Database Restore
- **Safe Restoration**: Automatically creates a backup of current database before restoring
- **Confirmation Dialogs**: Multiple confirmation steps to prevent accidental data loss
- **Restart Notification**: Alerts users when app restart is required after restoration

### 📊 Backup Management
- **Backup History**: View all available backups with creation dates, sizes, and types
- **Cleanup Tools**: Automatically clean up old backups (keeps most recent 5-10 by default)
- **Delete Individual Backups**: Remove specific backup files when no longer needed
- **Folder Operations**: Open backup folder in system file explorer

### ⚡ Automatic Backup
- **Scheduled Backups**: Configure automatic backups (Daily, Weekly, Monthly)
- **Background Processing**: Automatic backups run without user intervention
- **Smart Scheduling**: Uses Flutter Timer for reliable scheduling

## Platform-Specific Behavior

### Windows
- **Default Location**: `%USERPROFILE%\Documents\JGEM_Backups`
- **Folder Access**: Uses Windows Explorer for folder operations
- **Path Format**: Uses Windows-style backslashes

### macOS
- **Default Location**: `~/Documents/JGEM_Backups`
- **Folder Access**: Uses macOS Finder for folder operations
- **Path Format**: Uses Unix-style forward slashes

### Linux
- **Default Location**: `~/Documents/JGEM_Backups`
- **Folder Access**: Uses xdg-open for folder operations
- **Path Format**: Uses Unix-style forward slashes

### Mobile (iOS/Android)
- **Default Location**: App-specific documents directory
- **Fallback Handling**: Graceful fallback to internal storage if external storage unavailable
- **Path Copying**: Copies paths to clipboard when file explorer unavailable

## Usage Guide

### Creating a Backup

1. **Navigate to Backup Screen**: Go to Maintenance → Backup & Restore
2. **Click "Create Backup"**: Tap the blue backup button
3. **Optional Name**: Enter a custom name for the backup (or leave blank for automatic naming)
4. **Wait for Completion**: The system will create a copy of the database file
5. **Confirmation**: Success message will display the backup file name

### Restoring from Backup

1. **Select Backup**: In the Available Backups table, click on a backup row to select it
2. **Click Restore**: Click the restore icon (circular arrow) for the desired backup
3. **Confirm Action**: Review the backup details and confirm the restoration
4. **Wait for Process**: The system will:
   - Create a backup of current database
   - Replace current database with selected backup
   - Reinitialize database connections
5. **Restart Application**: Follow the prompt to restart the app for changes to take effect

### Changing Backup Location

1. **Click "Select Folder"**: Tap the orange folder button
2. **Choose Directory**: Use the file picker to select a custom backup folder
3. **Automatic Refresh**: The system will immediately scan the new folder for existing backups

### Managing Backups

- **Refresh List**: Click the refresh icon to reload available backups
- **Cleanup Old Backups**: Click "Cleanup" to remove old backups (keeps 5 most recent)
- **Delete Individual Backup**: Click the red delete icon next to any backup
- **Open Backup Folder**: Click "Open Folder" to view backups in file explorer

## Technical Implementation

### File Structure
```
JGEM_Backups/
├── 2025-06/
│   ├── backup_2024-12-30_14-30-15.db
│   ├── custom_backup_2024-12-30_15-45-22.db
│   ├── pre_restore_2024-12-30_16-20-10.db
│   └── metadata/
│       ├── backup_2024-12-30_14-30-15.db.metadata.json
│       ├── custom_backup_2024-12-30_15-45-22.db.metadata.json
│       └── pre_restore_2024-12-30_16-20-10.db.metadata.json
└── 2025-07/
    ├── backup_2024-12-31_10-15-30.db
    └── metadata/
        └── backup_2024-12-31_10-15-30.db.metadata.json
```

### Metadata Format
Each backup includes a JSON metadata file stored in a separate `metadata` subfolder to keep the main backup directory clean. The metadata contains:
- Original database path
- Creation timestamp
- File size
- Backup type (manual/automatic)
- Optional description

**Note**: Users will only see the `.db` files in the main backup folder for easy access, while metadata files are stored separately for system use.

### Safety Features
- **Pre-restore Backup**: Always creates backup before restoration
- **File Verification**: Verifies backup file integrity after creation
- **Size Validation**: Confirms backup file matches original database size
- **Error Handling**: Comprehensive error handling with user-friendly messages

## Configuration

### Automatic Backup Settings
- **Frequency Options**: Daily, Weekly, Monthly
- **Persistent Settings**: Backup preferences saved across app sessions
- **Smart Scheduling**: Automatically reschedules when frequency changes

### Cleanup Settings
- **Default Retention**: Keeps 10 most recent backups
- **Configurable Retention**: Can be adjusted in code (keepCount parameter)
- **Type-Aware Cleanup**: Preserves important manual backups over automatic ones

## Error Handling

The system includes comprehensive error handling for:
- Database connection issues
- File system permissions
- Insufficient storage space
- Corrupted backup files
- Network storage locations
- Cross-platform compatibility issues

## Security Considerations

- **Local Storage**: Backups are stored locally on the device
- **No Encryption**: Database files are stored in plain format (consider encryption for sensitive data)
- **Permission Handling**: Requests appropriate file system permissions
- **Path Validation**: Validates backup paths to prevent directory traversal

## Future Enhancements

Potential improvements for future versions:
- **Cloud Backup Integration**: Support for Google Drive, OneDrive, Dropbox
- **Backup Encryption**: Optional encryption for sensitive data
- **Incremental Backups**: Only backup changed data to save space
- **Backup Compression**: Compress backup files to reduce storage usage
- **Network Backup**: Backup to network locations or shared drives
- **Backup Verification**: Advanced integrity checking with checksums
