import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'modify_patient_details_screen.dart';
import 'modify_patient_status_screen.dart';
import 'modify_services_screen.dart';

// Log Entry Model
class LogEntry {
  final DateTime timestamp;
  final String type;
  final String description;

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.description,
  });
}

// Static Logging Service
class RecentUpdateLogService {
  static final List<LogEntry> _logEntries = [];
  static const int _maxLogs = 20; // Max number of logs to keep

  // Adds a log and ensures the list doesn't exceed maxLogs
  static void addLog(String type, String description) {
    if (_logEntries.length >= _maxLogs) {
      _logEntries.removeAt(0); // Remove the oldest log
    }
    _logEntries.add(LogEntry(
      timestamp: DateTime.now(),
      type: type,
      description: description,
    ));
  }

  // Returns a reversed list of logs (newest first)
  static List<LogEntry> getRecentLogs() {
    return List.unmodifiable(_logEntries.reversed);
  }

  // Clears all logs (e.g., for testing or reset)
  static void clearLogs() {
    _logEntries.clear();
  }
}

class UpdateScreen extends StatefulWidget {
  // Converted to StatefulWidget
  const UpdateScreen({super.key});

  @override
  UpdateScreenState createState() => UpdateScreenState();
}

class UpdateScreenState extends State<UpdateScreen> {
  List<LogEntry> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _recentLogs = RecentUpdateLogService.getRecentLogs();
    });
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (!mounted) return;
    _loadLogs(); // Refresh logs when returning from the modification screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // appBar: AppBar( // AppBar removed to use custom header like BackupScreen
      //   title: const Text('Update Data',
      //       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.teal[700],
      //   elevation: 0,
      //   iconTheme: const IconThemeData(color: Colors.white),
      // ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Changed for full-width header
          children: [
            // Custom Header like in BackupScreen
            Container(
              color: Colors.teal[700], // Header background color
              padding: const EdgeInsets.fromLTRB(20, 40, 20,
                  50), // Adjusted padding for a taller header + overlap space
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(height: 10), // Spacing after back button
                  const Text(
                    'Update Data', // Screen Title
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28, // Matches BackupScreen title
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Modify patient details, status, and services', // Screen Subtitle
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 16, // Matches BackupScreen subtitle
                    ),
                  ),
                ],
              ),
            ),
            // Action Cards Section with Transform.translate for overlap
            Transform.translate(
              offset: const Offset(0, -30), // Overlap effect
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20), // Horizontal padding for the row of cards
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceAround, // Distributes cards evenly
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildUpdateCard(
                        context,
                        title: 'Patient Details', // Shortened for card
                        icon: Icons.edit_note,
                        color: Colors.orange[700]!,
                        onTap: () {
                          _navigateAndRefresh(const ModifyPatientDetailsScreen());
                        },
                      ),
                    ),
                    const SizedBox(width: 15), // Spacing between cards
                    Expanded(
                      child: _buildUpdateCard(
                        context,
                        title: 'Patient Status', // Shortened for card
                        icon: Icons.person_search,
                        color: Colors.blue[700]!,
                        onTap: () {
                          _navigateAndRefresh(const ModifyPatientStatusScreen());
                        },
                      ),
                    ),
                    const SizedBox(width: 15), // Spacing between cards
                    Expanded(
                      child: _buildUpdateCard(
                        context,
                        title: 'Clinic Services', // Shortened for card
                        icon: Icons.medical_services_outlined,
                        color: Colors.green[700]!,
                        onTap: () {
                          _navigateAndRefresh(const ModifyServicesScreen());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildRecentUpdatesSection(), // Added recent updates section
          ],
        ),
      ),
    );
  }

  // Updated _buildUpdateCard to match BackupScreen's _buildActionCard style
  Widget _buildUpdateCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading =
        false, // Added for consistency, though not used in current UpdateScreen cards
  }) {
    return Card(
      elevation: 4, // Matches BackupScreen card elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap, // Disable tap if loading
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          // Explicit container for sizing if needed, or use Padding directly
          // width: 180, // Consider if fixed width is desired like in BackupScreen, or rely on Expanded
          padding: const EdgeInsets.all(20), // Adjusted padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content
            children: [
              if (isLoading)
                SizedBox(
                  width: 32, // Match icon size for loader
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 32, color: color), // Icon size
              const SizedBox(height: 12), // Space between icon and title
              Text(
                title,
                style: TextStyle(
                  fontSize: 15, // Adjusted font size
                  fontWeight: FontWeight.bold,
                  color: color, // Title color matches icon color
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget to build the recent updates section
  Widget _buildRecentUpdatesSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0).copyWith(
          top: 0), // Adjust top padding as it's below the overlapping cards
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recently Updated',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal[800],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _recentLogs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40.0, horizontal: 20.0),
                    child: Center(
                      child: Text(
                        'No recent updates to display.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable scrolling for the list itself
                    itemCount: _recentLogs.length,
                    itemBuilder: (context, index) {
                      final log = _recentLogs[index];
                      return ListTile(
                        leading: Icon(_getIconForLogType(log.type),
                            color: Colors.teal[600]),
                        title: Text(log.description,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '${log.type} - ${DateFormat('MMM d, yyyy hh:mm a').format(log.timestamp)}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        dense: true,
                      );
                    },
                    separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey[200]),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLogType(String type) {
    switch (type) {
      case 'Patient Detail':
        return Icons.person_outline;
      case 'Patient Status':
        return Icons.rule_folder_outlined;
      case 'Service':
        return Icons.medical_services_outlined;
      default:
        return Icons.update_outlined;
    }
  }
}
