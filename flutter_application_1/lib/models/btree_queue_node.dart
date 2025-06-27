// B-Tree node implementation for patient queue organization
import 'active_patient_queue_item.dart';

class BTreeQueueNode {
  static const int minDegree = 3; // Minimum degree (t) - each node can have at most 2t-1 keys
  
  List<ActivePatientQueueItem> keys;
  List<BTreeQueueNode> children;
  bool isLeaf;

  BTreeQueueNode({required this.isLeaf}) 
    : keys = <ActivePatientQueueItem>[],
      children = <BTreeQueueNode>[];

  // Get key count
  int get keyCount => keys.length;

  // Search for a patient queue item by queue number
  ActivePatientQueueItem? search(int queueNumber) {
    int i = 0;
    
    // Find the first key greater than or equal to queueNumber
    while (i < keyCount && queueNumber > keys[i].queueNumber) {
      i++;
    }

    // If the found key is equal to queueNumber, return it
    if (i < keyCount && keys[i].queueNumber == queueNumber) {
      return keys[i];
    }

    // If this is a leaf node, the key is not found
    if (isLeaf) {
      return null;
    }

    // Go to the appropriate child
    return children[i].search(queueNumber);
  }

  // Search for patients by name (partial match)
  List<ActivePatientQueueItem> searchByName(String name) {
    List<ActivePatientQueueItem> results = [];
    String lowerName = name.toLowerCase();

    // Search in current node
    for (int i = 0; i < keyCount; i++) {
      if (keys[i].patientName.toLowerCase().contains(lowerName)) {
        results.add(keys[i]);
      }
    }

    // Search in children if not a leaf
    if (!isLeaf) {
      for (int i = 0; i < children.length; i++) {
        results.addAll(children[i].searchByName(name));
      }
    }

    return results;
  }

  // Search for patients by status
  List<ActivePatientQueueItem> searchByStatus(String status) {
    List<ActivePatientQueueItem> results = [];

    // Search in current node
    for (int i = 0; i < keyCount; i++) {
      if (keys[i].status.toLowerCase() == status.toLowerCase()) {
        results.add(keys[i]);
      }
    }

    // Search in children if not a leaf
    if (!isLeaf) {
      for (int i = 0; i < children.length; i++) {
        results.addAll(children[i].searchByStatus(status));
      }
    }

    return results;
  }

  // Get all items in order (in-order traversal)
  List<ActivePatientQueueItem> getAllItems() {
    List<ActivePatientQueueItem> result = [];

    for (int i = 0; i < keyCount; i++) {
      // If not leaf, get items from left child first
      if (!isLeaf && i < children.length) {
        result.addAll(children[i].getAllItems());
      }
      
      // Add current key
      result.add(keys[i]);
    }

    // If not leaf, get items from rightmost child
    if (!isLeaf && children.isNotEmpty) {
      result.addAll(children.last.getAllItems());
    }

    return result;
  }

  // Insert a new patient queue item (non-full node)
  void insertNonFull(ActivePatientQueueItem item) {
    if (isLeaf) {
      // Insert into leaf node
      keys.add(item);
      keys.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    } else {
      // Find appropriate child
      int i = 0;
      while (i < keyCount && item.queueNumber > keys[i].queueNumber) {
        i++;
      }
      
      // Check if child is full and split if needed
      if (i < children.length && children[i].keyCount >= 2 * minDegree - 1) {
        splitChild(i);
        // Decide which child to insert into after split
        if (item.queueNumber > keys[i].queueNumber) {
          i++;
        }
      }
      
      // Make sure child exists
      if (i >= children.length) {
        children.add(BTreeQueueNode(isLeaf: true));
      }
      
      children[i].insertNonFull(item);
    }
  }

  // Split a full child
  void splitChild(int index) {
    if (index >= children.length) return;
    
    BTreeQueueNode fullChild = children[index];
    BTreeQueueNode newChild = BTreeQueueNode(isLeaf: fullChild.isLeaf);
    
    int mid = fullChild.keyCount ~/ 2;
    
    // Move half the keys to new child
    newChild.keys.addAll(fullChild.keys.sublist(mid + 1));
    
    // Move half the children to new child (if not leaf)
    if (!fullChild.isLeaf) {
      int childMid = fullChild.children.length ~/ 2;
      newChild.children.addAll(fullChild.children.sublist(childMid));
      fullChild.children.removeRange(childMid, fullChild.children.length);
    }
    
    // Promote middle key to parent
    ActivePatientQueueItem promotedKey = fullChild.keys[mid];
    keys.add(promotedKey);
    keys.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    
    // Remove promoted key and right half from full child
    fullChild.keys.removeRange(mid, fullChild.keys.length);
    
    // Insert new child
    children.insert(index + 1, newChild);
  }

  // Remove a patient queue item
  bool remove(int queueNumber) {
    // Find the key in current node
    int index = -1;
    for (int i = 0; i < keyCount; i++) {
      if (keys[i].queueNumber == queueNumber) {
        index = i;
        break;
      }
    }
    
    if (index != -1) {
      // Key found in this node
      keys.removeAt(index);
      return true;
    } else if (!isLeaf) {
      // Key not found, search in children
      for (int i = 0; i < children.length; i++) {
        if (children[i].remove(queueNumber)) {
          return true;
        }
      }
    }
    
    return false;
  }

  // Update a patient queue item
  bool update(ActivePatientQueueItem updatedItem) {
    // Simple approach: remove and re-insert
    if (remove(updatedItem.queueNumber)) {
      insertNonFull(updatedItem);
      return true;
    }
    return false;
  }

  // Get statistics about the tree
  Map<String, int> getStatistics() {
    Map<String, int> stats = {
      'waiting': 0,
      'in_consultation': 0,
      'served': 0,
      'removed': 0,
      'total': 0,
    };

    List<ActivePatientQueueItem> allItems = getAllItems();
    for (var item in allItems) {
      stats[item.status] = (stats[item.status] ?? 0) + 1;
      stats['total'] = stats['total']! + 1;
    }

    return stats;
  }
}
