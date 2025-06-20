import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/bill_item.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/screens/billing/widgets/generated_invoice_view.dart';
import 'package:flutter_application_1/screens/billing/widgets/in_consultation_patient_list.dart';
import 'package:flutter_application_1/screens/billing/widgets/payment_complete_view.dart';
import 'package:flutter_application_1/screens/billing/widgets/payment_processing_view.dart';
import 'package:flutter_application_1/screens/billing/widgets/prepare_invoice_view.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/pdf_invoice_service.dart';
import 'package:flutter_application_1/services/queue_service.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

enum InvoiceFlowStep {
  patientSelection,
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
  final TextEditingController _amountPaidController = TextEditingController();
  double _paymentChange = 0.0;
  String? _paymentReferenceNumber;

  // Button loading states
  bool _isGeneratingInvoice = false;
  bool _isProcessingPayment = false;
  bool _isSavingUnpaid = false;

  // Services and Helpers
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();
  final AuthService _authService = AuthService();
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

  // --- DATA FETCHING AND STATE MANAGEMENT ---

  Future<void> _loadCurrentUserId() async {
    final user = await _authService.getCurrentUser();
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
      _amountPaidController.clear();
      _paymentChange = 0.0;
      _paymentReferenceNumber = null;
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

      final pdfBytes = await _pdfInvoiceService.generateInvoicePdf(
        queueItem: patientQueueItem,
        patientDetails: _detailedPatientForInvoice,
        invoiceNumber: invoiceNumber,
        invoiceDate: now,
      );

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
      );

      await _queueService.updatePatientStatusInQueue(
          _selectedPatientQueueItem!.queueEntryId, 'served');

      setState(() {
        _paymentReferenceNumber = result['paymentReferenceNumber'];
        _paymentChange = amountPaid - totalBillAmount;
        _currentStep = InvoiceFlowStep.paymentComplete;
      });
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
      );

      // Also update status to 'served' so they leave the queue
      await _queueService.updatePatientStatusInQueue(
          patientQueueItem.queueEntryId, 'served');

      final pdfBytes = await _pdfInvoiceService.generateInvoicePdf(
        queueItem: patientQueueItem,
        patientDetails: _detailedPatientForInvoice,
        invoiceNumber: invoiceNumber,
        invoiceDate: now,
      );

      await _savePdfToDevice(pdfBytes, invoiceNumber);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unpaid invoice $invoiceNumber saved.'),
              backgroundColor: Colors.teal),
        );
      }
      _fetchInConsultationPatients();
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


  List<BillItem> _buildBillItems(ActivePatientQueueItem patientQueueItem, String billId) {
    if (patientQueueItem.selectedServices != null && patientQueueItem.selectedServices!.isNotEmpty) {
      return patientQueueItem.selectedServices!.map((service) => BillItem(
        billId: billId,
        description: service['name'] as String? ?? 'Unknown Service',
        quantity: 1,
        unitPrice: (service['price'] as num?)?.toDouble() ?? 0.0,
        itemTotal: (service['price'] as num?)?.toDouble() ?? 0.0,
        serviceId: service['id'] as String?,
      )).toList();
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

  Future<void> _savePdfToDevice(Uint8List pdfBytes, String invoiceNumber) async {
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
            action: SnackBarAction(label: 'Open', onPressed: () => OpenFilex.open(filePath)),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving PDF: $e'), backgroundColor: Colors.red));
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
        title: const Text('Generate Invoice & Process Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          onSaveUnpaid: _saveInvoiceAsUnpaid,
          isGenerating: _isGeneratingInvoice,
          isSaving: _isSavingUnpaid,
        );
      case InvoiceFlowStep.invoiceGenerated:
        return GeneratedInvoiceView(
          generatedInvoiceNumber: _generatedInvoiceNumber!,
          invoiceDate: _invoiceDate!,
          detailedPatientForInvoice: _detailedPatientForInvoice,
          selectedPatientQueueItem: _selectedPatientQueueItem!,
          currentBillItems: _currentBillItems,
          generatedPdfBytes: _generatedPdfBytes,
          currencyFormat: _currencyFormat,
          onPrint: _printPdf,
          onSave: _savePdfToDevice,
          onProceedToPayment: () => setState(() => _currentStep = InvoiceFlowStep.paymentProcessing),
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
        return PaymentCompleteView(
          generatedInvoiceNumber: _generatedInvoiceNumber!,
          paymentReferenceNumber: _paymentReferenceNumber ?? 'N/A',
          selectedPatientQueueItem: _selectedPatientQueueItem!,
          currentBillItems: _currentBillItems,
          paymentChange: _paymentChange,
          currencyFormat: _currencyFormat,
          onPrintReceipt: () => _printPdf(_generatedPdfBytes!),
          onNewInvoice: _fetchInConsultationPatients,
          pdfPreviewThumbnail: _buildPdfPreviewThumbnail(),
        );
    }
  }

  Widget _buildPdfPreviewThumbnail() {
    if (_generatedPdfBytes == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _printPdf(_generatedPdfBytes!),
      child: Container(
        height: 100,
        width: 70,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.picture_as_pdf, color: Colors.red), Text("Print", style: TextStyle(fontSize: 12))],
        ),
      ),
    );
  }
} 