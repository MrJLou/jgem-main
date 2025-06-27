// Status dropdown widget for appointments
import 'package:flutter/material.dart';

class AppointmentStatusDropdown extends StatelessWidget {
  final String currentStatus;
  final Function(String?) onChanged;

  const AppointmentStatusDropdown({
    super.key,
    required this.currentStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    List<String> statuses = ['Pending', 'Confirmed', 'Cancelled', 'Completed'];
    if (!statuses.contains(currentStatus)) statuses.add(currentStatus);
    
    return DropdownButton<String>(
      value: currentStatus,
      items: statuses.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: onChanged,
      underline: Container(),
      style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.normal),
      iconEnabledColor: Colors.teal[700],
    );
  }
}
