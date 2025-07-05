import 'dart:io';
import 'dart:convert'; // Added for jsonEncode

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/bill_item.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/screens/billing/widgets/generated_invoice_view.dart';
import 'package:flutter_application_1/screens/billing/widgets/in_consultation_patient_list.dart';
import 'package:flutter_application_1/screens/billing/widgets/lab_or_consultation_view.dart';
import 'package:flutter_application_1/screens/billing/widgets/payment_processing_view.dart';
import 'package:flutter_application_1/screens/billing/widgets/prepare_invoice_view.dart';
import 'package:flutter_application_1/screens/patient_queue/view_queue_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/pdf_invoice_service.dart';
import 'package:flutter_application_1/services/queue_service.dart';
import 'package:flutter_application_1/services/receipt_service.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

enum InvoiceFlowStep {
  patientSelection,
  labOrConsultation,
  invoiceGenerated,
  paymentProcessing,
  paymentComplete
}

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  InvoiceScreenState createState() => InvoiceScreenState();
}

class InvoiceScreenState extends State<InvoiceScreen> {
  // State Variables
  List<ActivePatientQueueItem> _inConsultationPatients = [];
  ActivePatientQueueItem? _selectedPatientQueueItem;
  Patient? _detailedPatientForInvoice;
  InvoiceFlowStep _currentStep = InvoiceFlowStep.patientSelection;

  // Loading and User Info
  bool _isLoadingPatients = true;
  String? _currentUserId;

  // Invoice and Payment Data
  String? _generatedInvoiceNumber;
  List<BillItem> _currentBillItems = [];
  DateTime? _invoiceDate;
  Uint8List? _generatedPdfBytes;
  Uint8List? _generatedReceiptBytes;
  final TextEditingController _amountPaidController = TextEditingController();
  double _paymentChange = 0.0;
  String? _paymentReferenceNumber;
  
  // Lab Results and Consultation Data
  final TextEditingController _consultationNotesController = TextEditingController();
  final TextEditingController _chiefComplaintController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();
  String _consultationType = 'General Consultation';
  final Map<String, Map<String, TextEditingController>> _labResultControllers = {};
  final Map<String, bool> _selectedLabTests = {};
  bool _isProcessingLabResults = false;
  bool _isLabTest = true; // Track whether we're in lab test or consultation mode

  // Button loading states
  bool _isGeneratingInvoice = false;
  bool _isProcessingPayment = false;
  bool _isSavingUnpaid = false;

