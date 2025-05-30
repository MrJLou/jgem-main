import 'package:flutter/material.dart';
import '../../services/queue_service.dart';
import '../../models/active_patient_queue_item.dart'; // Import the model

class ViewQueueScreen extends StatefulWidget {
  final QueueService queueService;

  const ViewQueueScreen({Key? key, required this.queueService})
      : super(key: key);

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
    _queueFuture = widget.queueService.getActiveQueueItems();
  }

  void _refreshQueue() {
    setState(() {
      _loadQueue(); // Re-fetch the queue data
    });
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
            padding: const EdgeInsets.only(top: 20.0, left: 50.0, right: 50.0),
            child: Column(
              children: [
                _buildTableHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final statusWidget = item.status == 'removed'
                          ? _buildRemovedTag()
                          : _buildDetailsButton(context, item);
                      return _buildTableRow(item, statusWidget);
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
      'Name',
      'Arrival Time',
      'Gender',
      'Age',
      'Condition',
      'Status'
    ];
    return Container(
      color: Colors.teal[700],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: headers.map((text) {
          return TableCellWidget(
            text: text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(ActivePatientQueueItem item, Widget statusWidget) {
    // Format arrivalTime for display
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';

    final dataCells = [
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
        color: item.status == 'removed' ? Colors.grey.shade200 : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...dataCells.map((text) => TableCellWidget(
                text: text.toString(),
                style: cellStyle,
              )),
          TableCellWidget(child: statusWidget),
        ],
      ),
    );
  }

  Widget _buildRemovedTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('Removed',
          style: TextStyle(
              color: Colors.red[900],
              fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDetailsButton(
      BuildContext context, ActivePatientQueueItem item) {
    return ElevatedButton(
      onPressed: () {
        // TODO: Implement navigation to a detailed view or action for the queue item
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viewing details for ${item.patientName}'),
            backgroundColor: Colors.teal,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(item.status == 'waiting'
          ? 'View'
          : item.status == 'in_consultation'
              ? 'Consulting'
              : 'Details'),
    );
  }

  final TextStyle cellStyle = TextStyle(fontSize: 14);
}

class TableCellWidget extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final Widget? child;

  const TableCellWidget({
    Key? key,
    this.text,
    this.style,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: child ??
            Text(
              text ?? '',
              style: style,
            ),
      ),
    );
  }
}
