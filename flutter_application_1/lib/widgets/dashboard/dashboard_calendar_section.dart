// Calendar section widget for dashboard
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/appointment.dart';

class DashboardCalendarSection extends StatelessWidget {
  final DateTime calendarSelectedDate;
  final DateTime calendarFocusedDay;
  final List<Appointment> allAppointmentsForCalendar;
  final List<Appointment> dailyAppointmentsForDisplay;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;
  final Function(int) onMonthSelected;

  const DashboardCalendarSection({
    super.key,
    required this.calendarSelectedDate,
    required this.calendarFocusedDay,
    required this.allAppointmentsForCalendar,
    required this.dailyAppointmentsForDisplay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildCalendarAppointmentsSection()),
        _buildYearMonthScroller(),
      ],
    );
  }

  Widget _buildCalendarAppointmentsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            child: TableCalendar<Appointment>(
              firstDay: DateTime.utc(DateTime.now().year - 5, 1, 1),
              lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
              focusedDay: calendarFocusedDay,
              selectedDayPredicate: (day) => isSameDay(calendarSelectedDate, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 17.0, color: Colors.teal[800], fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal[700], size: 24),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal[700], size: 24),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.teal[400],
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.teal[100]?.withAlpha(200),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.pinkAccent[200],
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
                outsideDaysVisible: false,
              ),
              eventLoader: (day) {
                return allAppointmentsForCalendar
                    .where((appointment) => isSameDay(appointment.date, day))
                    .toList();
              },
              onDaySelected: onDaySelected,
              onPageChanged: onPageChanged,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Appointments for ${DateFormat.yMMMd().format(calendarSelectedDate)}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[700]),
              ),
              Text(
                "${dailyAppointmentsForDisplay.length} scheduled",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          dailyAppointmentsForDisplay.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          "No appointments scheduled for this day.",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: dailyAppointmentsForDisplay.length,
                  itemBuilder: (context, index) {
                    final appointment = dailyAppointmentsForDisplay[index];
                    return _buildImageStyledAppointmentCard(appointment);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildImageStyledAppointmentCard(Appointment appointment, {bool isHighlighted = false}) {
    String details = appointment.consultationType;
    if (details.isEmpty) details = 'Scheduled';

    return Card(
        color: isHighlighted ? Colors.deepPurple.shade300 : Colors.white,
        elevation: isHighlighted ? 3 : 1.5,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isHighlighted
                    ? Colors.white.withAlpha(50)
                    : Colors.teal[500]?.withAlpha(26),
                child: Icon(
                  Icons.person_outline,
                  color: isHighlighted ? Colors.white : Colors.teal[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientId,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isHighlighted ? Colors.white : Colors.grey[800],
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: TextStyle(
                          color: isHighlighted
                              ? Colors.white.withAlpha(217)
                              : Colors.grey[600],
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) => Text(
                      appointment.time.format(context),
                      style: TextStyle(
                          color: isHighlighted
                              ? Colors.white.withAlpha(230)
                              : Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDashboardAppointmentStatusChip(appointment.status),
                ],
              )
            ],
          ),
        ));
  }

  Widget _buildDashboardAppointmentStatusChip(String status) {
    Color chipColor = Colors.grey.shade400;
    IconData iconData = Icons.info_outline;
    String label = status;

    switch (status.toLowerCase()) {
      case 'scheduled (simulated)':
      case 'scheduled':
        chipColor = Colors.blue.shade600;
        iconData = Icons.schedule_outlined;
        label = 'Scheduled';
        break;
      case 'confirmed':
        chipColor = Colors.green.shade600;
        iconData = Icons.check_circle_outline;
        label = 'Confirmed';
        break;
      case 'in consultation':
        chipColor = Colors.orange.shade700;
        iconData = Icons.medical_services_outlined;
        label = 'In Consult';
        break;
      case 'completed':
        chipColor = Colors.purple.shade600;
        iconData = Icons.done_all_outlined;
        label = 'Completed';
        break;
      case 'cancelled':
        chipColor = Colors.red.shade600;
        iconData = Icons.cancel_outlined;
        label = 'Cancelled';
        break;
      default:
        label = status.length > 10 ? '${status.substring(0,8)}...': status;
    }
    return Chip(
      avatar: Icon(iconData, color: Colors.white, size: 12),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
      backgroundColor: chipColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0.0),
      labelPadding: const EdgeInsets.only(left: 2.0, right: 4.0),
      iconTheme: const IconThemeData(size: 12),
    );
  }

  Widget _buildYearMonthScroller() {
    final currentYear = calendarSelectedDate.year.toString();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final currentMonthIndex = calendarSelectedDate.month - 1;

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(currentYear,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                  fontSize: 15)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: months.length,
            itemBuilder: (context, index) {
              bool isSelectedMonth = index == currentMonthIndex;
              return InkWell(
                onTap: () => onMonthSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  color: isSelectedMonth
                      ? Colors.teal[500]?.withAlpha(50)
                      : Colors.transparent,
                  child: Text(
                    months[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelectedMonth
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelectedMonth
                          ? Colors.teal[800]
                          : Colors.grey[700],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
