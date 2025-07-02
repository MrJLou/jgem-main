// Dashboard menu configuration and role management
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../screens/user_management_screen.dart';
import '../../screens/registration/registration_hub_screen.dart';
import '../../screens/registration/patient_registration_screen.dart';
import '../../screens/search/search_hub_screen.dart';
import '../../screens/laboratory/laboratory_hub_screen.dart';
import '../../screens/patient_queue/patient_queue_hub_screen.dart';
import '../../screens/appointments/appointment_overview_screen.dart';
import '../../screens/analytics/analytics_hub_screen.dart';
import '../../screens/reports/report_hub_screen.dart';
import '../../screens/billing/billing_hub_screen.dart';
import '../../screens/payment/payment_hub_screen.dart';
import '../../screens/maintenance/maintenance_hub_screen.dart';
import '../../screens/server_management_screen.dart';
import '../../screens/lan_connection_screen.dart';

import '../../screens/about_screen.dart';
import '../../debug_service_analytics_test.dart';

import '../../services/queue_service.dart';
import '../dashboard/live_queue_dashboard_view.dart';

class DashboardMenuConfig {
  static final Map<String, Map<String, dynamic>> allMenuItems = {
    'Dashboard': {
      'screen': (String accessLevel) => LiveQueueDashboardView(
          queueService: QueueService(), appointments: const []),
      'icon': Icons.dashboard_outlined
    },
    'Registration': {
      'screen': (String accessLevel) {
        if (kDebugMode) {
          print(
              'DEBUG: Registration screen factory called with accessLevel: "$accessLevel"');
        }
        if (accessLevel.trim().toLowerCase() == 'medtech') {
          if (kDebugMode) {
            print('DEBUG: Returning PatientRegistrationScreen for medtech');
          }
          return const PatientRegistrationScreen();
        }
        if (kDebugMode) {
          print('DEBUG: Returning RegistrationHubScreen for non-medtech role');
        }
        return const RegistrationHubScreen(); // For admin
      },
      'icon': Icons.app_registration
    },
    'User Management': {
      'screen': (String accessLevel) => const UserManagementScreen(),
      'icon': Icons.manage_accounts
    },
    'Maintenance': {
      'screen': (String accessLevel) => const MaintenanceHubScreen(),
      'icon': Icons.build_circle_outlined
    },
    'Search': {
      'screen': (String accessLevel) =>
          SearchHubScreen(accessLevel: accessLevel),
      'icon': Icons.search_outlined
    },
    'Patient Laboratory Histories': {
      'screen': (String accessLevel) => const LaboratoryHubScreen(),
      'icon': Icons.science_outlined
    },
    'Patient Queue': {
      'screen': (String accessLevel) =>
          PatientQueueHubScreen(accessLevel: accessLevel),
      'icon': Icons.groups_outlined
    },
    'Appointment Schedule': {
      'screen': (String accessLevel) => const AppointmentOverviewScreen(),
      'icon': Icons.calendar_month_outlined
    },

    'Analytics Hub': {
      'screen': (String accessLevel) => const AnalyticsHubScreen(),
      'icon': Icons.analytics_outlined
    },
    'Debug Service Analytics': {
      'screen': (String accessLevel) => const DebugServiceAnalyticsTest(),
      'icon': Icons.bug_report
    },
    'Report': {
      'screen': (String accessLevel) => const ReportHubScreen(),
      'icon': Icons.receipt_long_outlined
    },
    'Payment': {
      'screen': (String accessLevel) => const PaymentHubScreen(),
      'icon': Icons.payment_outlined
    },
    'Billing': {
      'screen': (String accessLevel) => const BillingHubScreen(),
      'icon': Icons.request_quote_outlined
    },

    'About': {
      'screen': (String accessLevel) => const AboutScreen(),
      'icon': Icons.info_outline
    },
    'Server Management': {
      'screen': (String accessLevel) => const ServerManagementScreen(),
      'icon': Icons.dns_outlined
    },
    'LAN Connection': {
      'screen': (String accessLevel) => const LanConnectionScreen(),
      'icon': Icons.wifi_outlined
    },
    '---': {
      'screen': (String accessLevel) =>
          const SizedBox.shrink(), // No screen for a divider
      'icon': Icons.horizontal_rule, // No icon for a divider
    }
  };

  static final Map<String, List<String>> rolePermissions = {
    'admin': [
      'Registration',
      'Maintenance',
      '---',
      'Search',
      'Patient Laboratory Histories',
      '---',
      'Patient Queue',
      'Appointment Schedule',
      '---',
      'Analytics Hub',
      'Debug Service Analytics',
      'Report',
      'Payment',
      'Billing',
      '---',
      'Server Management',
      '---',
      'About'
    ],
    'medtech': [
      'Dashboard',
      '---',
      'Registration',
      'Search',
      'Patient Laboratory Histories',
      '---',
      'Patient Queue',
      'Appointment Schedule',
      'Doctor Availability',
      '---',
      'Analytics Hub',
      'Report',
      'Payment',
      'Billing',
      '---',
      'LAN Connection',
      '---',
      'About'
    ],
    'doctor': [
      'Dashboard',
      '---',
      'Search',
      'Patient Laboratory Histories',
      '---',
      'Patient Queue',
      'Appointment Schedule',
      'Doctor Availability',
      '---',
      'Analytics Hub',
      'Report',
      'Payment',
      'Billing',
      '---',
      'LAN Connection',
      '---',
      'About'
    ],
  };
  static MenuConfiguration configureMenuForRole(String accessLevel) {
    if (kDebugMode) {
      print(
          'DEBUG: configureMenuForRole called with accessLevel: "$accessLevel"');
    }
    List<String> allowedMenuKeys = rolePermissions[accessLevel] ?? [];
    if (kDebugMode) {
      print('DEBUG: allowedMenuKeys for $accessLevel: $allowedMenuKeys');
    }

    List<String> tempTitles = [];
    List<Widget> tempScreens = [];
    List<IconData> tempIcons = [];

    String dashboardKey = 'Dashboard';
    if (allMenuItems.containsKey(dashboardKey) &&
        allowedMenuKeys.contains(dashboardKey)) {
      bool prioritize = (accessLevel == 'medtech' || accessLevel == 'doctor');

      if (prioritize && !tempTitles.contains(dashboardKey)) {
        tempTitles.add(dashboardKey);
        tempScreens.add(allMenuItems[dashboardKey]!['screen'](accessLevel));
        tempIcons.add(allMenuItems[dashboardKey]!['icon']);
      }
    }

    for (String key in allMenuItems.keys) {
      if (tempTitles.contains(key)) continue;

      if (allowedMenuKeys.contains(key)) {
        if (kDebugMode) {
          print('DEBUG: Adding menu item: $key');
        }
        tempTitles.add(key);
        tempScreens.add(allMenuItems[key]!['screen'](accessLevel));
        tempIcons.add(allMenuItems[key]!['icon']);
      }
    }

    if (kDebugMode) {
      print('DEBUG: Final menu titles: $tempTitles');
    }
    return MenuConfiguration(
      titles: tempTitles,
      screens: tempScreens,
      icons: tempIcons,
    );
  }
}

class MenuConfiguration {
  final List<String> titles;
  final List<Widget> screens;
  final List<IconData> icons;

  MenuConfiguration({
    required this.titles,
    required this.screens,
    required this.icons,
  });
}
