// Dashboard menu configuration and role management
import 'package:flutter/material.dart';
import '../../screens/user_management_screen.dart';
import '../../screens/registration/registration_hub_screen.dart';
import '../../screens/search/search_hub_screen.dart';
import '../../screens/laboratory/laboratory_hub_screen.dart';
import '../../screens/patient_queue/patient_queue_hub_screen.dart';
import '../../screens/appointments/appointment_overview_screen.dart';
import '../../screens/analytics/analytics_hub_screen.dart';
import '../../screens/reports/report_hub_screen.dart';
import '../../screens/billing/billing_hub_screen.dart';
import '../../screens/payment/payment_hub_screen.dart';
import '../../screens/maintenance/maintenance_hub_screen.dart';
import '../../screens/help/help_screen.dart';
import '../../screens/about_screen.dart';
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
      'screen': (String accessLevel) => const RegistrationHubScreen(),
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
    'Help': {
      'screen': (String accessLevel) => const HelpScreen(),
      'icon': Icons.help_outline
    },
    'About': {
      'screen': (String accessLevel) => const AboutScreen(),
      'icon': Icons.info_outline
    },
  };

  static final Map<String, List<String>> rolePermissions = {
    'admin': [
      'Registration',
      'Maintenance',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Appointment Schedule',
      'Analytics Hub',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'medtech': [
      'Dashboard',
      'Registration',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Appointment Schedule',
      'Analytics Hub',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'doctor': [
      'Dashboard',
      'Search',
      'Patient Laboratory Histories',
      'Patient Queue',
      'Appointment Schedule',
      'Analytics Hub',
      'Report',
      'Payment',
      'Billing',
      'Help',
      'About'
    ],
    'patient': ['Appointment Schedule', 'Help', 'About']
  };

  static MenuConfiguration configureMenuForRole(String accessLevel) {
    List<String> allowedMenuKeys =
        rolePermissions[accessLevel] ?? rolePermissions['patient']!;

    List<String> tempTitles = [];
    List<Widget> tempScreens = [];
    List<IconData> tempIcons = [];

    String dashboardKey = 'Dashboard';
    if (allMenuItems.containsKey(dashboardKey) &&
        allowedMenuKeys.contains(dashboardKey)) {
      bool prioritize =
          (accessLevel == 'medtech' || accessLevel == 'doctor');
      
      if (prioritize && !tempTitles.contains(dashboardKey)) {
        tempTitles.add(dashboardKey);
        tempScreens.add(allMenuItems[dashboardKey]!['screen'](accessLevel));
        tempIcons.add(allMenuItems[dashboardKey]!['icon']);
      }
    }

    for (String key in allMenuItems.keys) {
      if (tempTitles.contains(key)) continue;

      if (allowedMenuKeys.contains(key)) {
        tempTitles.add(key);
        tempScreens.add(allMenuItems[key]!['screen'](accessLevel));
        tempIcons.add(allMenuItems[key]!['icon']);
      }
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
