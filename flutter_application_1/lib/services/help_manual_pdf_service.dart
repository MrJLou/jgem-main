import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class HelpManualPdfService {
  /// Generate a comprehensive help manual PDF
  static Future<Uint8List> generateHelpManualPdf() async {
    try {
      final pdf = pw.Document();
      final coverImage = pw.MemoryImage(
        (await rootBundle.load('assets/images/slide1.png')).buffer.asUint8List(),
      );

      // Add pages to the PDF
      pdf.addPage(_buildCoverPage(coverImage));
      pdf.addPage(_buildTableOfContentsPage());
      pdf.addPage(_buildSystemOverviewPage());
      pdf.addPage(_buildGettingStartedPage());
      pdf.addPage(_buildUserGuidelinesPage());
      pdf.addPage(_buildPatientManagementPage());
      pdf.addPage(_buildAppointmentsPage());
      pdf.addPage(_buildReportsPage());
      pdf.addPage(_buildEnhancedFAQPage());
      pdf.addPage(_buildTroubleshootingPage());
      pdf.addPage(_buildSecurityGuidelinesPage());

      return pdf.save();
    } catch (e) {
      if (kDebugMode) {
        print('Error generating help manual PDF: $e');
      }
      rethrow;
    }
  }

  /// Print the help manual
  static Future<void> printHelpManual() async {
    try {
      final pdfBytes = await generateHelpManualPdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'J-Gem_Medical_User_Manual.pdf',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error printing help manual: $e');
      }
      rethrow;
    }
  }

  /// Save the help manual to device
  static Future<void> saveHelpManual() async {
    try {
      final pdfBytes = await generateHelpManualPdf();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'J-Gem_Medical_User_Manual.pdf',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving help manual: $e');
      }
      rethrow;
    }
  }

  // Cover page
  static pw.Page _buildCoverPage(pw.MemoryImage coverImage) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(
              width: 200,
              height: 200,
              child: pw.Image(coverImage),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'J-Gem Medical and Diagnostic Clinic',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'USER MANUAL',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'Patient Record Management System',
              style: const pw.TextStyle(
                fontSize: 16,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 80),
            pw.Text(
              'Version 2.0',
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey500,
              ),
            ),
          ],
        );
      },
    );
  }

  // Table of contents
  static pw.Page _buildTableOfContentsPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('Table of Contents'),
            pw.SizedBox(height: 30),
            _buildTOCItem('1. System Overview', 3),
            _buildTOCItem('2. Getting Started', 4),
            _buildTOCItem('   2.1 Login and Authentication', 4),
            _buildTOCItem('   2.2 User Roles and Permissions', 4),
            _buildTOCItem('   2.3 Dashboard Navigation', 4),
            _buildTOCItem('3. User Guidelines', 5),
            _buildTOCItem('   3.1 Best Practices', 5),
            _buildTOCItem('   3.2 Data Entry Standards', 5),
            _buildTOCItem('   3.3 Workflow Guidelines', 5),
            _buildTOCItem('4. Patient Management', 6),
            _buildTOCItem('   4.1 Patient Registration', 6),
            _buildTOCItem('   4.2 Patient Search', 6),
            _buildTOCItem('   4.3 Patient Records', 6),
            _buildTOCItem('5. Appointments', 7),
            _buildTOCItem('   5.1 Scheduling Appointments', 7),
            _buildTOCItem('   5.2 Managing Calendar', 7),
            _buildTOCItem('6. Reports and Analytics', 8),
            _buildTOCItem('   6.1 Generating Reports', 8),
            _buildTOCItem('   6.2 Data Export', 8),
            _buildTOCItem('7. Frequently Asked Questions', 9),
            _buildTOCItem('8. Troubleshooting', 10),
            _buildTOCItem('9. Security Guidelines', 11),
          ],
        );
      },
    );
  }

  // System overview page
  static pw.Page _buildSystemOverviewPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('1. System Overview'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Introduction'),
            _buildParagraph(
              'J-Gem Medical and Diagnostic Clinic Patient Management System is a comprehensive '
              'solution designed to streamline medical practice operations. The system provides '
              'tools for patient registration, appointment scheduling, medical records management, '
              'billing, and reporting.',
            ),
            pw.SizedBox(height: 15),
            _buildSectionTitle('Key Features'),
            _buildNumberedListItem('Patient registration and management', 1),
            _buildNumberedListItem('Appointment scheduling and calendar management', 2),
            _buildNumberedListItem('Medical records and laboratory results tracking', 3),
            _buildNumberedListItem('Billing and payment processing', 4),
            _buildNumberedListItem('Reports and analytics', 5),
            _buildNumberedListItem('Multi-user support with role-based access', 6),
            _buildNumberedListItem('Real-time data synchronization across devices', 7),
            pw.SizedBox(height: 15),
            _buildSectionTitle('System Requirements'),
            _buildNumberedListItem('Windows 10 or 11 system', 1),
            _buildNumberedListItem('Internet connection for cloud synchronization', 2),
            _buildNumberedListItem('Local network (LAN) for multi-device access', 3),
            _buildNumberedListItem('Minimum 8GB of RAM, and at least 500GB of storage', 4),
          ],
        );
      },
    );
  }

  // Getting started page
  static pw.Page _buildGettingStartedPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('2. Getting Started'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('2.1 Login and Authentication'),
            _buildParagraph(
              'To access the system, enter your username and password on the login screen. '
              'The system enforces single-device login for security purposes.',
            ),
            pw.SizedBox(height: 10),
            _buildSectionTitle('2.2 User Roles and Permissions'),
            _buildSubsection('Administrator/Admin'),
            _buildNumberedListItem('Full system access and configuration', 1),
            _buildNumberedListItem('User management and role assignment', 2),
            _buildNumberedListItem('System maintenance and server management', 3),
            _buildSubsection('Medical Technologist'),
            _buildNumberedListItem('Access to laboratory and diagnostic modules', 1),
            _buildNumberedListItem('Manages test requests and results', 2),
            _buildNumberedListItem('Maintains appointment and queue', 3),
            _buildSubsection('Doctor'),
            _buildNumberedListItem('Access to patient records and medical history', 1),
            _buildNumberedListItem('Manages patient consultations and treatments', 2),
            _buildNumberedListItem('Creates and manages patient schedules', 3),
            pw.SizedBox(height: 10),
            _buildSectionTitle('2.3 Dashboard Navigation'),
            _buildParagraph(
              'The main dashboard provides quick access to all system modules. The sidebar menu is customized based on the user\'s role, ensuring that users only see the functions relevant to their responsibilities.'
            ),
          ],
        );
      },
    );
  }

  // Patient management page
  static pw.Page _buildPatientManagementPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('4. Patient Management'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('4.1 Patient Registration'),
            _buildParagraph(
              'To register a new patient, navigate to the "Patient" section and click "Add New Patient". Fill in the required information, including personal details, contact information, and emergency contacts. When selecting the date of birth, you can choose any date within the allowed year range (patients must be at least 5 years old). The date picker allows you to select any month and day within the valid year - for example, if the oldest allowed birth year is 2020, you can select any date from January 1, 2020 to December 31, 2020. Ensure all data is accurate and complete.',
            ),
            pw.SizedBox(height: 10),
            _buildSectionTitle('4.2 Patient Search'),
            _buildParagraph(
              'The system provides a powerful search function to quickly find patient records. You can search by name, patient ID, or other identifiers. The search results are displayed in a clear and organized manner.',
            ),
            pw.SizedBox(height: 10),
            _buildSectionTitle('4.3 Patient Records'),
            _buildParagraph(
              'Each patient has a comprehensive digital record that includes:',
            ),
            _buildNumberedListItem('Demographic information', 1),
            _buildNumberedListItem('Medical history and allergies', 2),
            _buildNumberedListItem('Consultation notes and diagnoses', 3),
            _buildNumberedListItem('Laboratory results (duplicates automatically filtered - only actual lab values from "LAB-ONLY" entries are shown)', 4),
            _buildNumberedListItem('Queuing reports', 5),
            _buildNumberedListItem('Billing and payment history', 6),
          ],
        );
      },
    );
  }

  // Appointments page
  static pw.Page _buildAppointmentsPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('5. Appointments'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('5.1 Scheduling Appointments'),
            _buildParagraph(
              'Appointments can be scheduled through the "Appointments" module. Select a date and time, choose the doctor, and link the appointment to a patient record. The system checks for scheduling conflicts to avoid double booking.',
            ),
            pw.SizedBox(height: 10),
            _buildSectionTitle('5.2 Managing Calendar'),
            _buildParagraph(
              'The interactive calendar provides a visual overview of all scheduled appointments. Users can view the calendar by day, week, or month. It also supports color-coding for different appointment types or statuses.',
            ),
          ],
        );
      },
    );
  }

  // Reports page
  static pw.Page _buildReportsPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('6. Reports and Analytics'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('6.1 Generating Reports'),
            _buildParagraph(
              'The system offers a variety of standard reports, including:',
            ),
            _buildNumberedListItem('Daily, weekly, and monthly patient visits', 1),
            _buildNumberedListItem('Financial reports (revenue, billing, payments)', 2),
            _buildNumberedListItem('Laboratory test volume and turnaround time', 3),
            _buildNumberedListItem('Patient demographics and statistics', 4),
            _buildNumberedListItem('Generate queue reports', 5),
            pw.SizedBox(height: 10),
            _buildSectionTitle('6.2 Data Export'),
            _buildParagraph(
              'Reports can be exported to PDF formats for further analysis or sharing. The data export function is designed to be flexible and user-friendly.',
            ),
          ],
        );
      },
    );
  }

  // Enhanced FAQ page
  static pw.Page _buildEnhancedFAQPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('7. Frequently Asked Questions'),
            pw.SizedBox(height: 20),
            _buildFAQItem(
              'Q: How do I reset my password?',
              'A: Contact your system administrator to reset your password. For security reasons, '
              'password resets must be performed by authorized personnel.',
            ),
            _buildFAQItem(
              'Q: Why can\'t I log in from multiple devices?',
              'A: The system enforces single-device login for security. To log in from a new device, '
              'you must first log out from the current device or use force login option.',
            ),
            _buildFAQItem(
              'Q: How do I backup patient data?',
              'A: Data backup is performed automatically. Administrators can also create manual '
              'backups through the Maintenance section.',
            ),
            _buildFAQItem(
              'Q: What happens if I enter data while offline?',
              'A: The application supports offline data entry. Any data entered while offline will be automatically synchronized with the server when connection is restored.',
            ),
            _buildFAQItem(
              'Q: How do I set up the LAN connection for other devices?',
              'A: The main device acts as a host, and other devices connect using the provided IP address and access code.',
            ),
            _buildFAQItem(
              'Q: Can I customize the reports?',
              'A: Yes, reports can be filtered by date range, patient, and other parameters. Custom reports can be created by administrators.',
            ),
            _buildFAQItem(
              'Q: Who can merge patient data?',
              'A: Only users with administrative privileges have permission to merge patient data.',
            ),
            _buildFAQItem(
              'Q: Why do I see only one laboratory result when there should be multiple?',
              'A: The system automatically filters duplicate laboratory results to show only the actual lab values entered by medical technologists (labeled as "LAB-ONLY"). Payment placeholder records (labeled as "Laboratory Only") are automatically hidden to prevent confusion.',
            ),
            _buildFAQItem(
              'Q: Why can\'t I select certain months when entering a patient\'s date of birth?',
              'A: The date picker allows you to select any month and day within the valid birth year range. Patients must be at least 5 years old, so you can select any date within the allowed years (e.g., any date in 2020 if that\'s the oldest valid year).',
            ),
          ],
        );
      },
    );
  }

  // Troubleshooting page
  static pw.Page _buildTroubleshootingPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('8. Troubleshooting'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Common Issues and Solutions'),
            pw.SizedBox(height: 15),
            _buildTroubleshootingItem(
              'System is running slowly',
              [
                'Check internet connection speed',
                'Close unnecessary applications',
                'Restart the application',
                'Contact administrator if issue persists',
              ],
            ),
            _buildTroubleshootingItem(
              'Cannot connect to server',
              [
                'Verify server IP address and port',
                'Check network connectivity',
                'Ensure correct access code',
                'Contact administrator for server status',
              ],
            ),
            _buildTroubleshootingItem(
              'Data is not syncing',
              [
                'Check LAN connection status',
                'Verify server is running',
                'Try manual sync from connection screen',
                'Restart both client and server applications',
              ],
            ),
            _buildTroubleshootingItem(
              'Cannot print reports',
              [
                'Check printer connection and drivers',
                'Verify printer is set as default',
                'Try printing from a different application',
                'Contact IT support for printer issues',
              ],
            ),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Support Contact'),
            _buildParagraph(
              'For technical support beyond this manual, contact your system administrator '
              'or IT support team. Keep your user ID and error messages ready when '
              'requesting assistance.',
            ),
          ],
        );
      },
    );
  }

  // Helper methods for PDF building
  static pw.Widget _buildPageHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.teal700, width: 2),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.teal700,
        ),
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      ),
    );
  }

  static pw.Widget _buildSubsection(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  static pw.Widget _buildParagraph(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  static pw.Widget _buildNumberedListItem(String text, int number) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 20, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$number. ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTOCItem(String title, int page) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(page.toString(), style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildFAQItem(String question, String answer) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            question,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal700,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            answer,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTroubleshootingItem(String issue, List<String> solutions) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            issue,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red700,
            ),
          ),
          pw.SizedBox(height: 5),
          ...solutions.asMap().entries.map((entry) {
            int idx = entry.key;
            String solution = entry.value;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 15, bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${idx + 1}. ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Expanded(
                    child: pw.Text(
                      solution,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // User Guidelines page
  static pw.Page _buildUserGuidelinesPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('3. User Guidelines'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('3.1 Best Practices'),
            _buildNumberedListItem('Always log out of the system when not in use to protect patient data.', 1),
            _buildNumberedListItem('Regularly update your password and follow the clinic\'s security policies.', 2),
            _buildNumberedListItem('Verify patient identity before accessing or updating their records.', 3),
            _buildNumberedListItem('Report any system issues or suspicious activity to the administrator immediately.', 4),
            pw.SizedBox(height: 15),
            _buildSectionTitle('3.2 Data Entry Standards'),
            _buildNumberedListItem('Enter data accurately and consistently. Use standardized formats for names, dates, and addresses.', 1),
            _buildNumberedListItem('Avoid using abbreviations or jargon that may not be universally understood.', 2),
            _buildNumberedListItem('Double-check all entries for typos and errors before saving.', 3),
            pw.SizedBox(height: 15),
            _buildSectionTitle('3.3 Workflow Guidelines'),
            _buildNumberedListItem('Follow the established workflows for patient registration, appointment scheduling, and billing.', 1),
            _buildNumberedListItem('Ensure that all required fields are completed in each step of the process.', 2),
            _buildNumberedListItem('Communicate effectively with other team members to ensure smooth patient flow.', 3),
          ],
        );
      },
    );
  }

  // Security Guidelines page
  static pw.Page _buildSecurityGuidelinesPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('9. Security Guidelines'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Password Policy'),
            _buildNumberedListItem('Use strong, unique passwords for your system account.', 1),
            _buildNumberedListItem('Change your password every 90 days (optional).', 2),
            _buildNumberedListItem('Do not share your login credentials with anyone.', 3),
            pw.SizedBox(height: 15),
            _buildSectionTitle('Data Privacy'),
            _buildNumberedListItem('Access patient information only for legitimate, job-related purposes.', 1),
            _buildNumberedListItem('Do not disclose any patient information to unauthorized individuals.', 2),
            _buildNumberedListItem('Follow all relevant data privacy regulations, such as HIPAA.', 3),
            pw.SizedBox(height: 15),
            _buildSectionTitle('System Access'),
            _buildNumberedListItem('Log out of the system when you are away from your workstation.', 1),
            _buildNumberedListItem('Be aware of your surroundings to prevent shoulder surfing.', 2),
            _buildNumberedListItem('Report any lost or stolen devices to the administrator immediately.', 3),
          ],
        );
      },
    );
  }
}
