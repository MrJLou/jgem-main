import 'dart:convert';

class DoctorAvailability {
  final String id;
  final String doctorId;
  final String doctorName;
  final Map<DayOfWeek, DaySchedule> weeklySchedule;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? notes;

  DoctorAvailability({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.weeklySchedule,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.notes,
  });

  /// Get today's schedule for this doctor
  DaySchedule? getTodaySchedule() {
    final today = DayOfWeek.fromDateTime(DateTime.now());
    return weeklySchedule[today];
  }

  /// Check if doctor is available today
  bool isAvailableToday() {
    final todaySchedule = getTodaySchedule();
    return todaySchedule?.isAvailable ?? false;
  }

  /// Get schedule for a specific day
  DaySchedule? getScheduleForDay(DayOfWeek day) {
    return weeklySchedule[day];
  }

  /// Check if doctor is available on a specific day
  bool isAvailableOnDay(DayOfWeek day) {
    final daySchedule = getScheduleForDay(day);
    return daySchedule?.isAvailable ?? false;
  }

  /// Get all days this doctor is available
  List<DayOfWeek> getAvailableDays() {
    return weeklySchedule.entries
        .where((entry) => entry.value.isAvailable)
        .map((entry) => entry.key)
        .toList();
  }

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    final scheduleMap = <DayOfWeek, DaySchedule>{};
    
