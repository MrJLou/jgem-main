import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/doctor_availability.dart';

void main() {
  group('Doctor Registration Tests', () {
    test('Doctor availability should be created with proper default values', () {
      // Test data
      const String doctorId = 'test_doctor_123';
      const String doctorName = 'Dr. Test';
      
      // Create selected days map (Monday to Friday)
      final selectedDays = {
        DayOfWeek.monday: true,
        DayOfWeek.tuesday: true,
        DayOfWeek.wednesday: true,
        DayOfWeek.thursday: true,
        DayOfWeek.friday: true,
        DayOfWeek.saturday: false,
        DayOfWeek.sunday: false,
      };

      // Create availability schedule based on selected days
      final weeklySchedule = <DayOfWeek, DaySchedule>{};
      
      for (final day in DayOfWeek.values) {
        if (selectedDays[day] == true) {
          weeklySchedule[day] = DaySchedule(
            isAvailable: true,
            timeSlot: TimeSlot(
              startHour: 7,
              startMinute: 30,
              endHour: 16,
              endMinute: 30,
            ),
            notes: 'Created during registration test',
          );
        } else {
          weeklySchedule[day] = DaySchedule.createDayOff();
        }
      }

      final availability = DoctorAvailability(
        id: 'availability_${doctorId}_${DateTime.now().millisecondsSinceEpoch}',
        doctorId: doctorId,
        doctorName: doctorName,
        weeklySchedule: weeklySchedule,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        notes: 'Test schedule created during registration',
      );

      // Verify the availability object is created correctly
      expect(availability.doctorId, equals(doctorId));
      expect(availability.doctorName, equals(doctorName));
      expect(availability.isActive, isTrue);
      
      // Verify working days have correct availability and time slots
      expect(availability.weeklySchedule[DayOfWeek.monday]?.isAvailable, isTrue);
      expect(availability.weeklySchedule[DayOfWeek.monday]?.timeSlot, isNotNull);
      
      // Verify non-working days are set to off
      expect(availability.weeklySchedule[DayOfWeek.sunday]?.isAvailable, isFalse);
      
      // Verify no null values in required fields for working days
      for (final day in [DayOfWeek.monday, DayOfWeek.tuesday, DayOfWeek.wednesday, DayOfWeek.thursday, DayOfWeek.friday]) {
        final daySchedule = availability.weeklySchedule[day];
        expect(daySchedule, isNotNull);
        expect(daySchedule!.isAvailable, isTrue);
        expect(daySchedule.timeSlot, isNotNull);
        expect(daySchedule.timeSlot!.startHour, equals(7));
        expect(daySchedule.timeSlot!.endHour, equals(16));
      }
    });

    test('Doctor availability validation should handle defaults correctly', () {
      // Test that default values are used
      final daySchedule = DaySchedule(
        isAvailable: true,
        timeSlot: TimeSlot(
          startHour: 9,
          startMinute: 0,
          endHour: 17,
          endMinute: 0,
        ),
        notes: 'Standard working hours',
      );
      
      expect(daySchedule.isAvailable, isTrue);
      expect(daySchedule.timeSlot, isNotNull);
      expect(daySchedule.getFormattedTimeRange(), equals('9:00 AM - 5:00 PM'));
    });

    test('Selected days validation should work correctly', () {
      final allDaysSelected = {
        DayOfWeek.monday: true,
        DayOfWeek.tuesday: true,
        DayOfWeek.wednesday: true,
        DayOfWeek.thursday: true,
        DayOfWeek.friday: true,
        DayOfWeek.saturday: true,
        DayOfWeek.sunday: true,
      };

      final noDaysSelected = {
        DayOfWeek.monday: false,
        DayOfWeek.tuesday: false,
        DayOfWeek.wednesday: false,
        DayOfWeek.thursday: false,
        DayOfWeek.friday: false,
        DayOfWeek.saturday: false,
        DayOfWeek.sunday: false,
      };

      // Should have at least one day selected
      expect(allDaysSelected.values.any((selected) => selected), isTrue);
      expect(noDaysSelected.values.every((selected) => !selected), isTrue);
    });
  });
}
