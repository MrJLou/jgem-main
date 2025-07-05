# Today Doctor Feature

## Overview

The "Today Doctor" feature provides a comprehensive system for managing and displaying doctor availability by day of the week. This feature allows clinic staff to quickly see which doctors are available today, their schedules, specializations, and locations.

## Components

### 1. Models

#### `doctor_availability.dart`
- **DoctorAvailability**: Main model containing weekly schedules for doctors
- **DaySchedule**: Represents a doctor's schedule for a specific day
- **TimeSlot**: Represents time intervals within a day
- **DayOfWeek**: Enum for days of the week with utility methods

### 2. Services

#### `doctor_availability_service.dart`
- **DoctorAvailabilityService**: Main service for managing doctor availability
- Provides methods for:
  - Getting today's available doctors
  - Checking doctor availability at specific times
  - Managing doctor schedules
  - Finding next available appointment slots

### 3. UI Components

#### `widgets/dashboard/today_doctor_widget.dart`
- **TodayDoctorWidget**: Reusable widget showing doctor availability
- Two modes:
  - **Compact**: For dashboard integration
  - **Full**: For standalone screens
- Shows availability summary, specialization counts, and doctor details

#### `screens/doctor_availability/today_doctor_screen.dart`
- **TodayDoctorScreen**: Full-featured screen for managing doctor availability
- Two tabs:
  - **Today's Doctors**: Shows doctors available for selected date
  - **Weekly Schedule**: Overview of all doctors' weekly availability

### 4. Database Schema

The feature uses the existing `doctor_availability` table:

```sql
CREATE TABLE doctor_availability (
  id TEXT PRIMARY KEY,
  doctorId TEXT NOT NULL,
  doctorName TEXT NOT NULL,
  weeklySchedule TEXT NOT NULL, -- JSON string of DayOfWeek -> DaySchedule
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  isActive INTEGER DEFAULT 1,
  notes TEXT,
  FOREIGN KEY (doctorId) REFERENCES users (id)
);
```

## Features

### Current Implementation

1. **Doctor Availability Display**
   - Shows available doctors for today or any selected date
   - Displays working hours, specializations, and locations
   - Color-coded availability status

2. **Dashboard Integration**
   - Compact widget integrated into the main dashboard
   - Quick access to today's doctor information
   - Navigation to full doctor availability screen

3. **Weekly Overview**
   - View doctor schedules for entire week
   - Expandable day cards showing availability details
   - Easy navigation between days

4. **Default Schedule Management**
   - Automatic creation of default schedules for existing doctors
   - Standard working hours: Monday-Saturday, 7:30 AM - 4:30 PM
   - Sunday marked as day off

5. **Menu Integration**
   - Added "Doctor Availability" to main navigation menu
   - Available for 'medtech' and 'doctor' roles
   - Positioned logically after "Appointment Schedule"

### Data Structure

#### Default Doctor Schedule
- **Working Days**: Monday through Saturday
- **Working Hours**: 7:30 AM to 4:30 PM
- **Day Off**: Sunday
- **Specialty**: General
- **Location**: Main Clinic

#### Schedule Configuration
Each doctor has a weekly schedule with:
- Day-specific availability (true/false)
- Multiple time slots per day (morning/afternoon shifts)
- Break times within shifts
- Specialty assignments per day
- Location assignments per day
- Notes for special arrangements

## Usage

### For Dashboard Users
1. View "Today's Doctors" section on main dashboard
2. See availability summary and specialization counts
3. Click "View All" to access full doctor availability screen

### For Detailed Management
1. Navigate to "Doctor Availability" from main menu
2. Use "Today's Doctors" tab for current day information
3. Use "Weekly Schedule" tab for week overview
4. Use date picker to view availability for future dates

### For Developers
```dart
// Get today's available doctors
final availableDoctors = await DoctorAvailabilityService.getTodayAvailableDoctors();

// Check specific doctor availability
final isAvailable = await DoctorAvailabilityService.isDoctorAvailableAt(
  doctorId, 
  DateTime.now()
);

// Get next available slot for a doctor
final nextSlot = await DoctorAvailabilityService.getNextAvailableSlot(doctorId);
```

## Future Enhancements

### Planned Features
1. **Individual Doctor Schedule Management**
   - Edit individual doctor schedules
   - Set vacation/holiday periods
   - Manage multiple shifts per day

2. **Advanced Scheduling**
   - Room/location assignments
   - Equipment requirements
   - Break time management
   - Appointment slot customization

3. **Integration Features**
   - Appointment booking based on availability
   - Conflict detection during scheduling
   - Real-time availability updates
   - Notification system for schedule changes

4. **Reporting & Analytics**
   - Doctor utilization reports
   - Availability analytics
   - Schedule optimization suggestions
   - Patient wait time analysis

### Extensibility Points
- **Multiple Shifts**: Extend `DaySchedule` to support multiple non-contiguous shifts
- **Recurring Patterns**: Add support for rotating schedules
- **Holiday Management**: Integration with holiday calendar
- **Specialty Scheduling**: Different schedules based on doctor specializations
- **Room Management**: Integration with room/equipment availability

## Integration Points

### With Existing Systems
- **Appointment System**: Uses doctor availability for slot generation
- **User Management**: Syncs with doctor user accounts
- **Dashboard**: Integrated via `DashboardDoctorsSection`
- **Menu System**: Added to role-based navigation

### Database Relationships
- Links to `users` table via `doctorId`
- Compatible with existing appointment scheduling
- Supports backup/restore system (excludes session data)

## Technical Notes

### Performance Considerations
- Schedules cached in memory for quick access
- Database queries optimized with indexes on `doctorId` and `isActive`
- Compact JSON storage for weekly schedules

### Error Handling
- Graceful degradation when availability data unavailable
- Default schedule creation for new doctors
- Validation of time slot overlaps and conflicts

### Maintainability
- Modular design with clear separation of concerns
- Comprehensive documentation and code comments
- Consistent naming conventions and patterns
- Easy to extend with additional features

## Testing Recommendations

1. **Unit Tests**
   - Doctor availability logic
   - Time slot calculations
   - Schedule validation

2. **Integration Tests**
   - Database operations
   - API service integration
   - UI component rendering

3. **User Acceptance Tests**
   - Dashboard integration workflow
   - Doctor schedule management
   - Appointment booking flow

This feature provides a solid foundation for doctor availability management while maintaining compatibility with the existing clinic management system.
