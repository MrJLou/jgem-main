import 'package:flutter/material.dart';
import '../../services/queue_service.dart';
import '../../models/active_patient_queue_item.dart';

class RemoveFromQueueScreen extends StatefulWidget {
  final QueueService queueService;

  const RemoveFromQueueScreen({super.key, required this.queueService});

  @override
  RemoveFromQueueScreenState createState() => RemoveFromQueueScreenState();
}

class RemoveFromQueueScreenState extends State<RemoveFromQueueScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<ActivePatientQueueItem>>? _searchResultsFuture;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    // Initially load waiting and in-consultation patients
    _performSearch('', initialLoad: true);
  }

  void _performSearch(String query, {bool initialLoad = false}) {
    setState(() {
      _searchTerm = query.toLowerCase();
      // Fetch all statuses if searching, otherwise only active ones for initial/empty view
      List<String> statusesToFetch = (initialLoad || query.isEmpty)
          ? ['waiting', 'in_consultation']
          : ['waiting', 'in_consultation', 'served', 'removed'];

      _searchResultsFuture = widget.queueService
          .searchPatientsInQueue(query)
          .then((results) => results
              .where((item) => statusesToFetch.contains(item.status))
              .toList());
    });
  }

  Future<void> _removeFromQueueDialog(ActivePatientQueueItem patient) async {
    bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Removal'),
              content: Text(
                  'Are you sure you want to remove ${patient.patientName} (ID: ${patient.patientId ?? 'N/A'}) from the queue?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Remove', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted) return;
    if (confirm) {
      try {
        bool success =
            await widget.queueService.removeFromQueue(patient.queueEntryId);
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${patient.patientName} marked as removed from queue.'),
              backgroundColor: Colors.green,
            ),
          );
          _performSearch(_searchTerm); // Refresh results
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to remove ${patient.patientName}. Item not found or error occurred.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove from Queue'),
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Name or Patient ID',
                hintText: 'Enter name or ID to search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        })
                    : null,
              ),
              onChanged: (value) => _performSearch(value),
              onSubmitted: (value) =>
                  _performSearch(value), // Also search on submit
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<ActivePatientQueueItem>>(
                future: _searchResultsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (_searchTerm.isNotEmpty ||
                          _searchResultsFuture == null)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(_searchTerm.isEmpty
                          ? 'No active patients in the queue (status: waiting, in_consultation).'
                          : 'No patients found matching "$_searchTerm" with current filters.'),
                    );
                  }
                  final results = snapshot.data!;
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final patient = results[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(patient.patientName),
                          subtitle: Text(
                              'Queue No.: ${patient.queueNumber} - ID: ${patient.patientId ?? 'N/A'} - Arrived: ${TimeOfDay.fromDateTime(patient.arrivalTime).format(context)} - Status: ${_getDisplayStatus(patient.status)}'),
                          trailing: (patient.status == 'waiting' ||
                                  patient.status == 'in_consultation')
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _removeFromQueueDialog(patient),
                                  tooltip: 'Remove from Queue',
                                )
                              : (patient.status == 'removed'
                                  ? Chip(
                                      label: const Text('Removed'),
                                      backgroundColor: Colors.grey.shade300)
                                  : null), // No action for 'served' or other statuses here
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
