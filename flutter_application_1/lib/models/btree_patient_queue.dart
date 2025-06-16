// B-Tree implementation for patient queue management
import 'active_patient_queue_item.dart';
import 'btree_queue_node.dart';

class BTreePatientQueue {
  BTreeQueueNode? root;
  int _size = 0;

  BTreePatientQueue() {
    root = null;
  }

  // Get the size of the queue
  int get size => _size;

  // Check if the queue is empty
  bool get isEmpty => root == null;

  // Insert a new patient queue item
  void insert(ActivePatientQueueItem item) {
    if (root == null) {
      // Create root
      root = BTreeQueueNode(isLeaf: true);
      root!.keys.add(item);
    } else {
      // If root is full, create new root
      if (root!.keyCount == 2 * BTreeQueueNode.minDegree - 1) {
        BTreeQueueNode newRoot = BTreeQueueNode(isLeaf: false);
        newRoot.children.add(root!);
        newRoot.splitChild(0);

        // Decide which child should have the new key
        int i = 0;
        if (newRoot.keys[0].queueNumber < item.queueNumber) {
          i++;
        }
        newRoot.children[i].insertNonFull(item);
        root = newRoot;
      } else {
        root!.insertNonFull(item);
      }
    }
    _size++;
  }

  // Search for a patient by queue number
  ActivePatientQueueItem? searchByQueueNumber(int queueNumber) {
    if (root == null) return null;
    return root!.search(queueNumber);
  }

  // Search for patients by name (partial match)
  List<ActivePatientQueueItem> searchByName(String name) {
    if (root == null) return [];
    return root!.searchByName(name);
  }

  // Search for patients by status
  List<ActivePatientQueueItem> searchByStatus(String status) {
    if (root == null) return [];
    return root!.searchByStatus(status);
  }

  // Search for patients by patient ID
  List<ActivePatientQueueItem> searchByPatientId(String patientId) {
    if (root == null) return [];
    
    List<ActivePatientQueueItem> allItems = getAllItems();
    return allItems.where((item) => 
      item.patientId?.toLowerCase().contains(patientId.toLowerCase()) ?? false
    ).toList();
  }

  // Advanced search with multiple criteria
  List<ActivePatientQueueItem> advancedSearch({
    String? name,
    String? patientId,
    String? status,
    DateTime? arrivalDate,
    String? doctorName,
  }) {
    if (root == null) return [];
    
    List<ActivePatientQueueItem> results = getAllItems();
    
    if (name != null && name.isNotEmpty) {
      String lowerName = name.toLowerCase();
      results = results.where((item) => 
        item.patientName.toLowerCase().contains(lowerName)
      ).toList();
    }
    
    if (patientId != null && patientId.isNotEmpty) {
      String lowerPatientId = patientId.toLowerCase();
      results = results.where((item) => 
        item.patientId?.toLowerCase().contains(lowerPatientId) ?? false
      ).toList();
    }
    
    if (status != null && status.isNotEmpty) {
      String lowerStatus = status.toLowerCase();
      results = results.where((item) => 
        item.status.toLowerCase() == lowerStatus
      ).toList();
    }
    
    if (arrivalDate != null) {
      results = results.where((item) => 
        item.arrivalTime.year == arrivalDate.year &&
        item.arrivalTime.month == arrivalDate.month &&
        item.arrivalTime.day == arrivalDate.day
      ).toList();
    }
    
    if (doctorName != null && doctorName.isNotEmpty) {
      String lowerDoctorName = doctorName.toLowerCase();
      results = results.where((item) => 
        item.doctorName?.toLowerCase().contains(lowerDoctorName) ?? false
      ).toList();
    }
    
    return results;
  }

  // Get all items in sorted order (by queue number)
  List<ActivePatientQueueItem> getAllItems() {
    if (root == null) return [];
    return root!.getAllItems();
  }