  // Services and Helpers
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();
  final PdfInvoiceService _pdfInvoiceService = PdfInvoiceService();
  final Uuid _uuid = const Uuid();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_PH', symbol: '₱');

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _fetchInConsultationPatients();
  }
  
  @override
  void dispose() {
    // Dispose of all controllers to prevent memory leaks
    _amountPaidController.dispose();
    _consultationNotesController.dispose();
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _prescriptionController.dispose();
    for (var map in _labResultControllers.values) {
      for (var controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  // --- DATA FETCHING AND STATE MANAGEMENT ---

  Future<void> _loadCurrentUserId() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      setState(() => _currentUserId = user.id);
    }
  }

  Future<void> _fetchInConsultationPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _selectedPatientQueueItem = null;
      _currentStep = InvoiceFlowStep.patientSelection;
      _resetInvoiceAndPaymentState();
    });
    try {
      final patients =
          await _dbHelper.getActiveQueue(statuses: ['in_consultation']);
      final validPatients = patients
          .where((p) => p.totalPrice != null && p.totalPrice! > 0)
          .toList();
      setState(() => _inConsultationPatients = validPatients);
    } catch (e, s) {
      if (kDebugMode) print('Error fetching patients: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching patients: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  Future<void> _fetchPatientDetails(String? patientId) async {
    if (patientId == null || patientId.isEmpty) {
      setState(() => _detailedPatientForInvoice = null);
      return;
    }
    try {
      final patientDataMap = await _dbHelper.getPatient(patientId);
      if (mounted && patientDataMap != null) {
        setState(() =>
            _detailedPatientForInvoice = Patient.fromJson(patientDataMap));
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching patient details: $e");
    }
  }

  void _resetInvoiceAndPaymentState() {
    setState(() {
      _generatedInvoiceNumber = null;
      _currentBillItems = [];
      _invoiceDate = null;
      _generatedPdfBytes = null;
      _generatedReceiptBytes = null;
      _amountPaidController.clear();
      _paymentChange = 0.0;
      _paymentReferenceNumber = null;
      _consultationNotesController.clear();
      _chiefComplaintController.clear();
      _diagnosisController.clear();
      _prescriptionController.clear();
      _labResultControllers.clear();
      _selectedLabTests.clear();
      _isProcessingLabResults = false;
    });
  }

  // --- CORE BUSINESS LOGIC ---

  void _generateInvoice() async {
    if (_selectedPatientQueueItem == null) return;
    setState(() => _isGeneratingInvoice = true);
    try {
      final patientQueueItem = _selectedPatientQueueItem!;

      final invoiceNumber = 'INV-${_uuid.v4().substring(0, 6).toUpperCase()}';
      final now = DateTime.now();
      final List<BillItem> items =
          _buildBillItems(patientQueueItem, invoiceNumber);
          
      // Add lab results or consultation notes to the invoice if they were entered
      if (_selectedLabTests.isNotEmpty) {
        // Process selected lab tests results
        _selectedLabTests.forEach((testKey, isSelected) {
          if (isSelected) {
            final controller = _labResultControllers[testKey]?['result'];
            if (controller != null) {
              items.add(BillItem(
                billId: invoiceNumber,
                description: '$testKey Test Results',
                quantity: 1,
                unitPrice: 0.0, // Price already included in the main service
                itemTotal: 0.0,
                notes: '$testKey Level: ${controller.text}',
              ));
            }
          }
        });
      } else if (_consultationNotesController.text.isNotEmpty) {
        // For consultation, add the notes to the bill items in a more structured way
        
        // Find consultation service in the patient's selected services
        final consultationService = patientQueueItem.selectedServices?.firstWhere(
          (service) => (service['category'] as String?)?.toLowerCase() == 'consultation' || 
                      (service['name'] as String?)?.toLowerCase().contains('consult') == true,
          orElse: () => {'name': 'Consultation', 'id': 'general_consultation'},
        );
        
        final serviceName = consultationService?['name'] as String? ?? 'Consultation';
        
        // Add consultation notes to bill items
        items.add(BillItem(
          billId: invoiceNumber,
          description: '$serviceName - Medical Notes',
          quantity: 1,
          unitPrice: 0.0, // Price already included in the main service
          itemTotal: 0.0,
          notes: 'Findings and Recommendations:\n${_consultationNotesController.text}',
          serviceId: consultationService?['id'] as String?,
        ));
      }

      final pdfBytes = await _pdfInvoiceService.generateInvoicePdf(
        queueItem: patientQueueItem,
        patientDetails: _detailedPatientForInvoice,
        invoiceNumber: invoiceNumber,
        invoiceDate: now,
      );

      // Track the generated PDF for sync
      try {
        await _dbHelper.documentTrackingService.trackInvoiceGeneration(
          billId: invoiceNumber, // Using invoice number as bill ID for tracking
          invoiceNumber: invoiceNumber,
          pdfBytes: pdfBytes,
          patientName: patientQueueItem.patientName,
          userId: _currentUserId,
          additionalMetadata: {
            'queueEntryId': patientQueueItem.queueEntryId,
            'totalAmount': items.fold(0.0, (sum, item) => sum + item.itemTotal),
            'status': 'generated',
          },
        );
        debugPrint('Invoice PDF tracked for sync: $invoiceNumber');
      } catch (e) {
        debugPrint('Warning: Failed to track invoice PDF for sync: $e');
        // Continue with invoice generation even if tracking fails
      }

      setState(() {
        _generatedInvoiceNumber = invoiceNumber;
        _currentBillItems = items;
        _invoiceDate = now;
        _generatedPdfBytes = pdfBytes;
        _currentStep = InvoiceFlowStep.invoiceGenerated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingInvoice = false);
    }
  }

  void _processPayment() async {
    // Guard clauses
    if (_selectedPatientQueueItem == null ||
        _currentUserId == null ||
        _generatedInvoiceNumber == null) {
      return;
    }

    setState(() => _isProcessingPayment = true);

    final double totalBillAmount =
        _currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    final double? amountPaid = double.tryParse(_amountPaidController.text);

    if (amountPaid == null || amountPaid < totalBillAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Insufficient amount paid.'),
          backgroundColor: Colors.red));
      setState(() => _isProcessingPayment = false);
      return;
    }

    try {
      final result = await _dbHelper.recordInvoiceAndPayment(
        displayInvoiceNumber: _generatedInvoiceNumber,
        patient: _selectedPatientQueueItem!,
        billItemsJson: _selectedPatientQueueItem!.selectedServices ?? [],
        subtotal: totalBillAmount,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: totalBillAmount,
        invoiceDate: _invoiceDate!,
        dueDate: _invoiceDate!.add(const Duration(days: 30)),
        currentUserId: _currentUserId!,
        amountPaidByCustomer: amountPaid,
        paymentMethod: 'Cash',
        paymentNotes: 'Payment for Invoice #$_generatedInvoiceNumber',
      ); // Use the specialized payment success method that handles appointment status updates
      await _queueService.markPaymentSuccessfulAndServe(
          _selectedPatientQueueItem!.queueEntryId);

      // --- Generate Receipt ---
      final receiptDetails = {
        'patientName': _selectedPatientQueueItem!.patientName,
        'invoiceNumber': _generatedInvoiceNumber!,
        'referenceNumber': result['paymentReferenceNumber'],
        'paymentDate': DateTime.now(),
        'totalAmount': totalBillAmount,
        'amountPaid': amountPaid,
        'change': amountPaid - totalBillAmount,
        'receivedByUserId': _currentUserId!,
        'billItems': _currentBillItems
            .map((item) => {
                  'description': item.description,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'itemTotal': item.itemTotal,
                })
            .toList(),
      };
      final receiptBytes =
          await ReceiptService.generateReceiptPdfBytes(receiptDetails);

      // Track the generated receipt PDF for sync
      try {
        final paymentRef = result['paymentReferenceNumber'] ?? 'UNKNOWN';
        await _dbHelper.documentTrackingService.trackReceiptGeneration(
          paymentId: paymentRef,
          referenceNumber: paymentRef,
          pdfBytes: receiptBytes,
          patientName: _selectedPatientQueueItem!.patientName,
          userId: _currentUserId,
          additionalMetadata: {
            'invoiceNumber': _generatedInvoiceNumber,
            'totalAmount': totalBillAmount,
            'amountPaid': amountPaid,
            'change': amountPaid - totalBillAmount,
          },
        );
        debugPrint('Receipt PDF tracked for sync: $paymentRef');
      } catch (e) {
        debugPrint('Warning: Failed to track receipt PDF for sync: $e');
        // Continue with receipt generation even if tracking fails
      }
      // --- End Generate Receipt ---

      setState(() {
        _paymentReferenceNumber = result['paymentReferenceNumber'];
        _paymentChange = amountPaid - totalBillAmount;
        _currentStep = InvoiceFlowStep.paymentComplete;
        _generatedReceiptBytes = receiptBytes;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Payment processed successfully for ${_selectedPatientQueueItem?.patientName}'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh queue displays after successful payment
        ViewQueueScreen.refreshDashboardAfterPayment();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _saveInvoiceAsUnpaid() async {
    if (_selectedPatientQueueItem == null || _currentUserId == null) return;
    setState(() => _isSavingUnpaid = true);

    try {
      final patientQueueItem = _selectedPatientQueueItem!;
      final invoiceNumber = 'INV-${_uuid.v4().substring(0, 6).toUpperCase()}';
      final now = DateTime.now();
      final List<BillItem> items =
          _buildBillItems(patientQueueItem, invoiceNumber);
      final double totalAmount =
          items.fold(0.0, (sum, item) => sum + item.itemTotal);

      await _dbHelper.recordUnpaidInvoice(
        displayInvoiceNumber: invoiceNumber,
        patientId: patientQueueItem.patientId,
        billItemsJson: patientQueueItem.selectedServices ?? [],
        subtotal: totalAmount,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: totalAmount,
        invoiceDate: now,
        dueDate: now.add(const Duration(days: 30)),
        currentUserId: _currentUserId!,
        notes: "Unpaid invoice for ${patientQueueItem.patientName}",
      ); // Use the specialized payment success method that also handles appointment status
      await _queueService
          .markPaymentSuccessfulAndServe(patientQueueItem.queueEntryId);

      final pdfBytes = await _pdfInvoiceService.generateInvoicePdf(
        queueItem: patientQueueItem,
        patientDetails: _detailedPatientForInvoice,
        invoiceNumber: invoiceNumber,
        invoiceDate: now,
      );

      // Track the generated unpaid invoice PDF for sync
      try {
        await _dbHelper.documentTrackingService.trackInvoiceGeneration(
          billId: invoiceNumber,
          invoiceNumber: invoiceNumber,
          pdfBytes: pdfBytes,
          patientName: patientQueueItem.patientName,
          userId: _currentUserId,
          additionalMetadata: {
            'queueEntryId': patientQueueItem.queueEntryId,
            'totalAmount': totalAmount,
            'status': 'unpaid',
          },
        );
        debugPrint('Unpaid invoice PDF tracked for sync: $invoiceNumber');
      } catch (e) {
        debugPrint('Warning: Failed to track unpaid invoice PDF for sync: $e');
        // Continue with invoice generation even if tracking fails
      }

      await _savePdfToDevice(pdfBytes, invoiceNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unpaid invoice $invoiceNumber saved for ${patientQueueItem.patientName}'),
            backgroundColor: Colors.teal,
          ),
        );

        // Refresh patient list and queue displays
        _fetchInConsultationPatients();
        ViewQueueScreen.refreshDashboardAfterPayment();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving unpaid invoice: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSavingUnpaid = false);
    }
  }

  List<BillItem> _buildBillItems(
      ActivePatientQueueItem patientQueueItem, String billId) {
    if (patientQueueItem.selectedServices != null &&
        patientQueueItem.selectedServices!.isNotEmpty) {
      return patientQueueItem.selectedServices!
          .map((service) => BillItem(
                billId: billId,
                description: service['name'] as String? ?? 'Unknown Service',
                quantity: 1,
                unitPrice: (service['price'] as num?)?.toDouble() ?? 0.0,
                itemTotal: (service['price'] as num?)?.toDouble() ?? 0.0,
                serviceId: service['id'] as String?,
              ))
          .toList();
    }
    return [
      BillItem(
        billId: billId,
        description: patientQueueItem.conditionOrPurpose ?? "General Services",
        quantity: 1,
        unitPrice: patientQueueItem.totalPrice ?? 0.0,
        itemTotal: patientQueueItem.totalPrice ?? 0.0,
      )
    ];
  }

  // --- PDF HANDLING ---

  Future<void> _savePdfToDevice(
      Uint8List pdfBytes, String invoiceNumber) async {
    try {
      final dbFile = File((await _dbHelper.database).path);
      final invoiceDir = Directory('${dbFile.parent.path}/Invoice');
      if (!await invoiceDir.exists()) await invoiceDir.create(recursive: true);

      final filePath = '${invoiceDir.path}/$invoiceNumber.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $filePath'),
            action: SnackBarAction(
                label: 'Open', onPressed: () => OpenFilex.open(filePath)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveReceiptToDevice(
      Uint8List pdfBytes, String receiptNumber) async {
    try {
      final dbFile = File((await _dbHelper.database).path);
      final receiptDir = Directory('${dbFile.parent.path}/Receipts');
      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }

      final filePath = '${receiptDir.path}/$receiptNumber.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to: $filePath'),
            action: SnackBarAction(
                label: 'Open', onPressed: () => OpenFilex.open(filePath)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Generate Invoice & Process Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchInConsultationPatients,
            tooltip: 'Refresh / New Invoice',
          )
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: InConsultationPatientList(
              patients: _inConsultationPatients,
              selectedPatient: _selectedPatientQueueItem,
              onPatientSelected: (patient) {
                setState(() {
                  _selectedPatientQueueItem = patient;
                  _currentStep = InvoiceFlowStep.patientSelection;
                  _resetInvoiceAndPaymentState();
                });
                _initializeLabControllers(); // Initialize lab test controllers for the selected patient
                _fetchPatientDetails(patient.patientId);
              },
              currencyFormat: _currencyFormat,
              isLoading: _isLoadingPatients,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildRightPaneContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPaneContent() {
    if (_selectedPatientQueueItem == null) {
      return const Center(child: Text('Select a patient from the list.'));
    }

    switch (_currentStep) {
      case InvoiceFlowStep.patientSelection:
        return PrepareInvoiceView(
          patient: _selectedPatientQueueItem!,
          currencyFormat: _currencyFormat,
          onGenerateAndPay: _generateInvoice,
          onLabOrConsultation: () {
            setState(() => _currentStep = InvoiceFlowStep.labOrConsultation);
          },
          onSaveUnpaid: _saveInvoiceAsUnpaid,
          isGenerating: _isGeneratingInvoice,
          isSaving: _isSavingUnpaid,
        );
      case InvoiceFlowStep.labOrConsultation:
        return LabOrConsultationView(
          patient: _selectedPatientQueueItem!,
          consultationNotesController: _consultationNotesController,
          chiefComplaintController: _chiefComplaintController,
          diagnosisController: _diagnosisController,
          prescriptionController: _prescriptionController,
          consultationType: _consultationType,
          onConsultationTypeChanged: (String type) {
            setState(() => _consultationType = type);
          },
          labResultControllers: _labResultControllers,
          isLabTest: _isLabTest,
          onToggleType: (bool isLab) {
            setState(() => _isLabTest = isLab);
          },
          onSaveAndContinue: _saveLabOrConsultationAndContinue,
          isLoading: _isProcessingLabResults, // Pass the loading state
          onBack: () {
            setState(() => _currentStep = InvoiceFlowStep.patientSelection);
          },
        );
      case InvoiceFlowStep.invoiceGenerated:
        // Handle the case where invoice data might not be ready yet
        if (_generatedInvoiceNumber == null || _invoiceDate == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Generating invoice, please wait..."),
              ],
            ),
          );
        }
        
        return GeneratedInvoiceView(
          generatedInvoiceNumber: _generatedInvoiceNumber ?? 'Pending',
          invoiceDate: _invoiceDate ?? DateTime.now(),
          detailedPatientForInvoice: _detailedPatientForInvoice,
          selectedPatientQueueItem: _selectedPatientQueueItem!,
          currentBillItems: _currentBillItems,
          generatedPdfBytes: _generatedPdfBytes,
          currencyFormat: _currencyFormat,
          onPrint: _printPdf,
          onSave: _savePdfToDevice,
          onProceedToPayment: () =>
              setState(() => _currentStep = InvoiceFlowStep.paymentProcessing),
        );
      case InvoiceFlowStep.paymentProcessing:
        return PaymentProcessingView(
          generatedInvoiceNumber: _generatedInvoiceNumber!,
          selectedPatientQueueItem: _selectedPatientQueueItem!,
          currentBillItems: _currentBillItems,
          amountPaidController: _amountPaidController,
          currencyFormat: _currencyFormat,
          onConfirmAndPay: _processPayment,
          onBackToInvoice: () =>
              setState(() => _currentStep = InvoiceFlowStep.invoiceGenerated),
          isProcessing: _isProcessingPayment,
        );
      case InvoiceFlowStep.paymentComplete:
        return _buildPaymentCompleteContent();
    }
  }
  
  void _saveLabOrConsultationAndContinue() async {
    if (_selectedPatientQueueItem == null) return;
    
    setState(() => _isProcessingLabResults = true);
    
    try {
      // Process and collect all lab results data
      final Map<String, dynamic> labResultsData = {};
      
      // Filter out empty values and only include tests that were selected/performed
      for (var testCategory in _labResultControllers.keys) {
        final Map<String, String> testResults = {};
        bool hasResults = false;
        
        for (var component in _labResultControllers[testCategory]!.keys) {
          final value = _labResultControllers[testCategory]![component]!.text.trim();
          if (value.isNotEmpty) {
            testResults[component] = value;
            hasResults = true;
          }
        }
        
        // Only include test categories that have at least one result
        if (hasResults) {
          labResultsData[testCategory] = testResults;
        }
      }
      
      // Process consultation notes
      final String consultationNotes = _consultationNotesController.text.trim();
      
      if (kDebugMode) {
        print('Lab Results to save: $labResultsData');
        print('Consultation Notes to save: $consultationNotes');
      }
      
      // Save lab results and consultation notes to medical records
      final recordId = const Uuid().v4();
      final now = DateTime.now();
      
      // Convert lab results to JSON string for storage
      String? labResultsJson;
      if (labResultsData.isNotEmpty) {
        labResultsJson = jsonEncode(labResultsData);
      }
      
      // Create medical record entry
      await _dbHelper.insertMedicalRecord({
        'id': recordId,
        'patientId': _selectedPatientQueueItem!.patientId,
        'appointmentId': _selectedPatientQueueItem!.originalAppointmentId,
        'selectedServices': jsonEncode(_selectedPatientQueueItem!.selectedServices ?? []),
        'recordType': _currentStep == InvoiceFlowStep.labOrConsultation && !(_isLabTest) 
            ? 'consultation' 
            : 'laboratory',
        'recordDate': now.toIso8601String(),
        'diagnosis': null,
        'treatment': null,
        'prescription': null,
        'labResults': labResultsJson,
        'notes': consultationNotes.isEmpty ? null : consultationNotes,
        'doctorId': _selectedPatientQueueItem!.doctorId ?? _currentUserId!,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      
      // Proceed to invoice generation
      setState(() => _currentStep = InvoiceFlowStep.invoiceGenerated);
      _generateInvoice();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingLabResults = false);
      }
    }
  }

  Widget _buildPaymentCompleteContent() {
    if (_selectedPatientQueueItem == null) {
      return const Center(
          child: Text("Error: Patient data lost. Please start a new invoice."));
    }
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 80),
          const SizedBox(height: 20),
          const Text(
            'Payment Successful',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Patient: ${_selectedPatientQueueItem!.patientName}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Reference: ${_paymentReferenceNumber ?? 'N/A'}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Change Due: ${_currencyFormat.format(_paymentChange)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (_generatedReceiptBytes != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _printPdf(_generatedReceiptBytes!),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print Receipt'),
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _saveReceiptToDevice(_generatedReceiptBytes!,
                      'RECEIPT-${_generatedInvoiceNumber!}'),
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Save Receipt'),
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue),
                ),
              ],
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              _fetchInConsultationPatients();
              ViewQueueScreen.refreshDashboardAfterPayment();
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Start New Invoice'),
          ),
        ],
      ),
    );
  }

  void _initializeLabControllers() {
    // Clear any existing controllers first to prevent memory leaks
    _labResultControllers.forEach((_, controllers) {
      controllers.forEach((_, controller) {
        controller.dispose();
      });
    });
    _labResultControllers.clear();
    
    // Initialize blood sugar controllers
    _labResultControllers['glucose'] = {
      'fbs': TextEditingController(),
    };
    
    // Initialize lipid profile controllers
    _labResultControllers['lipid'] = {
      'total_cholesterol': TextEditingController(),
      'triglycerides': TextEditingController(),
      'hdl': TextEditingController(),
      'ldl': TextEditingController(),
      'vldl': TextEditingController(),
    };
    
    // Initialize kidney function controllers
    _labResultControllers['kidney'] = {
      'bun': TextEditingController(),
      'creatinine': TextEditingController(),
      'uric_acid': TextEditingController(),
    };
    
    // Initialize liver function controllers
    _labResultControllers['liver'] = {
      'sgpt': TextEditingController(),
      'sgot': TextEditingController(),
    };
    
    // Initialize CBC controllers
    _labResultControllers['cbc'] = {
      'wbc': TextEditingController(),
      'rbc': TextEditingController(),
      'hemoglobin': TextEditingController(),
      'hematocrit': TextEditingController(),
      'platelet': TextEditingController(),
      'mcv_mch_mchc': TextEditingController(),
      'wbc_differential': TextEditingController(),
    };
  }
}
