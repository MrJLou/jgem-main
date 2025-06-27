// Enhanced Queue Manager Service with B-Tree integration
import 'package:flutter/foundation.dart';
import '../models/active_patient_queue_item.dart';
import '../models/btree_patient_queue.dart';
import '../services/queue_service.dart';
// Enhanced real-time sync service import removed - using ShelfLanServer integration

class BTreeQueueManager {
  static final BTreeQueueManager _instance = BTreeQueueManager._internal();
  factory BTreeQueueManager() => _instance;
  BTreeQueueManager._internal();

  late BTreePatientQueue _bTreeQueue;
  late QueueService _queueService;
  bool _isInitialized = false;

  // Initialize the B-Tree queue manager
  Future<void> initialize(QueueService queueService) async {
    if (_isInitialized) return;

    _queueService = queueService;
    _bTreeQueue = BTreePatientQueue();

    try {
      // Load existing queue items into B-Tree
      await _loadExistingQueueItems();

      // Register with real-time sync service for queue updates
      // RealTimeSyncService callback registration deprecated - using ShelfLanServer now
      // EnhancedRealTimeSyncService.registerQueueUpdateCallback(handleSyncUpdate);

      _isInitialized = true;
      debugPrint(
          'BTreeQueueManager: Initialized successfully with ${_bTreeQueue.size} items');
    } catch (e) {
      debugPrint('BTreeQueueManager: Error during initialization: $e');
      rethrow;
    }
  }

  // Load existing queue items from database into B-Tree
  Future<void> _loadExistingQueueItems() async {
    try {
      List<ActivePatientQueueItem> existingItems =
          await _queueService.getActiveQueueItems();
      if (existingItems.isNotEmpty) {
        _bTreeQueue.buildFromList(existingItems);
        debugPrint(
            'BTreeQueueManager: Loaded ${existingItems.length} existing queue items');
      }
    } catch (e) {
      debugPrint('BTreeQueueManager: Error loading existing items: $e');
      throw Exception('Failed to load existing queue items: $e');
    }
  }

