import 'package:flutter/material.dart';
import '../../services/queue_service.dart';
import '../../models/active_patient_queue_item.dart'; // Import the model

class ViewQueueScreen extends StatefulWidget {
  final QueueService queueService;

  const ViewQueueScreen({super.key, required this.queueService});

  @override
  _ViewQueueScreenState createState() => _ViewQueueScreenState();
}

class _ViewQueueScreenState extends State<ViewQueueScreen> {
  late Future<List<ActivePatientQueueItem>> _queueFuture;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  void _loadQueue() {
    // Fetch all statuses to show a comprehensive view
    _queueFuture = widget.queueService.getActiveQueueItems(
        statuses: ['waiting', 'in_consultation', 'served', 'removed']);
  }

  void _refreshQueue() {
    setState(() {
      _loadQueue(); // Re-fetch the queue data
    });
  }

  Future<void> _updatePatientStatus(
      ActivePatientQueueItem item, String newStatus) async {
    try {
      bool success = false;
      if (newStatus == 'served') {
        success =
            await widget.queueService.markPatientAsServed(item.queueEntryId);
      } else if (newStatus == 'in_consultation') {
        success = await widget.queueService
            .markPatientAsInConsultation(item.queueEntryId);
      } else if (newStatus == 'waiting') {
        // Add a method in QueueService to specifically handle reverting to 'waiting'
        // This might involve clearing servedAt or consultationStartedAt timestamps.
        // For now, using a general update method if available or modifying existing.
        success = await widget.queueService
            .updatePatientStatus(item.queueEntryId, 'waiting');
      }
      // Add other status updates like 'removed' if it's not handled by a separate screen/flow.

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${item.patientName}\'s status updated to $newStatus.'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshQueue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status for ${item.patientName}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'View Queue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            onPressed: _refreshQueue,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Queue',
          ),
        ],
      ),
      body: FutureBuilder<List<ActivePatientQueueItem>>(
        future: _queueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading queue: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyQueueMessage();
          }

          final queue = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.only(
                top: 20.0, left: 20.0, right: 20.0), // Adjusted padding
            child: Column(
              children: [
                _buildTableHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      return _buildTableRow(
                          item); // statusWidget is now part of _buildTableRow
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyQueueMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'No patients in the queue',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Patients will appear here when added to the queue',
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

  Widget _buildTableHeader() {
    final headers = [
      'Queue No.', // Added Queue Number
      'Name',
      'Arrival Time',
      'Gender',
      'Age',
      'Condition',
      'Status & Actions' // Combined Status and Actions
    ];
    return Container(
      color: Colors.teal[700],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceAround, // Will adjust with Expanded
        children: headers.map((text) {
          return Expanded(
              // Use Expanded for better column sizing
              flex: (text == 'Name' || text == 'Status & Actions')
                  ? 2
                  : (text == 'Condition' ? 2 : 1), // Adjust flex values
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

  Widget _buildTableRow(ActivePatientQueueItem item) {
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';

    final dataCells = [
      item.queueNumber.toString(), // Display Queue Number
      item.patientName,
      arrivalDisplayTime,
      item.gender ?? 'N/A',
      item.age?.toString() ?? 'N/A',
      item.conditionOrPurpose ?? 'N/A',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: item.status == 'removed'
            ? Colors.grey.shade200
            : (item.status == 'served' ? Colors.lightGreen[50] : Colors.white),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex =
                (idx == 1) ? 2 : (idx == 5 ? 2 : 1); // Name and Condition
            if (idx == 0)
              flex =
                  0; // Queue number fixed small size if needed via SizedBox or fixed width

            Widget cellChild =
                Text(text, style: cellStyle, overflow: TextOverflow.ellipsis);
            if (idx == 0) {
              // Queue Number specific styling/sizing
              return Expanded(
                  flex: 1,
                  child: Center(
                      child: Text(text,
                          style: cellStyle.copyWith(
                              fontWeight: FontWeight.bold))));
            }

            return Expanded(
                flex: flex,
                child: TableCellWidget(
                  text: text,
                  style: cellStyle,
                ));
          }).toList(),
          Expanded(
            // Status and Actions cell
            flex: 2, // Give more space for status and actions
            child: TableCellWidget(child: _buildStatusActionsWidget(item)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActionsWidget(ActivePatientQueueItem item) {
    if (item.status == 'removed') {
      return _buildRemovedTag();
    }

    List<String> possibleStatuses = ['waiting', 'in_consultation', 'served'];
    String currentStatus = item.status;
    if (!possibleStatuses.contains(currentStatus)) {
      // Fallback for unknown statuses
      currentStatus = 'waiting';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _getDisplayStatus(item.status), // Display current status text
          style: TextStyle(
              fontWeight: FontWeight.bold, color: _getStatusColor(item.status)),
        ),
        SizedBox(width: 8), // Add some space between text and icon
        PopupMenuButton<String>(
          tooltip: "Change Status",
          icon: Icon(Icons.edit, size: 20, color: Colors.teal[600]),
          onSelected: (String newStatus) {
            _updatePatientStatus(item, newStatus);
          },
          itemBuilder: (BuildContext context) {
            return possibleStatuses.map((String statusValue) {
              return PopupMenuItem<String>(
                value: statusValue,
                child: Text(_getDisplayStatus(statusValue)),
              );
            }).toList();
          },
        ),
      ],
    );
  }

  // Helper to get display-friendly status string
  static String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return 'Waiting';
      case 'in_consultation':
        return 'In Consultation'; // Changed
      case 'served':
        return 'Served';
      case 'removed':
        return 'Removed';
      default:
        return status; // Fallback to the original status if unknown
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange.shade700;
      case 'in_consultation':
        return Colors.blue.shade700;
      case 'served':
        return Colors.green.shade700;
      case 'removed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildRemovedTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red[100], // Lighter red for removed tag
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('Removed',
          style: TextStyle(
              color: Colors.red[700],
              fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }

  // _buildDetailsButton is replaced by _buildStatusActionsWidget
  // TextStyle cellStyle = const TextStyle(fontSize: 14); // Defined at class level if not already
  TextStyle cellStyle = const TextStyle(
      fontSize: 14, color: Colors.black87); // ensure it's defined
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
      // Add padding around cell content for better spacing
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: Center(
        child: child ??
            Text(
              text ?? '',
              style: style,
              textAlign: TextAlign.center, // Center text in cell
              overflow:
                  TextOverflow.ellipsis, // Prevent long text from breaking UI
            ),
      ),
    );
  }
}
