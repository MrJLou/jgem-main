import 'package:flutter/material.dart';
import '../../services/queue_service.dart';
import '../../services/btree_queue_manager.dart';
import '../../models/active_patient_queue_item.dart';
import '../../models/appointment.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../models/patient.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'add_to_queue_screen.dart';

class _AppointmentDisplayItem {
  final Appointment appointment;
  final String patientName;
  final String doctorName;

  _AppointmentDisplayItem({
    required this.appointment,
    required this.patientName,
    required this.doctorName,
  });
}

class ViewQueueScreen extends StatefulWidget {
  final QueueService queueService;

  const ViewQueueScreen({super.key, required this.queueService});

  @override
  ViewQueueScreenState createState() => ViewQueueScreenState();

  // Static method to refresh B-Tree from external screens
  static void refreshBTreeIfExists() {
    // This can be called from other screens when new patients are added
    final BTreeQueueManager queueManager = BTreeQueueManager();
    if (queueManager.isInitialized) {
      queueManager.refresh().catchError((e) {
        debugPrint('Error refreshing B-Tree from external call: $e');
      });
    }
  }
}

class ViewQueueScreenState extends State<ViewQueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BTreeQueueManager _queueManager;

  // State for Scheduled Appointments Tab
  late Future<List<_AppointmentDisplayItem>> _appointmentItemsFuture;
  DateTime _selectedAppointmentDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _isLoadingAppointments = false;

  // State for Live Queue Tab
  bool _isLoadingLiveQueue = false;
  late Future<List<ActivePatientQueueItem>> _liveQueueFuture;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  // Debug state for performance monitoring
  bool _showPerformanceMetrics = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _queueManager = BTreeQueueManager();
    _initializeQueueManager();
    _appointmentItemsFuture =
        _prepareAppointmentDisplayItems(_selectedAppointmentDate);
    _loadLiveQueue();
    // Initialize the cache for the current month
    _initializeCache();
    
    // Setup search listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (mounted) {
      setState(() {
        // This setState call will trigger a rebuild, allowing conditional UI
        // in the AppBar (like the calendar icon) to update based on the
        // current _tabController.index.
      });
      if (_tabController.index == 1 && _monthAppointments.isEmpty) {
        _cacheAppointmentsForMonth(_focusedDay);
      }
    }
  }

  void _loadAppointmentsForSelectedDate() {
    setState(() {
      _isLoadingAppointments = true;
      _appointmentItemsFuture =
          _prepareAppointmentDisplayItems(_selectedAppointmentDate);
      _appointmentItemsFuture.whenComplete(() {
        if (mounted) {
          setState(() {
            _isLoadingAppointments = false;
          });
        }
      });
    });
  }

  void _loadLiveQueue() {
    setState(() {
      _isLoadingLiveQueue = true;
    });
    
    if (_queueManager.isInitialized) {
      // Use B-Tree for faster loading if initialized
      _liveQueueFuture = Future.value(_queueManager.getFilteredItems(
        statuses: ['waiting', 'in_consultation', 'served', 'removed'],
        todayOnly: true,
        prioritySort: true,
      ));
    } else {
      // Fallback to database query
      _liveQueueFuture = widget.queueService.getActiveQueueItems(
          statuses: ['waiting', 'in_consultation', 'served', 'removed']);
    }
    
    _liveQueueFuture.whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoadingLiveQueue = false;
        });
      }
    });
  }

  void _refreshCurrentTabData() {
    if (_tabController.index == 0) {
      // Refresh B-Tree data if initialized
      if (_queueManager.isInitialized) {
        _queueManager.refresh().then((_) {
          _loadLiveQueue();
        }).catchError((e) {
          debugPrint('Error refreshing B-Tree: $e');
          _loadLiveQueue(); // Fallback to normal loading
        });
      } else {
        _loadLiveQueue();
      }
    } else {
      _loadAppointmentsForSelectedDate();
    }
  }

  Future<void> _updateAppointmentStatus(
      Appointment appointment, String newStatus) async {
    if (!mounted) return;
    setState(() => _isLoadingAppointments = true);
    try {
      await ApiService.updateAppointmentStatus(appointment.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Appointment for ${appointment.patientId} status updated to $newStatus."),
            backgroundColor: Colors.green,
          ),
        );
        _loadAppointmentsForSelectedDate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating appointment status: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAppointments = false);
      }
    }
  }

  Future<void> _updateLiveQueueItemStatus(
      ActivePatientQueueItem item, String newStatus) async {
    if (!mounted) return;
    setState(() => _isLoadingLiveQueue = true);
    try {
      bool success;
      
      // Use B-Tree queue manager if initialized, otherwise fallback to direct service
      if (_queueManager.isInitialized) {
        success = await _queueManager.updatePatientStatus(item.queueEntryId, newStatus);
      } else {
        success = await widget.queueService.updatePatientStatusInQueue(item.queueEntryId, newStatus);
      }
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text("${item.patientName}'s status updated to ${_getDisplayStatus(newStatus)}."),
              backgroundColor: Colors.green,
            ),
          );
          _loadLiveQueue();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status for ${item.patientName}.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating live queue status: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLiveQueue = false);
      }
    }
  }

  // Add a method to cache appointments for the visible month
  final Map<DateTime, List<Appointment>> _monthAppointments = {};

  Future<void> _cacheAppointmentsForMonth(DateTime month) async {
    try {
      setState(() => _isLoadingAppointments = true);
      
      // Get the first and last day of the month
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      // Clear existing cache for this month
      _monthAppointments.removeWhere((key, value) =>
        key.year == month.year && key.month == month.month
      );

      // Fetch appointments for the whole month
      final appointments = await ApiService.getAppointmentsForRange(firstDay, lastDay);
      
      // Filter and group appointments by date
      for (var appointment in appointments) {
        final date = DateTime(
          appointment.date.year,
          appointment.date.month,
          appointment.date.day,
        );
        
        if (!_monthAppointments.containsKey(date)) {
          _monthAppointments[date] = [];
        }
        _monthAppointments[date]!.add(appointment);
      }

      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      debugPrint('Error caching appointments: $e');
      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
        });
      }
    }
  }

  Future<void> _initializeCache() async {
    await _cacheAppointmentsForMonth(_focusedDay);
  }

  // Initialize the B-Tree queue manager
  Future<void> _initializeQueueManager() async {
    try {
      await _queueManager.initialize(widget.queueService);
      debugPrint('B-Tree Queue Manager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing B-Tree Queue Manager: $e');
    }
  }

  // Handle search input changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  // Get filtered and searched queue items using B-Tree
  List<ActivePatientQueueItem> _getFilteredQueueItems(List<ActivePatientQueueItem> items) {
    if (!_queueManager.isInitialized) {
      return items;
    }

    // Start with filtered items from B-Tree
    List<ActivePatientQueueItem> filteredItems = _queueManager.getFilteredItems(
      statuses: _selectedStatusFilter == 'all' ? null : [_selectedStatusFilter],
      todayOnly: true,
      prioritySort: true,
    );

    // Apply search if query is not empty
    if (_searchQuery.isNotEmpty) {
      // Try different search methods
      List<ActivePatientQueueItem> searchResults = [];
      
      // Search by name
      searchResults.addAll(_queueManager.searchByName(_searchQuery));
      
      // Search by patient ID
      searchResults.addAll(_queueManager.searchByPatientId(_searchQuery));
      
      // Search by queue number if query is numeric
      if (int.tryParse(_searchQuery) != null) {
        int queueNumber = int.parse(_searchQuery);
        ActivePatientQueueItem? item = _queueManager.searchByQueueNumber(queueNumber);
        if (item != null) {
          searchResults.add(item);
        }
      }
      
      // Remove duplicates and filter by status if needed
      Set<String> seen = {};
      filteredItems = searchResults.where((item) {
        if (seen.contains(item.queueEntryId)) return false;
        seen.add(item.queueEntryId);
         // Apply status filter if not 'all'
        if (_selectedStatusFilter != 'all' && item.status != _selectedStatusFilter) {
          return false;
        }
        
        // Always filter for today only in Live Queue
        DateTime today = DateTime.now();
        return item.arrivalTime.year == today.year &&
               item.arrivalTime.month == today.month &&
               item.arrivalTime.day == today.day;
      }).toList();
    }

    return filteredItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Patient Queue & Appointments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        actions: [
          // Debug menu for B-Tree performance
          if (_queueManager.isInitialized)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'performance':
                    setState(() {
                      _showPerformanceMetrics = !_showPerformanceMetrics;
                    });
                    break;
                  case 'validate':
                    _validateBTreeConsistency();
                    break;
                  case 'export':
                    _exportBTreeStructure();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'performance',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(_showPerformanceMetrics ? 'Hide Metrics' : 'Show Metrics'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'validate',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Validate B-Tree'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Export Structure'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            onPressed: _refreshCurrentTabData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Current View',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Live Queue (Today)'),
            Tab(text: 'Scheduled Appointments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveQueueTab(),
          _buildScheduledAppointmentsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddToQueueScreen(queueService: widget.queueService),
            ),
          ).then((_) {
            // Refresh data when returning from add screen
            _refreshCurrentTabData();
          });
        },
        backgroundColor: Colors.teal[700],
        tooltip: 'Add Patient to Queue',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildLiveQueueTab() {
    return Column(
      children: [
        // Search and Filter UI
        _buildSearchAndFilterBar(),
        // Performance Metrics (if enabled)
        _buildPerformanceMetrics(),
        // Queue Content
        Expanded(
          child: FutureBuilder<List<ActivePatientQueueItem>>(
            future: _liveQueueFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || _isLoadingLiveQueue) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading live queue: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyListMessage('live queue items');
              }
              
              final queue = snapshot.data!;
              
              // Use B-Tree filtering if available, otherwise use traditional filtering
              List<ActivePatientQueueItem> filteredQueue;
              if (_queueManager.isInitialized && (_searchQuery.isNotEmpty || _selectedStatusFilter != 'all')) {
                filteredQueue = _getFilteredQueueItems(queue);
              } else {
                // Traditional filtering for backward compatibility
                filteredQueue = queue.where((item) {
                  bool isActive = item.status == 'waiting' || item.status == 'in_consultation';
                  bool isFinalizedWalkIn = (item.status == 'served' || item.status == 'removed') &&
                                           (item.originalAppointmentId == null || item.originalAppointmentId!.isEmpty);
                  bool statusMatch = _selectedStatusFilter == 'all' || item.status == _selectedStatusFilter;
                  bool todayMatch = _isToday(item.arrivalTime);
                  
                  return (isActive || isFinalizedWalkIn) && statusMatch && todayMatch;
                }).toList();
                
                // Sort traditionally if B-Tree is not used for filtering
                filteredQueue.sort((a, b) {
                  if (a.status == 'in_consultation' && b.status != 'in_consultation') return -1;
                  if (a.status != 'in_consultation' && b.status == 'in_consultation') return 1;
                  if (a.queueNumber != 0 && b.queueNumber != 0) {
                    return a.queueNumber.compareTo(b.queueNumber);
                  }
                  return a.arrivalTime.compareTo(b.arrivalTime);
                });
              }

              if (filteredQueue.isEmpty) {
                return _buildEmptyListMessage('matching queue items');
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildLiveQueueTableHeader(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredQueue.length,
                        itemBuilder: (context, index) {
                          return _buildLiveQueueTableRow(filteredQueue[index]);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Performance metrics widget (debug mode)
        _buildPerformanceMetrics(),
      ],
    );
  }

  // Build search and filter bar for live queue
  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, patient ID, or queue number...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          // Filter row
          Row(
            children: [
              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status Filter',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'waiting', child: Text('Waiting')),
                    DropdownMenuItem(value: 'in_consultation', child: Text('In Consultation')),
                    DropdownMenuItem(value: 'served', child: Text('Served')),
                    DropdownMenuItem(value: 'removed', child: Text('Removed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value ?? 'all';
                    });
                  },
                ),
              ),

            ],
          ),
          // Queue statistics (if B-Tree is initialized)
          if (_queueManager.isInitialized) _buildQueueStatistics(),
        ],
      ),
    );
  }

  // Build queue statistics widget
  Widget _buildQueueStatistics() {
    Map<String, int> stats = _queueManager.getStatistics();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Waiting', stats['waiting'] ?? 0, Colors.orange),
          _buildStatChip('In Consultation', stats['in_consultation'] ?? 0, Colors.blue),
          _buildStatChip('Served', stats['served'] ?? 0, Colors.green),
          _buildStatChip('Total', stats['total'] ?? 0, Colors.grey),
        ],
      ),
    );
  }

  // Build individual stat chip
  Widget _buildStatChip(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(30)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Debug build performance metrics widget
  Widget _buildPerformanceMetrics() {
    if (!_queueManager.isInitialized || !_showPerformanceMetrics) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic> metrics = _queueManager.getPerformanceMetrics();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue[700], size: 16),
              const SizedBox(width: 8),
              Text(
                'B-Tree Performance Metrics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _showPerformanceMetrics = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricItem('Queue Size', metrics['totalPatients']?.toString() ?? '0'),
              _buildMetricItem('Waiting', metrics['waitingPatients']?.toString() ?? '0'),
              _buildMetricItem('In Consultation', metrics['inConsultation']?.toString() ?? '0'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildMetricItem('Avg Wait (min)', metrics['averageWaitTimeMinutes']?.toStringAsFixed(1) ?? '0.0'),
              _buildMetricItem('Served Today', metrics['servedPatients']?.toString() ?? '0'),
              _buildMetricItem('Active Consultations', metrics['activeConsultations']?.toString() ?? '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Debug method to validate B-Tree consistency
  void _validateBTreeConsistency() async {
    if (!_queueManager.isInitialized) return;
    
    try {
      bool isConsistent = await _queueManager.validateConsistency();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConsistent 
                ? 'B-Tree is consistent with database' 
                : 'B-Tree inconsistency detected!',
            ),
            backgroundColor: isConsistent ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating B-Tree: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Debug method to export B-Tree structure
  void _exportBTreeStructure() {
    if (!_queueManager.isInitialized) return;
    
    try {
      Map<String, dynamic> structure = _queueManager.exportTreeStructure();
      debugPrint('B-Tree Structure: ${structure.toString()}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('B-Tree structure exported to debug console'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting B-Tree structure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ...existing code...

  // Helper method to check if a date is today
  bool _isToday(DateTime date) {
    DateTime today = DateTime.now();
    return date.year == today.year &&
           date.month == today.month &&
           date.day == today.day;
  }

  Widget _buildLiveQueueTableHeader() {
    final headers = [
      'No.', 'Name (ID)', 'Arrival', 'Gender', 'Age', 'Purpose/Notes', 'Status & Actions'
    ];
    return Container(
      color: Colors.blue[700],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: headers.map((text) {
          int flex = 1;
          if (text == 'Name (ID)' || text == 'Purpose/Notes') flex = 2;
          if (text == 'Status & Actions') flex = 2;
          return Expanded(
            flex: flex,
            child: TableCellWidget(
              text: text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLiveQueueTableRow(ActivePatientQueueItem item) {
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';
    final bool isFromAppointment = item.originalAppointmentId != null && item.originalAppointmentId!.isNotEmpty;

    final dataCells = [
      item.queueNumber.toString(),
      '${item.patientName} (${Patient.formatId(item.patientId ?? "000000")})',
      arrivalDisplayTime,
      item.gender ?? 'N/A',
      item.age?.toString() ?? 'N/A',
      item.conditionOrPurpose ?? 'N/A',
    ];

    Color rowColor = isFromAppointment ? Colors.indigo[50]! : Colors.white;
    Color textColor = isFromAppointment ? Colors.indigo[800]! : Colors.black87;
    if (item.status == 'removed') {
      rowColor = Colors.grey.shade200;
      textColor = Colors.grey.shade600;
    } else if (item.status == 'served') {
      rowColor = Colors.lightGreen[50]!;
      textColor = Colors.green[800]!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: rowColor,
        border: Border.all(color: isFromAppointment ? Colors.indigo[200]! : Colors.grey.shade300, width: isFromAppointment ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex = (idx == 1 || idx == 5) ? 2 : 1;
            return Expanded(
              flex: flex,
              child: TableCellWidget(
                text: text,
                style: cellStyle.copyWith(color: textColor, fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal),
              ),
            );
          }),
          Expanded(
            flex: 2,
            child: TableCellWidget(child: _buildLiveQueueStatusActionsWidget(item)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveQueueStatusActionsWidget(ActivePatientQueueItem item) {
    if (item.status == 'removed') {
      return _buildStatusChip('Removed', Colors.red.shade100, Colors.red.shade700);
    }
    if (item.status == 'served') {
      return _buildStatusChip('Served', Colors.green.shade100, Colors.green.shade700);
    }

    List<String> possibleStatuses = [];
    if (item.status == 'waiting') {
      possibleStatuses = ['in_consultation', 'served', 'removed'];
    } else if (item.status == 'in_consultation') {
      possibleStatuses = ['waiting', 'served', 'removed'];
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_getDisplayStatus(item.status), style: TextStyle(fontWeight: FontWeight.bold, color: _getLiveQueueStatusColor(item.status))),
        if (possibleStatuses.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: "Change Status",
            icon: Icon(Icons.edit, size: 20, color: Colors.teal[600]),
            onSelected: (String newStatus) => _updateLiveQueueItemStatus(item, newStatus),
            itemBuilder: (BuildContext context) {
              return possibleStatuses.map((String statusValue) {
                return PopupMenuItem<String>(value: statusValue, child: Text(_getDisplayStatus(statusValue)));
              }).toList();
            },
          ),
      ],
    );
  }

  Widget _buildScheduledAppointmentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildInlineCalendar(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _buildAppointmentsListForSelectedDate(),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2010, 10, 16),
      lastDay: DateTime.utc(2030, 3, 14),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedAppointmentDate, day),
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      eventLoader: (day) {
        final date = DateTime(day.year, day.month, day.day);
        return _monthAppointments[date] ?? [];
      },
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: Colors.teal[700],
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.teal.withAlpha(100),
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Colors.red[600],
          shape: BoxShape.circle,
        ),
        markersMaxCount: 1,
      ),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedAppointmentDate, selectedDay)) {
          setState(() {
            _selectedAppointmentDate = selectedDay;
            _focusedDay = focusedDay;
            _loadAppointmentsForSelectedDate();
          });
        }
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _cacheAppointmentsForMonth(focusedDay).then((_) {
          if (mounted) setState(() {});
        });
      },
    );
  }

  Widget _buildAppointmentsListForSelectedDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            "Appointments for: ${DateFormat.yMMMMd().format(_selectedAppointmentDate)}",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal[700],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_AppointmentDisplayItem>>(
            future: _appointmentItemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _isLoadingAppointments) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading appointments: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyListMessage(
                    'appointments for ${DateFormat.yMMMMd().format(_selectedAppointmentDate)}');
              }
              final appointments = snapshot.data!;
              appointments.sort((a, b) {
                final aTime = a.appointment.time.hour * 60 + a.appointment.time.minute;
                final bTime = b.appointment.time.hour * 60 + b.appointment.time.minute;
                return aTime.compareTo(bTime);
              });

              return Column(
                children: [
                  _buildAppointmentTableHeader(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        return _buildAppointmentTableRow(appointments[index]);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyListMessage(String itemType) { 
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(itemType.contains('appointments') ? Icons.event_busy : Icons.queue, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'No $itemType scheduled/found.', 
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              itemType.contains('appointments') 
                ? 'Appointments will appear here when scheduled for the selected date.'
                : 'Items will appear here when added to the live queue.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentTableHeader() { 
    final headers = [
      'Time',
      'Patient Name',
      'Doctor Name',
      'Type',
      'Status & Actions'
    ];
    return Container(
      color: Colors.teal[700],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: headers.map((text) {
          return Expanded(
              flex: (text == 'Patient Name' || text == 'Doctor Name' || text == 'Status & Actions')
                  ? 2
                  : (text == 'Type' ? 3 : 1),
              child: TableCellWidget(
                text: text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ));
        }).toList(),
      ),
    );
  }

  Widget _buildAppointmentTableRow(_AppointmentDisplayItem displayItem) {
    final appointment = displayItem.appointment;
    final patientName = displayItem.patientName;
    final doctorName = displayItem.doctorName;

    final timeDisplay = appointment.time.format(context);
    final dataCells = [
      timeDisplay,
      '$patientName (${Patient.formatId(appointment.patientId)})',
      '$doctorName (${User.formatId(appointment.doctorId)})',
      appointment.consultationType,
    ];
    Color rowColor = Colors.white;
    Color textColor = Colors.black87;
    switch (appointment.status.toLowerCase()) {
      case 'scheduled':
      case 'confirmed':
        rowColor = Colors.blue[50]!;
        textColor = Colors.blue[800]!;
        break;
      case 'in consultation':
        rowColor = Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        break;
      case 'completed':
      case 'served':
        rowColor = Colors.green[50]!;
        textColor = Colors.green[800]!;
        break;
      case 'cancelled':
        rowColor = Colors.red[50]!;
        textColor = Colors.red[800]!;
        break;
      default:
        rowColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: rowColor,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex = (idx == 1 || idx == 2) ? 2 : (idx == 3 ? 3 : 1);
            return Expanded(
                flex: flex,
                child: TableCellWidget(
                  text: text,
                  style: cellStyle.copyWith(color: textColor),
                ));
          }),
          Expanded(
            flex: 2,
            child: TableCellWidget(
                child: _buildAppointmentStatusActionsWidget(appointment)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStatusActionsWidget(Appointment appointment) {
    if (appointment.status.toLowerCase() == 'cancelled') {
      return _buildStatusChip('Cancelled', Colors.red.shade100, Colors.red.shade700);
    }
    if (appointment.status.toLowerCase() == 'completed' || appointment.status.toLowerCase() == 'served') {
      return _buildStatusChip('Completed', Colors.green.shade100, Colors.green.shade700);
    }
    List<String> possibleStatuses = [
      'Scheduled', 'Confirmed', 'In Consultation', 'Completed', 'Cancelled'
    ];
    String currentDisplayStatus = _getDisplayAppointmentStatus(appointment.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(currentDisplayStatus, style: TextStyle(fontWeight: FontWeight.bold, color: _getAppointmentStatusColor(appointment.status))),
        const SizedBox(width: 8), 
        if (appointment.status.toLowerCase() != 'cancelled' && appointment.status.toLowerCase() != 'completed' && appointment.status.toLowerCase() != 'served')
          PopupMenuButton<String>(
            tooltip: "Change Status",
            icon: Icon(Icons.edit, size: 20, color: Colors.teal[600]),
            onSelected: (String newStatusChoice) {
              String actualNewStatus = newStatusChoice;
              if (newStatusChoice == 'Completed') actualNewStatus = 'Completed'; 
              _updateAppointmentStatus(appointment, actualNewStatus);
            },
            itemBuilder: (BuildContext context) {
              return possibleStatuses.where((statusValue) {
                if (appointment.status.toLowerCase() == 'scheduled' && statusValue == 'Scheduled') return false;
                if (appointment.status.toLowerCase() == 'confirmed' && statusValue == 'Confirmed') return false;
                if (appointment.status.toLowerCase() == 'in consultation' && statusValue == 'In Consultation') return false;
                return true;
              }).map((String statusValue) {
                return PopupMenuItem<String>(value: statusValue, child: Text(_getDisplayAppointmentStatus(statusValue)));
              }).toList();
            },
          ),
      ],
    );
  }

  Widget _buildStatusChip(String text, Color bgColor, Color textColor) { 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
  
  String _getDisplayStatus(String status) { 
    switch (status.toLowerCase()) {
      case 'waiting': return 'Waiting';
      case 'in_consultation': return 'In Consult';
      case 'served': return 'Served';
      case 'removed': return 'Removed';
      default: return status;
    }
  }

  String _getDisplayAppointmentStatus(String status) { 
    switch (status.toLowerCase()) {
      case 'scheduled': return 'Scheduled';
      case 'confirmed': return 'Confirmed';
      case 'in consultation': return 'In Consult';
      case 'completed': return 'Completed';
      case 'served': return 'Served'; 
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Color _getLiveQueueStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting': return Colors.orange.shade700;
      case 'in_consultation': return Colors.blue.shade700;
      case 'served': return Colors.green.shade700;
      case 'removed': return Colors.red.shade700;
      default: return Colors.grey.shade700;
    }
  }

  Color _getAppointmentStatusColor(String status) { 
    switch (status.toLowerCase()) {
      case 'scheduled': return Colors.blueGrey.shade700;
      case 'confirmed': return Colors.blue.shade700;
      case 'in consultation': return Colors.orange.shade800;
      case 'completed':
      case 'served':
        return Colors.green.shade700;
      case 'cancelled': return Colors.red.shade700;
      default: return Colors.grey.shade700;
    }
  }

  TextStyle cellStyle = const TextStyle(fontSize: 14, color: Colors.black87); 

  Future<List<_AppointmentDisplayItem>> _prepareAppointmentDisplayItems(
      DateTime date) async {
    final appointments = await ApiService.getAppointments(date);
    final List<_AppointmentDisplayItem> displayItems = [];
    for (var appt in appointments) {
      final patient = await ApiService.getPatientById(appt.patientId);
      final doctor = await ApiService.getUserById(appt.doctorId);
      displayItems.add(_AppointmentDisplayItem(
        appointment: appt,
        patientName: patient.fullName,
        doctorName: doctor?.fullName ?? 'Unknown Doctor',
      ));
    }
    return displayItems;
  }

  // Method to add patient through B-Tree manager
  Future<bool> addPatientThroughBTree(ActivePatientQueueItem patient) async {
    try {
      if (_queueManager.isInitialized) {
        await _queueManager.addPatient(patient);
        _loadLiveQueue(); // Refresh the UI
        return true;
      } else {
        // Fallback to regular queue service
        bool success = await widget.queueService.addPatientToQueue(patient);
        _loadLiveQueue(); // Refresh the UI
        return success;
      }
    } catch (e) {
      debugPrint('Error adding patient through B-Tree: $e');
      return false;
    }
  }
}

class TableCellWidget extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final Widget? child;

  const TableCellWidget({
    super.key,
    this.text,
    this.style,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: Center(
        child: child ??
            Text(
              text ?? '',
              style: style,
              textAlign: TextAlign.center, 
              overflow: TextOverflow.ellipsis, 
            ),
      ),
    );
  }
}