  // Ensure the manager is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
          'BTreeQueueManager not initialized. Call initialize() first.');
    }
  }

  // Handle real-time sync updates from other devices
  Future<void> handleSyncUpdate(
      String operation, Map<String, dynamic> data) async {
    _ensureInitialized();

    try {
      switch (operation.toLowerCase()) {
        case 'queue_added':
          await _handleSyncQueueAdded(data);
          break;
        case 'queue_updated':
          await _handleSyncQueueUpdated(data);
          break;
        case 'queue_removed':
          await _handleSyncQueueRemoved(data);
          break;
        default:
          debugPrint('BTreeQueueManager: Unknown sync operation: $operation');
      }
    } catch (e) {
      debugPrint('BTreeQueueManager: Error handling sync update: $e');
      // Don't rethrow - sync failures shouldn't break the app
    }
  }

  // Handle queue item added from sync
  Future<void> _handleSyncQueueAdded(Map<String, dynamic> data) async {
    try {
      final item = ActivePatientQueueItem.fromJson(data);

      // Check if item already exists (to avoid duplicates)
      final existing = _bTreeQueue.searchByQueueNumber(item.queueNumber);
      if (existing == null) {
        _bTreeQueue.insert(item);
        debugPrint(
            'BTreeQueueManager: Added synced queue item ${item.patientName}');
      } else {
        debugPrint(
            'BTreeQueueManager: Queue item ${item.patientName} already exists, skipping add');
      }
    } catch (e) {
      debugPrint('BTreeQueueManager: Error handling sync queue add: $e');
    }
  }

  // Handle queue item updated from sync
  Future<void> _handleSyncQueueUpdated(Map<String, dynamic> data) async {
    try {
      final item = ActivePatientQueueItem.fromJson(data);

      // Update in B-Tree
      _bTreeQueue.update(item);
      debugPrint(
          'BTreeQueueManager: Updated synced queue item ${item.patientName}');
    } catch (e) {
      debugPrint('BTreeQueueManager: Error handling sync queue update: $e');
    }
  }

  // Handle queue item removed from sync
  Future<void> _handleSyncQueueRemoved(Map<String, dynamic> data) async {
    try {
      final item = ActivePatientQueueItem.fromJson(data);

      // Remove from B-Tree
      _bTreeQueue.remove(item.queueNumber);
      debugPrint(
          'BTreeQueueManager: Removed synced queue item ${item.patientName}');
    } catch (e) {
      debugPrint('BTreeQueueManager: Error handling sync queue remove: $e');
    }
  }

  // Add a new patient to the queue
  Future<ActivePatientQueueItem> addPatient(
      ActivePatientQueueItem patient) async {
    _ensureInitialized();

    try {
      // Add to database first
      ActivePatientQueueItem addedPatient =
          await _queueService.addPatientDataToQueue({
        'patientId': patient.patientId,
        'patientName': patient.patientName,
        'arrivalTime': patient.arrivalTime.toIso8601String(),
        'status': patient.status,
        'queueNumber': patient.queueNumber,
        'originalAppointmentId': patient.originalAppointmentId,
        'doctorId': patient.doctorId,
        'doctorName': patient.doctorName,
      });

      // Then add to B-Tree
      _bTreeQueue.insert(addedPatient);

      debugPrint(
          'BTreeQueueManager: Added patient ${addedPatient.patientName} to queue');
      return addedPatient;
    } catch (e) {
      debugPrint('BTreeQueueManager: Error adding patient: $e');
      rethrow;
    }
  }

  // Remove a patient from the queue
  Future<bool> removePatient(String queueEntryId) async {
    _ensureInitialized();

    try {
      // Find the patient first
      ActivePatientQueueItem? patient =
          await _queueService.getQueueItem(queueEntryId);
      if (patient == null) return false;
      // Remove from database
      bool removed = await _queueService.removeFromQueue(queueEntryId);

      if (removed) {
        // Remove from B-Tree
        _bTreeQueue.remove(patient.queueNumber);
        debugPrint(
            'BTreeQueueManager: Removed patient ${patient.patientName} from queue');
      }

      return removed;
    } catch (e) {
      debugPrint('BTreeQueueManager: Error removing patient: $e');
      return false;
    }
  }

  // Update patient status
  Future<bool> updatePatientStatus(
      String queueEntryId, String newStatus) async {
    _ensureInitialized();

    try {
      // Update in database first
      bool updated = await _queueService.updatePatientStatusInQueue(
          queueEntryId, newStatus);

      if (updated) {
        // Get updated patient data
        ActivePatientQueueItem? updatedPatient =
            await _queueService.getQueueItem(queueEntryId);
        if (updatedPatient != null) {
          // Update in B-Tree
          _bTreeQueue.update(updatedPatient);
          debugPrint(
              'BTreeQueueManager: Updated patient ${updatedPatient.patientName} status to $newStatus');
        }
      }

      return updated;
    } catch (e) {
      debugPrint('BTreeQueueManager: Error updating patient status: $e');
      return false;
    }
  }

  // Search patients by queue number
  ActivePatientQueueItem? searchByQueueNumber(int queueNumber) {
    _ensureInitialized();
    return _bTreeQueue.searchByQueueNumber(queueNumber);
  }

  // Search patients by name
  List<ActivePatientQueueItem> searchByName(String name) {
    _ensureInitialized();
    return _bTreeQueue.searchByName(name);
  }

  // Search patients by status
  List<ActivePatientQueueItem> searchByStatus(String status) {
    _ensureInitialized();
    return _bTreeQueue.searchByStatus(status);
  }

  // Search patients by patient ID
  List<ActivePatientQueueItem> searchByPatientId(String patientId) {
    _ensureInitialized();
    return _bTreeQueue.searchByPatientId(patientId);
  }

  // Advanced search with multiple criteria
  List<ActivePatientQueueItem> advancedSearch({
    String? name,
    String? patientId,
    String? status,
    DateTime? arrivalDate,
    String? doctorName,
  }) {
    _ensureInitialized();
    return _bTreeQueue.advancedSearch(
      name: name,
      patientId: patientId,
      status: status,
      arrivalDate: arrivalDate,
      doctorName: doctorName,
    );
  }

  // Get all queue items
  List<ActivePatientQueueItem> getAllItems() {
    _ensureInitialized();
    return _bTreeQueue.getAllItems();
  }

  // Get items sorted by priority
  List<ActivePatientQueueItem> getItemsByPriority() {
    _ensureInitialized();
    return _bTreeQueue.getItemsByPriority();
  }

  // Get today's queue items
  List<ActivePatientQueueItem> getTodayItems() {
    _ensureInitialized();
    return _bTreeQueue.getTodayItems();
  }

  // Get filtered items for display
  List<ActivePatientQueueItem> getFilteredItems({
    List<String>? statuses,
    bool todayOnly = false,
    bool prioritySort = true,
  }) {
    _ensureInitialized();

    List<ActivePatientQueueItem> items =
        todayOnly ? getTodayItems() : getAllItems();

    // Filter by status if specified
    if (statuses != null && statuses.isNotEmpty) {
      items = items.where((item) => statuses.contains(item.status)).toList();
    }

    // Sort by priority if requested
    if (prioritySort) {
      items = _sortItemsByPriority(items);
    }

    return items;
  }

  // Sort items by priority (used internally)
  List<ActivePatientQueueItem> _sortItemsByPriority(
      List<ActivePatientQueueItem> items) {
    items.sort((a, b) {
      // Priority order: in_consultation > waiting > served > removed
      int statusPriorityA = _getStatusPriority(a.status);
      int statusPriorityB = _getStatusPriority(b.status);

      if (statusPriorityA != statusPriorityB) {
        return statusPriorityA.compareTo(statusPriorityB);
      }

      // For same status, sort by queue number
      if (a.queueNumber != 0 && b.queueNumber != 0) {
        return a.queueNumber.compareTo(b.queueNumber);
      }

      // Fallback to arrival time
      return a.arrivalTime.compareTo(b.arrivalTime);
    });

    return items;
  }

  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'in_consultation':
        return 1;
      case 'waiting':
        return 2;
      case 'served':
        return 3;
      case 'removed':
        return 4;
      default:
        return 5;
    }
  }

  // Get queue statistics
  Map<String, int> getStatistics() {
    _ensureInitialized();
    return _bTreeQueue.getStatistics();
  }

  // Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    _ensureInitialized();
    return _bTreeQueue.getPerformanceMetrics();
  }

  // Get next patient in queue
  ActivePatientQueueItem? getNextPatient() {
    _ensureInitialized();
    return _bTreeQueue.getNextPatient();
  }

  // Get current consultations
  List<ActivePatientQueueItem> getCurrentConsultations() {
    _ensureInitialized();
    return _bTreeQueue.getCurrentConsultations();
  }

  // Get waiting patients count
  int getWaitingCount() {
    _ensureInitialized();
    return _bTreeQueue.getWaitingCount();
  }

  // Get in consultation count
  int getInConsultationCount() {
    _ensureInitialized();
    return _bTreeQueue.getInConsultationCount();
  }

  // Refresh the B-Tree with latest database data
  Future<void> refresh() async {
    _ensureInitialized();

    try {
      debugPrint('BTreeQueueManager: Refreshing queue data...');
      await _loadExistingQueueItems();
      debugPrint('BTreeQueueManager: Queue data refreshed successfully');
    } catch (e) {
      debugPrint('BTreeQueueManager: Error refreshing queue data: $e');
      rethrow;
    }
  }

  // Validate B-Tree consistency with database
  Future<bool> validateConsistency() async {
    _ensureInitialized();

    try {
      List<ActivePatientQueueItem> dbItems =
          await _queueService.getActiveQueueItems();
      List<ActivePatientQueueItem> treeItems = getAllItems();

      // Check if counts match
      if (dbItems.length != treeItems.length) {
        debugPrint(
            'BTreeQueueManager: Consistency check failed - count mismatch');
        return false;
      }

      // Check if all items exist in both
      for (var dbItem in dbItems) {
        if (!treeItems
            .any((treeItem) => treeItem.queueEntryId == dbItem.queueEntryId)) {
          debugPrint(
              'BTreeQueueManager: Consistency check failed - missing item ${dbItem.queueEntryId}');
          return false;
        }
      }

      debugPrint('BTreeQueueManager: Consistency check passed');
      return true;
    } catch (e) {
      debugPrint('BTreeQueueManager: Error during consistency check: $e');
      return false;
    }
  }

  // Export tree structure for debugging
  Map<String, dynamic> exportTreeStructure() {
    _ensureInitialized();
    return _bTreeQueue.exportTreeStructure();
  }

  // Get queue size
  int get queueSize => _isInitialized ? _bTreeQueue.size : 0;

  // Check if queue is empty
  bool get isEmpty => _isInitialized ? _bTreeQueue.isEmpty : true;

  // Check if manager is initialized
  bool get isInitialized => _isInitialized;
}
