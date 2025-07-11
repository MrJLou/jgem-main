import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/backup_service.dart';
import '../../services/database_helper.dart';
import '../../utils/error_dialog_utils.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  BackupScreenState createState() => BackupScreenState();
}

class BackupScreenState extends State<BackupScreen> {
  bool _isAutoBackupEnabled = false;
  String _selectedBackupFrequency = 'Daily';
  final List<String> _backupFrequencies = ['Daily', 'Weekly', 'Monthly'];
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoadingBackups = false;
  Timer? _backupTimer;
  String? _customBackupPath;
  List<BackupMetadata> _availableBackups = [];
  BackupDirectoryInfo? _backupDirInfo;
  BackupMetadata? _selectedBackupForRestore;

  @override
  void initState() {
    super.initState();
    _initializeBackupSystem();
  }

  Future<void> _initializeBackupSystem() async {
    // Initialize backup service
    BackupService.initialize(DatabaseHelper());
    
    // Load backup directory info and available backups
    await _refreshBackupInfo();
  }

  Future<void> _refreshBackupInfo() async {
    setState(() {
      _isLoadingBackups = true;
    });

    try {
      // Get backup directory info
      _backupDirInfo = await BackupService.getBackupDirectoryInfo(_customBackupPath);
      
      // Get available backups
      _availableBackups = await BackupService.getAvailableBackups(_customBackupPath);
      
    } catch (e) {
      debugPrint('Error refreshing backup info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBackups = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
  }

  Future<String?> _showBackupNameDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for this backup (optional):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backup Name',
                hintText: 'e.g., Before Update, Daily Backup',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFullBackup() async {
    // Show name dialog
    final name = await _showBackupNameDialog();
    if (name == null) return; // User cancelled

    setState(() {
      _isBackingUp = true;
    });

    try {
      final result = await BackupService.createFullDatabaseBackup(
        customBackupPath: _customBackupPath,
        backupName: name.trim().isEmpty ? null : name.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        ErrorDialogUtils.showSuccessDialog(
          context: context,
          title: 'Backup Created',
          message: 'Full database backup created successfully: ${result.metadata!.fileName}',
        );

        // Refresh backup list
        await _refreshBackupInfo();
      } else {
        ErrorDialogUtils.showErrorDialog(
          context: context,
          title: 'Backup Failed',
          message: 'Failed to create full backup: ${result.error}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ErrorDialogUtils.showErrorDialog(
        context: context,
        title: 'Backup Error',
        message: 'Error creating full backup: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _cleanUserSessions() async {
    try {
      setState(() {
        _isRestoring = true;
      });

      final result = await BackupService.cleanAllUserSessions();

      if (!mounted) return;

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All user sessions cleaned successfully. You can now log in normally.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clean user sessions'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cleaning user sessions: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _restoreFromBackup(BackupMetadata backup) async {
    // Show confirmation dialog
    final confirmed = await _showRestoreConfirmationDialog(backup);
    if (!confirmed) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      final result = await BackupService.restoreFromBackup(backup);

      if (!mounted) return;

      if (result.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database restored successfully from ${backup.fileName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Show restart dialog
        _showRestartDialog();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: ${result.error}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restoring backup: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<bool> _showRestoreConfirmationDialog(BackupMetadata backup) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to restore from this backup?'),
            const SizedBox(height: 16),
            Text('Backup: ${backup.fileName}'),
            Text('Created: ${backup.formattedTimestamp}'),
            Text('Size: ${backup.formattedSize}'),
            const SizedBox(height: 16),
            const Text(
              'Warning: This will replace your current database. '
              'A backup of your current data will be created automatically.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Restart Required'),
        content: const Text(
          'The database has been restored successfully. '
          'Please restart the application to ensure all changes take effect.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Close the app (user will need to manually restart)
              if (Platform.isAndroid || Platform.isIOS) {
                exit(0);
              } else {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBackupFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        setState(() {
          _customBackupPath = selectedDirectory;
        });
        
        // Refresh backup info with new path
        await _refreshBackupInfo();
        
        if (!mounted) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup folder set to: $selectedDirectory'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting folder: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _deleteBackup(BackupMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete ${backup.fileName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final success = await BackupService.deleteBackup(backup);
      
      if (success) {
        if (!mounted) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup ${backup.fileName} deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Refresh backup list
        await _refreshBackupInfo();
      } else {
        if (!mounted) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete backup ${backup.fileName}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting backup: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _openBackupFolder() async {
    try {
      final backupDir = await BackupService.getBackupDirectory(_customBackupPath);
      
      if (Platform.isWindows) {
        await Process.run('explorer', [backupDir.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [backupDir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [backupDir.path]);
      } else {
        // Copy path to clipboard for other platforms
        await Clipboard.setData(ClipboardData(text: backupDir.path));
        if (!mounted) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup folder path copied to clipboard: ${backupDir.path}'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening backup folder: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _toggleAutoBackup(bool value) {
    setState(() {
      _isAutoBackupEnabled = value;
      if (value) {
        _scheduleAutoBackup();
      } else {
        _backupTimer?.cancel();
      }
    });
  }

  void _scheduleAutoBackup() {
    _backupTimer?.cancel();

    Duration interval;
    switch (_selectedBackupFrequency) {
      case 'Daily':
        interval = const Duration(days: 1);
        break;
      case 'Weekly':
        interval = const Duration(days: 7);
        break;
      case 'Monthly':
        interval = const Duration(days: 30);
        break;
      default:
        interval = const Duration(days: 1);
    }

    _backupTimer = Timer.periodic(interval, (timer) {
      _createFullBackup();
    });
  }

  Future<void> _showBackupPathInfo() async {
    try {
      final backupDir = await BackupService.getBackupDirectory(_customBackupPath);
      if (!mounted) return;
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Path Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current backup directory:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  backupDir.path,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Monthly folder structure is used for organization.'),
              Text('Current month: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting backup path: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: Colors.teal[700],
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Database Backup & Restore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Securely backup and restore your application database.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action Cards
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Single Row - Essential Actions Only
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionCard(
                          'Full DB Backup',
                          Icons.storage,
                          Colors.indigo[700]!,
                          _isBackingUp ? null : () => _createFullBackup(),
                          isLoading: _isBackingUp,
                        ),
                        _buildActionCard(
                          'Select Folder',
                          Icons.folder_open,
                          Colors.orange[700]!,
                          () => _selectBackupFolder(),
                        ),
                        _buildActionCard(
                          'Open Folder',
                          Icons.launch,
                          Colors.green[700]!,
                          () => _openBackupFolder(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Backup Settings
            Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Auto Backup Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto Backup',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Automatically backup your database',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isAutoBackupEnabled,
                            onChanged: _toggleAutoBackup,
                            activeColor: Colors.teal[700],
                          ),
                        ],
                      ),
                      
                      if (_isAutoBackupEnabled) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Backup Frequency',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedBackupFrequency,
                          items: _backupFrequencies.map((frequency) {
                            return DropdownMenuItem(
                              value: frequency,
                              child: Text(frequency),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBackupFrequency = value!;
                              _scheduleAutoBackup();
                            });
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Backup Location Info
                      if (_backupDirInfo != null) ...[
                        const Text(
                          'Backup Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.folder, color: Colors.teal[700]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _backupDirInfo!.path,
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: _backupDirInfo!.path));
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Path copied to clipboard')),
                                      );
                                    },
                                    tooltip: 'Copy path',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Files: ${_backupDirInfo!.fileCount}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'Size: ${_backupDirInfo!.formattedTotalSize}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'Last: ${_backupDirInfo!.formattedLastBackup}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Available Backups
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Colors.teal[700]),
                              const SizedBox(width: 12),
                              Text(
                                'Available Backups',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[900],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _refreshBackupInfo,
                                icon: _isLoadingBackups
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[700]!),
                                        ),
                                      )
                                    : Icon(Icons.refresh, color: Colors.teal[700]),
                                tooltip: 'Refresh',
                              ),
                              IconButton(
                                onPressed: _showBackupPathInfo,
                                icon: Icon(Icons.info_outline, color: Colors.teal[700]),
                                tooltip: 'Show backup path info',
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  await BackupService.cleanupOldBackups(
                                    keepCount: 5,
                                    customBackupPath: _customBackupPath,
                                  );
                                  await BackupService.cleanupEmptyMonthlyFolders(_customBackupPath);
                                  await BackupService.cleanupMetadataFolders(_customBackupPath);
                                  await _refreshBackupInfo();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Old backups, empty folders, and metadata cleaned up'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.cleaning_services, size: 18),
                                label: const Text('Cleanup'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.teal[700],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _cleanUserSessions,
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('Clear Sessions'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    if (_availableBackups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No backups found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 48,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                            columnSpacing: 24,
                            horizontalMargin: 24,
                            columns: [
                              DataColumn(
                                label: Text(
                                  'Backup Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Date Created',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Size',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Type',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Actions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ),
                            ],
                            rows: _availableBackups.map((backup) {
                              return DataRow(
                                selected: _selectedBackupForRestore == backup,
                                onSelectChanged: (selected) {
                                  setState(() {
                                    _selectedBackupForRestore = selected! ? backup : null;
                                  });
                                },
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(
                                        backup.fileName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(backup.formattedTimestamp)),
                                  DataCell(Text(backup.formattedSize)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: backup.type == BackupType.automatic
                                            ? Colors.blue[100]
                                            : Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        backup.type == BackupType.automatic ? 'Auto' : 'Manual',
                                        style: TextStyle(
                                          color: backup.type == BackupType.automatic
                                              ? Colors.blue[700]
                                              : Colors.green[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Tooltip(
                                          message: 'Restore from this backup',
                                          child: IconButton(
                                            icon: Icon(Icons.restore, color: Colors.teal[700]),
                                            onPressed: _isRestoring
                                                ? null
                                                : () => _restoreFromBackup(backup),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Delete this backup',
                                          child: IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red[700]),
                                            onPressed: () => _deleteBackup(backup),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap, {
    bool isLoading = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