    if (json['weeklySchedule'] is String) {
      final scheduleData = jsonDecode(json['weeklySchedule'] as String);
      for (final entry in (scheduleData as Map<String, dynamic>).entries) {
        final day = DayOfWeek.fromString(entry.key);
        if (day != null) {
          scheduleMap[day] = DaySchedule.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } else if (json['weeklySchedule'] is Map) {
      for (final entry in (json['weeklySchedule'] as Map<String, dynamic>).entries) {
        final day = DayOfWeek.fromString(entry.key);
        if (day != null) {
          scheduleMap[day] = DaySchedule.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    }

    return DoctorAvailability(
      id: json['id'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      weeklySchedule: scheduleMap,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: (json['isActive'] as int? ?? 1) == 1,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final scheduleJson = <String, dynamic>{};
    for (final entry in weeklySchedule.entries) {
      scheduleJson[entry.key.name] = entry.value.toJson();
    }

    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'weeklySchedule': jsonEncode(scheduleJson),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'notes': notes,
    };
  }

  DoctorAvailability copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    Map<DayOfWeek, DaySchedule>? weeklySchedule,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? notes,
  }) {
    return DoctorAvailability(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  /// Create a default schedule (Monday-Saturday, 7:30 AM - 4:30 PM)
  /// matching the current appointment system
  static DoctorAvailability createDefault({
    required String doctorId,
    required String doctorName,
  }) {
    final defaultSchedule = <DayOfWeek, DaySchedule>{};
    
    // Standard working days
    for (final day in [
      DayOfWeek.monday,
      DayOfWeek.tuesday,
      DayOfWeek.wednesday,
      DayOfWeek.thursday,
      DayOfWeek.friday,
      DayOfWeek.saturday,
    ]) {
      defaultSchedule[day] = DaySchedule.createStandardWorkingDay();
    }
    
    // Sunday off
    defaultSchedule[DayOfWeek.sunday] = DaySchedule.createDayOff();

    return DoctorAvailability(
      id: 'availability_${doctorId}_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      doctorName: doctorName,
      weeklySchedule: defaultSchedule,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      notes: 'Default schedule created',
    );
  }
}

class DaySchedule {
  final bool isAvailable;
  final TimeSlot? timeSlot;
  final String? notes;

  DaySchedule({
    required this.isAvailable,
    this.timeSlot,
    this.notes,
  });

  /// Get working hours for the day
  TimeSlot? getWorkingHours() {
    return isAvailable ? timeSlot : null;
  }

  /// Check if doctor is available at a specific time
  bool isAvailableAtTime(DateTime time) {
    if (!isAvailable || timeSlot == null) return false;
    
    final timeOnly = TimeSlot.fromDateTime(time);
    return timeSlot!.contains(timeOnly);
  }

  /// Get formatted time range for display
  String getFormattedTimeRange() {
    if (!isAvailable || timeSlot == null) {
      return 'Not Available';
    }
    return timeSlot!.formatTimeRange();
  }

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    // Handle backward compatibility with old format
    TimeSlot? convertedTimeSlot;
    
    if (json['timeSlot'] != null) {
      // New format - single time slot
      convertedTimeSlot = TimeSlot.fromJson(json['timeSlot'] as Map<String, dynamic>);
    } else if (json['morningShift'] != null || json['afternoonShift'] != null) {
      // Old format - convert morning/afternoon shifts to single slot
      TimeSlot? morning = json['morningShift'] != null 
          ? TimeSlot.fromJson(json['morningShift'] as Map<String, dynamic>)
          : null;
      TimeSlot? afternoon = json['afternoonShift'] != null 
          ? TimeSlot.fromJson(json['afternoonShift'] as Map<String, dynamic>)
          : null;
      
      if (morning != null && afternoon != null) {
        // Combine morning and afternoon into one continuous slot
        convertedTimeSlot = TimeSlot(
          startHour: morning.startHour,
          startMinute: morning.startMinute,
          endHour: afternoon.endHour,
          endMinute: afternoon.endMinute,
        );
      } else if (morning != null) {
        convertedTimeSlot = morning;
      } else if (afternoon != null) {
        convertedTimeSlot = afternoon;
      }
    }

    return DaySchedule(
      isAvailable: (json['isAvailable'] as bool?) ?? false,
      timeSlot: convertedTimeSlot,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAvailable': isAvailable,
      'timeSlot': timeSlot?.toJson(),
      'notes': notes,
    };
  }

  /// Create a standard working day (7:30 AM - 4:30 PM)
  static DaySchedule createStandardWorkingDay() {
    return DaySchedule(
      isAvailable: true,
      timeSlot: TimeSlot(
        startHour: 7,
        startMinute: 30,
        endHour: 16,
        endMinute: 30,
      ),
    );
  }

  /// Create a day off
  static DaySchedule createDayOff() {
    return DaySchedule(
      isAvailable: false,
      notes: 'Day off',
    );
  }

  /// Create a custom working day with specific hours
  static DaySchedule createCustomWorkingDay({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? notes,
  }) {
    return DaySchedule(
      isAvailable: true,
      timeSlot: TimeSlot(
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      ),
      notes: notes,
    );
  }
}

class TimeSlot {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  TimeSlot({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  /// Create TimeSlot from DateTime (time portion only)
  factory TimeSlot.fromDateTime(DateTime dateTime) {
    return TimeSlot(
      startHour: dateTime.hour,
      startMinute: dateTime.minute,
      endHour: dateTime.hour,
      endMinute: dateTime.minute,
    );
  }

  /// Check if this time slot contains a specific time
  bool contains(TimeSlot time) {
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    final timeMinutes = time.startHour * 60 + time.startMinute;
    
    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  /// Get duration in minutes
  int getDurationMinutes() {
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    return endMinutes - startMinutes;
  }

  /// Format as time range string
  String formatTimeRange() {
    return '${_formatTime(startHour, startMinute)} - ${_formatTime(endHour, endMinute)}';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startHour: json['startHour'] as int,
      startMinute: json['startMinute'] as int,
      endHour: json['endHour'] as int,
      endMinute: json['endMinute'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }
}

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get displayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }

  String get shortName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Mon';
      case DayOfWeek.tuesday:
        return 'Tue';
      case DayOfWeek.wednesday:
        return 'Wed';
      case DayOfWeek.thursday:
        return 'Thu';
      case DayOfWeek.friday:
        return 'Fri';
      case DayOfWeek.saturday:
        return 'Sat';
      case DayOfWeek.sunday:
        return 'Sun';
    }
  }

  /// Convert from DateTime.weekday
  static DayOfWeek fromDateTime(DateTime dateTime) {
    switch (dateTime.weekday) {
      case DateTime.monday:
        return DayOfWeek.monday;
      case DateTime.tuesday:
        return DayOfWeek.tuesday;
      case DateTime.wednesday:
        return DayOfWeek.wednesday;
      case DateTime.thursday:
        return DayOfWeek.thursday;
      case DateTime.friday:
        return DayOfWeek.friday;
      case DateTime.saturday:
        return DayOfWeek.saturday;
      case DateTime.sunday:
        return DayOfWeek.sunday;
      default:
        throw ArgumentError('Invalid weekday: ${dateTime.weekday}');
    }
  }

  /// Convert from string name
  static DayOfWeek? fromString(String name) {
    final lowerName = name.toLowerCase();
    for (final day in DayOfWeek.values) {
      if (day.name.toLowerCase() == lowerName ||
          day.displayName.toLowerCase() == lowerName ||
          day.shortName.toLowerCase() == lowerName) {
        return day;
      }
    }
    return null;
  }

  /// Get corresponding DateTime.weekday value
  int get dateTimeWeekday {
    switch (this) {
      case DayOfWeek.monday:
        return DateTime.monday;
      case DayOfWeek.tuesday:
        return DateTime.tuesday;
      case DayOfWeek.wednesday:
        return DateTime.wednesday;
      case DayOfWeek.thursday:
        return DateTime.thursday;
      case DayOfWeek.friday:
        return DateTime.friday;
      case DayOfWeek.saturday:
        return DateTime.saturday;
      case DayOfWeek.sunday:
        return DateTime.sunday;
    }
  }
}
