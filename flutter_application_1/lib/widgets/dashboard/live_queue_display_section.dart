// Live queue display section widget for dashboard
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../models/active_patient_queue_item.dart';
import '../../services/api_service.dart'; // Added import for ApiService

// Helper class for table cells to ensure consistent formatting
class TableCellWidget extends StatelessWidget {
  final Widget? child;
  final String? text;
  final TextStyle? style;
  final TextAlign textAlign;

  const TableCellWidget({
    Key? key,
    this.child,
    this.text,
    this.style,
    this.textAlign = TextAlign.center,
  }) : assert(child != null || text != null),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: child ?? Text(
        text!,
        style: style,
        textAlign: textAlign,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class LiveQueueDisplaySection extends StatefulWidget {
  final DateTime calendarSelectedDate;
  final bool isLoadingQueueAndAppointments;
  final List<ActivePatientQueueItem> walkInQueueItems;
  final List<Appointment> appointmentsForSelectedDate;
  final Function(String) onActivateAppointment;
  final Function(ActivePatientQueueItem, String) onUpdateQueueItemStatus;
  final String Function(String) getDisplayStatus;
  final Color Function(String) getStatusColor;

  const LiveQueueDisplaySection({
    super.key,
    required this.calendarSelectedDate,
    required this.isLoadingQueueAndAppointments,
    required this.walkInQueueItems,
    required this.appointmentsForSelectedDate,
    required this.onActivateAppointment,
    required this.onUpdateQueueItemStatus,
    required this.getDisplayStatus,
    required this.getStatusColor,
  });

  @override
  LiveQueueDisplaySectionState createState() => LiveQueueDisplaySectionState();
}

class LiveQueueDisplaySectionState extends State<LiveQueueDisplaySection> {
  // Cache for patient names to avoid repeated API calls
  final Map<String, String> _patientNamesCache = {};

  // Method to get patient name from ID with caching
  Future<String> _getPatientName(String patientId) async {
    if (_patientNamesCache.containsKey(patientId)) {
      return _patientNamesCache[patientId]!;
    }
    
    try {
      final patient = await ApiService.getPatientById(patientId);
      final name = patient.fullName;
      _patientNamesCache[patientId] = name;
      return name;
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = widget.calendarSelectedDate.year == now.year &&
                    widget.calendarSelectedDate.month == now.month &&
                    widget.calendarSelectedDate.day == now.day;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Row(
              children: [
                Icon(Icons.queue, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Text(
                  isToday ? 'Live Patient Queue (Today)' : 'Patient Queue for ${DateFormat.yMMMd().format(widget.calendarSelectedDate)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (widget.isLoadingQueueAndAppointments)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Walk-in patients section (only for today)
              if (isToday) ...[
                Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Walk-in Patients (${widget.walkInQueueItems.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.walkInQueueItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(
                        'No walk-in patients in queue',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else ...[
                  _buildTableHeader(),
                  ...widget.walkInQueueItems.map((item) => _buildTableRow(item)),
                ],
                const SizedBox(height: 24),
              ],
              
              // Scheduled appointments section
              Row(
                children: [
                  Icon(Icons.event, size: 20, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Scheduled Appointments (${widget.appointmentsForSelectedDate.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.appointmentsForSelectedDate.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      'No appointments scheduled for this date',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else ...[
                _buildAppointmentTableHeader(),
                ...widget.appointmentsForSelectedDate.map((appointment) => _buildAppointmentTableRow(appointment)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    final headers = ['No.', 'Name', 'Arrival', 'Condition', 'Payment', 'Status & Actions'];
    return Container(
      color: Colors.teal[600],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: headers.map((text) {
          int flex = 1;
          if (text == 'Name') flex = 2;
          if (text == 'Condition') flex = 4; // Further increased flex for services/condition
          if (text == 'Status & Actions') flex = 3;
          if (text == 'Payment') flex = 1; 

          return Expanded(
              flex: flex,
              child: TableCellWidget(
                  text: text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)));
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(ActivePatientQueueItem item) {
    const cellStyle = TextStyle(fontSize: 14, color: Colors.black87);
    final arrivalDisplayTime =
        '${item.arrivalTime.hour.toString().padLeft(2, '0')}:${item.arrivalTime.minute.toString().padLeft(2, '0')}';
      bool isRepresentingScheduledAppointment = item.queueEntryId.startsWith('appt_');
    String originalAppointmentId = isRepresentingScheduledAppointment && item.queueEntryId.length > 5 
        ? item.queueEntryId.substring(5) 
        : '';

    final dataCells = [
      isRepresentingScheduledAppointment && item.status == 'Scheduled'
          ? arrivalDisplayTime
          : (item.queueNumber).toString(),
      item.patientName,
      isRepresentingScheduledAppointment ? "-" : arrivalDisplayTime,
      // Format condition or selected services better
      item.selectedServices?.isNotEmpty == true 
          ? item.selectedServices!.map((s) => s['name'] as String? ?? '').join(', ')
          : (item.conditionOrPurpose ?? 'N/A'),
      item.paymentStatus,
    ];

    TextStyle paymentStatusStyle = TextStyle(
        fontSize: cellStyle.fontSize,
        fontWeight: FontWeight.w500,
        color: item.paymentStatus == 'Paid' 
            ? Colors.green.shade700 
            : (item.paymentStatus == 'Pending' ? Colors.orange.shade800 : Colors.grey.shade700)
    );
    if (isRepresentingScheduledAppointment && item.status == 'Scheduled'){
        paymentStatusStyle = paymentStatusStyle.copyWith(color: Colors.purple.shade700);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3), // Increased vertical margin
      padding: const EdgeInsets.symmetric(vertical: 8), // Increased vertical padding
      decoration: BoxDecoration(
          color: isRepresentingScheduledAppointment && item.status == 'Scheduled' 
              ? Colors.indigo[50]
              : (item.status == 'removed'
                  ? Colors.grey.shade200
                  : (item.status == 'served' 
                      ? Colors.lightGreen[50] 
                      : (item.status == 'in_progress' 
                          ? Colors.purple[50] 
                          : Colors.white))),
          border: Border.all(
            color: isRepresentingScheduledAppointment && item.status == 'Scheduled' 
                   ? Colors.indigo[200]! 
                   : Colors.grey.shade300,
            width: isRepresentingScheduledAppointment && item.status == 'Scheduled' ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4)
      ),
      child: Row(
        children: [
          ...dataCells.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex = 1;
            TextStyle currentCellStyle = cellStyle.copyWith(
              color: isRepresentingScheduledAppointment && item.status == 'Scheduled' 
                     ? Colors.indigo[700] 
                     : cellStyle.color
            );

            switch (idx) {
              case 0: // No. or Scheduled Time
                flex = 1;
                currentCellStyle = currentCellStyle.copyWith(
                  fontWeight: FontWeight.bold,
                );
                break;
              case 1: // Name
                flex = 2;
                break;
              case 2: // Arrival (or '-' for scheduled)
                flex = 1;
                break;
              case 3: // Condition
                flex = 4; // Further increased flex for services/condition
                break;
              case 4: // Payment
                flex = 1;
                currentCellStyle = paymentStatusStyle.copyWith(
                  color: isRepresentingScheduledAppointment && item.status == 'Scheduled' 
                         ? Colors.indigo[700] 
                         : paymentStatusStyle.color
                );
                break;
            }

            return Expanded(
                flex: flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: idx == 3 ? // Condition/Services column
                    TableCellWidget(
                      child: Tooltip(
                        message: text, // Show full text in tooltip on hover
                        child: Text(
                          text, 
                          style: currentCellStyle, 
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start, // Left-align services text
                          maxLines: 3, // Increased to 3 lines for more service text visibility
                        ),
                      ),
                    ) :
                    TableCellWidget(
                      child: Text(text, style: currentCellStyle, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    ),
                ));
          }),
          Expanded(
            flex: 3,
            child: isRepresentingScheduledAppointment && item.status == 'Scheduled' 
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text("Activate", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          widget.onActivateAppointment(originalAppointmentId);
                        },
                    ), 
                  )
                : (item.status == 'waiting' || item.status == 'in_progress')
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: PopupMenuButton<String>(
                        tooltip: "Change Status",
                        icon: Icon(Icons.more_vert, color: widget.getStatusColor(item.status)),
                        onSelected: (String newStatus) {
                           widget.onUpdateQueueItemStatus(item, newStatus);
                        },
                        itemBuilder: (BuildContext context) {
                          List<String> possibleStatuses = [];
                          if (item.status == 'waiting') {
                            possibleStatuses.addAll(['in_progress', 'served', 'removed']);
                          } else if (item.status == 'in_progress') {
                            possibleStatuses.addAll(['waiting', 'served', 'removed']);
                          }
                          return possibleStatuses.map((String statusValue) {
                            return PopupMenuItem<String>(
                              value: statusValue,
                              child: Text(widget.getDisplayStatus(statusValue)),
                            );
                          }).toList();
                        },
                      ),
                    )
                  : TableCellWidget(
                      child: Text(widget.getDisplayStatus(item.status),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.getStatusColor(item.status),
                              fontSize: cellStyle.fontSize),
                          textAlign: TextAlign.center)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentTableHeader() {
    final headers = ['Time', 'Patient', 'Doctor', 'Type', 'Status', 'Actions'];
    return Container(
      color: Colors.deepOrange[600],
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: headers.map((text) {
          int flex = 1;
          if (text == 'Type') flex = 2;
          if (text == 'Actions') flex = 2;
          if (text == 'Patient') flex = 3; // Increased flex for patient info
          
          return Expanded(
              flex: flex,
              child: TableCellWidget(
                  text: text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)));
        }).toList(),
      ),
    );
  }  Widget _buildAppointmentTableRow(Appointment appointment) {
    // Format time without context dependency
    final timeString = '${appointment.time.hour.toString().padLeft(2, '0')}:${appointment.time.minute.toString().padLeft(2, '0')}';
    
    // Prepare patient information with ID and name if available
    final patientCell = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<String>(
          future: _getPatientName(appointment.patientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic));
            }
            return Text(
              snapshot.data ?? 'Unknown',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        Text(
          'ID: ${appointment.patientId}', 
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
    
    final dataCells = [
      timeString,
      '', // Placeholder for patient column (we'll use a custom widget)
      appointment.doctorId,
      appointment.consultationType,
      appointment.status,
    ];

    // Check if the appointment is already activated
    bool isActivated = appointment.status.toLowerCase() == 'in consultation' || 
                      appointment.status.toLowerCase() == 'completed' ||
                      appointment.status.toLowerCase() == 'served' ||
                      appointment.status.toLowerCase() == 'removed' ||
                      appointment.status.toLowerCase() == 'cancelled';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3), // Increased vertical margin
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), // Increased padding
      decoration: BoxDecoration(
        color: isActivated ? Colors.green[50] : Colors.orange[50],
        border: Border.all(
          color: isActivated ? Colors.green[200]! : Colors.orange[200]!, 
          width: 1.0
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Time column (first cell)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TableCellWidget(
                child: Text(dataCells[0], 
                    style: TextStyle(
                      fontSize: 13, 
                      color: isActivated ? Colors.green[800] : Colors.deepOrange[800],
                      fontWeight: FontWeight.bold
                    ), 
                    overflow: TextOverflow.ellipsis, 
                    textAlign: TextAlign.center),
              ),
            )
          ),
          
          // Patient column (second cell)
          Expanded(
            flex: 3, // Increased flex for patient info
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TableCellWidget(
                child: patientCell,
              ),
            )
          ),
          
          // Remaining cells (doctor, type, status)
          ...dataCells.asMap().entries.where((entry) => entry.key >= 2).map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int flex = 1;
            if (idx == 3) flex = 2; // Type column
            
            return Expanded(
                flex: flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TableCellWidget(
                    child: Text(text, 
                        style: TextStyle(
                          fontSize: 13, 
                          color: isActivated ? Colors.green[800] : Colors.deepOrange[800]
                        ), 
                        overflow: TextOverflow.ellipsis, 
                        textAlign: TextAlign.center),
                  ),
                ));
          }),
          Expanded(
            flex: 2, // Actions column
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: isActivated 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      appointment.status.toLowerCase() == 'in consultation' 
                        ? 'In Progress' 
                        : 'Completed',
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 16),
                    label: const Text("Activate", style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => widget.onActivateAppointment(appointment.id),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
