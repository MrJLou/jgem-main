import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/active_patient_queue_item.dart';
import '../maintenance/update_screen.dart'; // Import for RecentUpdateLogService

class ModifyPatientStatusScreen extends StatefulWidget {
  const ModifyPatientStatusScreen({super.key});

  @override
  ModifyPatientStatusScreenState createState() =>
      ModifyPatientStatusScreenState();
}

class ModifyPatientStatusScreenState extends State<ModifyPatientStatusScreen> {
  final TextEditingController _searchController = TextEditingController();
  ActivePatientQueueItem? _searchedQueueItem;
  bool _isLoading = false;

  Future<void> _performSearch() async {
    String searchTerm = _searchController.text;
    if (searchTerm.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _searchedQueueItem = null;
      });
      try {
        final results =
            await ApiService.searchPatientsInActiveQueue(searchTerm);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (results.isEmpty) {
            _searchedQueueItem = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'No patient found in active queue matching "$searchTerm".'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          } else if (results.length == 1) {
            _searchedQueueItem = results.first;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${results.length} patients found. Displaying the first. (Refine search or implement selection)'),
                backgroundColor: Colors.blueAccent,
              ),
            );
            _searchedQueueItem = results.first;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _searchedQueueItem = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching patient status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Patient ID or Name to search.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // Method to reload the current _searchedQueueItem details from the database
  Future<void> _loadSearchedItemDetails() async {
    if (_searchedQueueItem == null) return;
    try {
      final updatedItem =
          await ApiService.getActiveQueueItem(_searchedQueueItem!.queueEntryId);
      if (!mounted) return;
      setState(() {
        _searchedQueueItem = updatedItem;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reloading patient status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_searchedQueueItem == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patient selected to update status.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String displayStatus = newStatus.replaceAll('_', ' ').capitalizeFirst();

    try {
      // ApiService.updateActivePatientStatus is void, so we don't assign its result
      await ApiService.updateActivePatientStatus(
          _searchedQueueItem!.queueEntryId, newStatus);

      // If the above call doesn't throw an error, assume success
      await _loadSearchedItemDetails(); // Refresh data

      if (!mounted) return; // Check mounted after async operation
      setState(() =>
          _isLoading = false); // Set loading to false after successful load

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Status for ${_searchedQueueItem?.patientName ?? "Patient"} updated to $displayStatus.'),
          backgroundColor: Colors.green,
        ),
      );
      RecentUpdateLogService.addLog('Patient Status',
          'Status for ${_searchedQueueItem?.patientName ?? "Patient"} (ID: ${_searchedQueueItem?.patientId ?? _searchedQueueItem?.queueEntryId ?? "N/A"}) to $displayStatus');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Modify Patient Status',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Patient ID/Name in Queue',
                      hintText: 'Enter Patient ID or Name from Active Queue',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                    ),
                    onSubmitted: (_) =>
                        _performSearch(), // Allow search on submit
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _performSearch, // Disable when loading
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600], // Primary action color
                      foregroundColor: Colors.white, // White text
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12), // Consistent padding
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8.0), // Consistent radius
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600) // Consistent text style
                      ),
                  child: _isLoading &&
                          _searchController.text
                              .isNotEmpty // Show loader only if this button triggered loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ))
                      : const Text('Enter'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                    color: Colors.teal[50]?.withAlpha(128),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.teal[300]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(51),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ]),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchedQueueItem != null
                        ? _buildStatusModificationArea()
                        // If _searchResults is not empty and _searchedQueueItem is null, it means multiple results were found
                        // but we are not yet building a list for selection. This case is currently handled by picking the first.
                        // A more robust UI would show a list here:
                        // : _searchResults.isNotEmpty
                        //    ? _buildSearchResultsList() // You would create this widget
                        : Center(
                            // Initial placeholder or no results
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined,
                                  size: 60, color: Colors.teal[700]),
                              const SizedBox(height: 10),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Search for a patient in the active queue to modify their status.'
                                    : 'Patient not found or multiple results. Please refine your search.', // This message might need adjustment based on multiple results handling
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.teal[800],
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          )),
              ),
            ),
            // const SizedBox(height: 20), // Space for removed button
            // Back Button - REMOVED
            /*
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                child: const Text('Back'),
              ),
            ),
            */
          ],
        ),
      ),
    );
  }

  Widget _buildStatusModificationArea() {
    if (_searchedQueueItem == null) {
      return const SizedBox
          .shrink(); // Should not happen if this widget is built
    }

    // This widget will be displayed after a patient is "found"
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          // Use patientName from _searchedQueueItem
          'Modifying Status for: ${_searchedQueueItem!.patientName}',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal[900]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          '(Queue No: ${_searchedQueueItem!.queueNumber})',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 15),
        Text(
          // Use status from _searchedQueueItem
          'Current Status: ${_searchedQueueItem!.status.capitalizeFirst()}',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Select New Status',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            filled: true,
            fillColor: Colors.white,
          ),
          // Use status from _searchedQueueItem for the value
          value: _searchedQueueItem!.status,
          items: ['waiting', 'in_consultation', 'served', 'removed']
              .map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value.replaceAll('_', ' ').capitalizeFirst()),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _searchedQueueItem!.status) {
              _updateStatus(newValue);
            }
          },
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Updating..."),
          )
        else
          Text(
            'New status will reflect above upon successful update.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
      ],
    );
  }
}

// Helper extension for String capitalization
extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