  // Get items by priority/status order
  List<ActivePatientQueueItem> getItemsByPriority() {
    List<ActivePatientQueueItem> allItems = getAllItems();
    
    // Sort by priority: in_consultation > waiting > served > removed
    allItems.sort((a, b) {
      // First sort by status priority
      int statusPriorityA = _getStatusPriority(a.status);
      int statusPriorityB = _getStatusPriority(b.status);
      
      if (statusPriorityA != statusPriorityB) {
        return statusPriorityA.compareTo(statusPriorityB);
      }
      
      // Then by queue number for same status
      return a.queueNumber.compareTo(b.queueNumber);
    });
    
    return allItems;
  }

  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'in_consultation': return 1;
      case 'waiting': return 2;
      case 'served': return 3;
      case 'removed': return 4;
      default: return 5;
    }
  }

  // Remove a patient from the queue
  bool remove(int queueNumber) {
    if (root == null) return false;
    
    bool removed = root!.remove(queueNumber);
    
    if (removed) {
      _size--;
      
      // If root becomes empty, make first child as new root
      if (root!.keyCount == 0) {
        if (!root!.isLeaf) {
          root = root!.children[0];
        } else {
          root = null;
        }
      }
    }
    
    return removed;
  }

  // Update a patient queue item
  bool update(ActivePatientQueueItem updatedItem) {
    if (root == null) return false;
    return root!.update(updatedItem);
  }

  // Get queue statistics
  Map<String, int> getStatistics() {
    if (root == null) {
      return {
        'waiting': 0,
        'in_consultation': 0,
        'served': 0,
        'removed': 0,
        'total': 0,
      };
    }
    return root!.getStatistics();
  }

  // Get items for today only
  List<ActivePatientQueueItem> getTodayItems() {
    DateTime today = DateTime.now();
    List<ActivePatientQueueItem> allItems = getAllItems();
    
    return allItems.where((item) =>
      item.arrivalTime.year == today.year &&
      item.arrivalTime.month == today.month &&
      item.arrivalTime.day == today.day
    ).toList();
  }

  // Get waiting patients count
  int getWaitingCount() {
    return searchByStatus('waiting').length;
  }

  // Get in consultation patients count
  int getInConsultationCount() {
    return searchByStatus('in_consultation').length;
  }

  // Get next patient in queue (first waiting patient)
  ActivePatientQueueItem? getNextPatient() {
    List<ActivePatientQueueItem> waitingPatients = searchByStatus('waiting');
    if (waitingPatients.isEmpty) return null;
    
    // Sort by queue number and return first
    waitingPatients.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    return waitingPatients.first;
  }

  // Get current patient in consultation
  List<ActivePatientQueueItem> getCurrentConsultations() {
    return searchByStatus('in_consultation');
  }

  // Filter items by date range
  List<ActivePatientQueueItem> getItemsInDateRange(DateTime startDate, DateTime endDate) {
    List<ActivePatientQueueItem> allItems = getAllItems();
    
    return allItems.where((item) {
      DateTime itemDate = DateTime(
        item.arrivalTime.year,
        item.arrivalTime.month,
        item.arrivalTime.day,
      );
      DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
      DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
      
      return (itemDate.isAfter(start) || itemDate.isAtSameMomentAs(start)) &&
             (itemDate.isBefore(end) || itemDate.isAtSameMomentAs(end));
    }).toList();
  }
  // Get queue performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    List<ActivePatientQueueItem> todayItems = getTodayItems();
    Map<String, int> stats = getStatistics();
    
    double averageWaitTime = 0.0;
    int servedCount = 0;
    
    for (var item in todayItems) {
      if (item.status == 'served' && item.servedAt != null) {
        Duration waitTime = item.servedAt!.difference(item.arrivalTime);
        averageWaitTime += waitTime.inMinutes;
        servedCount++;
      }
    }
    
    if (servedCount > 0) {
      averageWaitTime = averageWaitTime / servedCount;
    }
    
    return {
      'totalPatients': stats['total'],
      'waitingPatients': stats['waiting'],
      'inConsultation': stats['in_consultation'],
      'servedPatients': stats['served'],
      'removedPatients': stats['removed'],
      'averageWaitTimeMinutes': averageWaitTime,
      'currentQueueLength': getWaitingCount(),
      'activeConsultations': getInConsultationCount(),
    };
  }

  // Clear all items from the queue
  void clear() {
    root = null;
    _size = 0;
  }

  // Build tree from a list of items
  void buildFromList(List<ActivePatientQueueItem> items) {
    clear();
    
    // Sort items by queue number for optimal tree construction
    items.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    
    for (var item in items) {
      insert(item);
    }
  }

  // Export tree structure for debugging
  Map<String, dynamic> exportTreeStructure() {
    if (root == null) {
      return {'isEmpty': true};
    }
    
    return {
      'isEmpty': false,
      'size': _size,
      'statistics': getStatistics(),
      'performanceMetrics': getPerformanceMetrics(),
      'allItems': getAllItems().map((item) => {
        'queueNumber': item.queueNumber,
        'patientName': item.patientName,
        'patientId': item.patientId,
        'status': item.status,
        'arrivalTime': item.arrivalTime.toIso8601String(),
      }).toList(),
    };
  }
}
