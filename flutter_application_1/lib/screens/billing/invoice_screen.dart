import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/active_patient_queue_item.dart';
import 'package:flutter_application_1/models/patient.dart';
import 'package:flutter_application_1/services/database_helper.dart';
import 'package:flutter_application_1/services/queue_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/bill_item.dart';
import 'dart:convert'; // Added for jsonEncode in payment processing
import 'dart:io'; // Added for PDF
import 'dart:typed_data'; // Added for PDF
import 'package:pdf/pdf.dart'; // Added for PDF
import 'package:pdf/widgets.dart' as pw; // Added for PDF
import 'package:path_provider/path_provider.dart'; // Added for PDF
import 'package:printing/printing.dart'; // Added for PDF
import 'package:open_filex/open_filex.dart'; // Added for opening PDF
import 'package:flutter/services.dart' show rootBundle; // Added for loading image asset

enum InvoiceFlowStep { patientSelection, invoiceGenerated, paymentProcessing, paymentComplete }

class InvoiceScreen extends StatefulWidget {
  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<ActivePatientQueueItem> _inConsultationPatients = [];
  ActivePatientQueueItem? _selectedPatientQueueItem;
  Patient? _detailedPatientForInvoice;
  bool _isLoadingPatients = true;
  String? _currentUserId;
  
  String? _generatedInvoiceNumber;
  List<BillItem> _currentBillItems = [];
  DateTime? _invoiceDate;
  InvoiceFlowStep _currentStep = InvoiceFlowStep.patientSelection;

  // Payment related state variables
  final TextEditingController _amountPaidController = TextEditingController();
  double _paymentChange = 0.0;
  String? _paymentReferenceNumber; // This might be same as invoice number or a new one for payment transaction

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final QueueService _queueService = QueueService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _fetchInConsultationPatients();
  }

  Future<void> _loadCurrentUserId() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not identify current user. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
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
      final patients = await _dbHelper.getActiveQueue(statuses: ['in_consultation']);
      final validPatients = patients
          .where((p) =>
              p.patientId != null &&
              p.patientId!.isNotEmpty &&
              p.totalPrice != null &&
              p.totalPrice! > 0)
          .toList();

      setState(() {
        _inConsultationPatients = validPatients;
        _isLoadingPatients = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPatients = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching patients: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetInvoiceAndPaymentState() {
      _generatedInvoiceNumber = null;
      _currentBillItems = [];
      _invoiceDate = null;
      _amountPaidController.clear();
      _paymentChange = 0.0;
      _paymentReferenceNumber = null;
  }
  
  void _generateInvoice() async {
    if (_selectedPatientQueueItem == null) return;

    setState(() {
      _isLoadingPatients = true;
    });

    final patientQueueItem = _selectedPatientQueueItem!;
    Patient? fetchedPatientDetails;
    if (patientQueueItem.patientId != null && patientQueueItem.patientId!.isNotEmpty) {
      try {
        final patientDataMap = await _dbHelper.getPatient(patientQueueItem.patientId!);
        if (patientDataMap != null) {
          fetchedPatientDetails = Patient.fromJson(patientDataMap);
        }
      } catch (e) {
        print("Error fetching patient details for invoice: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching patient details: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
        setState(() {
          _isLoadingPatients = false;
        });
        return;
      }
    }

    final invoiceIdSuffix = _uuid.v4().substring(0, 6).toUpperCase();
    final fullInvoiceDbId = "BILL-${_uuid.v4()}";
    final now = DateTime.now();
    
    List<BillItem> items = [];
    if (patientQueueItem.selectedServices != null && patientQueueItem.selectedServices!.isNotEmpty) {
      for (var service in patientQueueItem.selectedServices!) {
        items.add(BillItem(
          billId: fullInvoiceDbId, 
          description: service['name'] as String? ?? 'Unknown Service',
          quantity: 1, 
          unitPrice: (service['price'] as num?)?.toDouble() ?? 0.0,
          itemTotal: (service['price'] as num?)?.toDouble() ?? 0.0,
          serviceId: service['id'] as String?,
        ));
      }
    } else if (patientQueueItem.conditionOrPurpose != null && patientQueueItem.conditionOrPurpose!.isNotEmpty) {
      items.add(BillItem(
        billId: fullInvoiceDbId,
        description: patientQueueItem.conditionOrPurpose!,
        quantity: 1,
        unitPrice: patientQueueItem.totalPrice ?? 0.0,
        itemTotal: patientQueueItem.totalPrice ?? 0.0,
      ));
    } else {
       items.add(BillItem(
        billId: fullInvoiceDbId,
        description: "General Services",
        quantity: 1,
        unitPrice: patientQueueItem.totalPrice ?? 0.0,
        itemTotal: patientQueueItem.totalPrice ?? 0.0,
      ));
    }

    setState(() {
      _detailedPatientForInvoice = fetchedPatientDetails;
      _generatedInvoiceNumber = "INV-$invoiceIdSuffix";
      _currentBillItems = items;
      _invoiceDate = now;
      _currentStep = InvoiceFlowStep.invoiceGenerated;
      _isLoadingPatients = false;
    });
  }

  Future<void> _processInvoicePayment() async {
    if (_selectedPatientQueueItem == null || _currentUserId == null || _generatedInvoiceNumber == null || _invoiceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing critical data for payment processing.'), backgroundColor: Colors.red),
      );
      return;
    }

    final double? amountPaidFromInput = double.tryParse(_amountPaidController.text);
    // Calculate Subtotal, Tax, and Total based on _currentBillItems
    double subtotal = _currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.00; // Placeholder, can be made dynamic later
    double taxAmount = 0.0; // Tax removed
    double totalBillAmount = subtotal - discount + taxAmount; // Tax is now 0

    if (amountPaidFromInput == null || amountPaidFromInput < totalBillAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient amount paid. Required: ₱${totalBillAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final processedPatientItem = _selectedPatientQueueItem!;
    final displayInvNum = _generatedInvoiceNumber!;
    final invDate = _invoiceDate!;
    final dueDate = invDate.add(Duration(days: 30)); // Example due date

    // Prepare billItemsJson from _currentBillItems (which are BillItem objects)
    // The recordInvoiceAndPayment expects List<Map<String, dynamic>> that matches patient.selectedServices structure
    // or a generic structure if _currentBillItems were derived differently.
    // For simplicity, let's assume _currentBillItems directly translates or we adapt DatabaseHelper.
    // For now, sending the structure expected by current DB helper method (based on patient.selectedServices)
    // If _currentBillItems is already the source of truth for items, we should use that.

    List<Map<String, dynamic>> itemsForDb = [];
    if (processedPatientItem.selectedServices != null && processedPatientItem.selectedServices!.isNotEmpty) {
        itemsForDb = processedPatientItem.selectedServices!;
    } else {
        // If no selectedServices, create a general item for DB from _currentBillItems or totalPrice
        // This part needs to align with how `recordInvoiceAndPayment` handles items.
        // Based on `recordInvoiceAndPayment` it can take an empty list and use patient.totalPrice
        // if `billItemsJson` is empty.
    }
    
    // If _currentBillItems was the primary source for display and calculation:
    // itemsForDb = _currentBillItems.map((item) => {
    //   'id': item.serviceId, // May be null if not a standard service
    //   'name': item.description,
    //   'price': item.unitPrice,
    //   'quantity': item.quantity
    // }).toList();

    try {
      final result = await _dbHelper.recordInvoiceAndPayment(
        displayInvoiceNumber: displayInvNum,
        patient: processedPatientItem,
        billItemsJson: itemsForDb, // Use processedPatientItem.selectedServices or map _currentBillItems
        subtotal: subtotal,
        discountAmount: discount,
        taxAmount: taxAmount,
        totalAmount: totalBillAmount,
        invoiceDate: invDate,
        dueDate: dueDate,
        currentUserId: _currentUserId!,
        amountPaidByCustomer: amountPaidFromInput,
        paymentMethod: 'Cash', // Assuming Cash
        paymentNotes: 'Payment for Invoice #$displayInvNum',
      );

      _paymentReferenceNumber = result['paymentReferenceNumber'];
      // The invoice number from result should match displayInvNum

      bool paymentAndServeSuccess = await _queueService.markPaymentSuccessfulAndServe(processedPatientItem.queueEntryId);
      if (!paymentAndServeSuccess) {
        // Even if DB record is fine, if queue update fails, it's a partial success. Log or notify.
        print('Warning: Payment recorded in DB, but failed to update queue status for ${processedPatientItem.queueEntryId}');
        // Potentially show a different message or offer a retry for queue update.
      }

      await _dbHelper.logUserActivity(
        _currentUserId!,
        'Processed payment for invoice $displayInvNum for patient ${processedPatientItem.patientName} (Payment Ref: $_paymentReferenceNumber)',
        targetRecordId: _paymentReferenceNumber, 
        targetTable: DatabaseHelper.tablePayments, // Or tablePatientBills
        details: jsonEncode({
          'queueEntryId': processedPatientItem.queueEntryId,
          'invoiceNumber': displayInvNum,
          'amountPaid': amountPaidFromInput,
          'totalBill': totalBillAmount,
          'billItems_summary': _currentBillItems.map((item) => item.description).join(', '),
        }),
      );

      // --- Auto Save PDF after successful payment ---
      try {
        final pdfBytes = await _generatePdfInvoiceBytes();
        if (mounted && pdfBytes.isNotEmpty) {
          await _savePdfInvoice(pdfBytes, displayInvNum); // displayInvNum is _generatedInvoiceNumber
        }
      } catch (pdfError) {
        print('Error auto-saving PDF after payment: $pdfError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment successful, but failed to auto-save PDF: $pdfError'), backgroundColor: Colors.orange),
          );
        }
      }
      // --- End Auto Save PDF ---

      setState(() {
        _paymentChange = amountPaidFromInput - totalBillAmount;
        _currentStep = InvoiceFlowStep.paymentComplete;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! Reference: $_paymentReferenceNumber. Change: ₱${_paymentChange.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error processing payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- PDF Generation and Handling Methods ---

  Future<Uint8List> _generatePdfInvoiceBytes() async {
    final pdf = pw.Document();

    // Invoice Details (assuming these are already correctly populated)
    final String invoiceNumber = _generatedInvoiceNumber ?? 'INV-XXXXXX';
    final String patientName = _detailedPatientForInvoice?.fullName ?? _selectedPatientQueueItem?.patientName ?? 'N/A';
    final String patientAddress = _detailedPatientForInvoice?.address ?? 'N/A';
    final String patientContact = _detailedPatientForInvoice?.contactNumber ?? 'N/A';
    final DateTime issueDate = _invoiceDate ?? DateTime.now();
    final DateTime dueDate = issueDate.add(const Duration(days: 30)); // Example due date

    // Bill Items
    final List<BillItem> items = _currentBillItems;

    // Calculations
    final double subtotal = items.fold(0.0, (sum, item) => sum + item.itemTotal);
    // final double discountAmount = 0.0; // Discount is removed
    // final double taxRate = 0.00; // Tax is removed (was 0.05 for 5%)
    // final double taxAmount = subtotal * taxRate; // Tax is removed
    final double totalAmount = subtotal; // Since discount and tax are 0/removed

    final boldStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final normalStyle = const pw.TextStyle(); // Default style

    // Load the logo
    pw.ImageProvider? logoImageProvider;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/slide1.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoImageProvider = pw.MemoryImage(logoBytes);
    } catch (e) {
      print('Error loading logo for PDF: $e');
      // Handle error, e.g., log it or use a placeholder
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImageProvider != null)
                        pw.Image(logoImageProvider, width: 120, height: 60) // Adjust size as needed
                      else
                        pw.Text('Your Company Logo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                      pw.SizedBox(height: 5),
                      // Add company details if needed, e.g.,
                      // pw.Text('Your Company Name', style: normalStyle),
                      // pw.Text('Company Address Line 1', style: normalStyle),
                      // pw.Text('Company Contact', style: normalStyle),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 36, color: PdfColors.blue)),
                      pw.SizedBox(height: 10),
                      pw.Text('Invoice #: $invoiceNumber', style: boldStyle),
                      pw.Text('Date of Issue: ${DateFormat('MM/dd/yyyy').format(issueDate)}', style: normalStyle),
                      pw.Text('Due Date: ${DateFormat('MM/dd/yyyy').format(dueDate)}', style: normalStyle),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Billed To Section
              pw.Text('BILLED TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey700)),
              pw.SizedBox(height: 5),
              pw.Text(patientName, style: boldStyle),
              if (patientAddress != 'N/A') pw.Text(patientAddress, style: normalStyle),
              if (patientContact != 'N/A') pw.Text(patientContact, style: normalStyle),
              pw.SizedBox(height: 30),

              // Items Table Header
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue700,
                  // borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('DESCRIPTION', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 1, child: pw.Text('QTY', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('RATE', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),

              // Items Table Rows
              ...items.map((item) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                     border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                     color: items.indexOf(item) % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item.description, style: normalStyle)),
                      pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.right, style: normalStyle)),
                      pw.Expanded(flex: 2, child: pw.Text('₱${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: normalStyle)),
                      pw.Expanded(flex: 2, child: pw.Text('₱${item.itemTotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: normalStyle)),
                    ],
                  ),
                );
              }).toList(),
              pw.SizedBox(height: 20),

              // Totals Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200, // Adjust width as needed
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: boldStyle),
                            pw.Text('₱${subtotal.toStringAsFixed(2)}', style: normalStyle),
                          ],
                        ),
                        // Discount and Tax rows are removed as per request
                        // pw.SizedBox(height: 5),
                        // pw.Row(
                        //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        //   children: [
                        //     pw.Text('Discount:', style: boldStyle),
                        //     pw.Text('₱${discountAmount.toStringAsFixed(2)}', style: normalStyle),
                        //   ],
                        // ),
                        // pw.SizedBox(height: 5),
                        // pw.Row(
                        //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        //   children: [
                        //     pw.Text('Tax (${(taxRate * 100).toStringAsFixed(0)}%):', style: boldStyle),
                        //     pw.Text('₱${taxAmount.toStringAsFixed(2)}', style: normalStyle),
                        //   ],
                        // ),
                        pw.Divider(height: 10, thickness: 1, color: PdfColors.black),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                            pw.Text('₱${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Terms & Conditions / Thank You
              pw.Text('TERMS & CONDITIONS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey700)),
              pw.Text('Payment is due within 30 days. Please make payments to Example Clinic.', style: pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 15),
              pw.Text('THANK YOU FOR YOUR BUSINESS!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
              
              pw.SizedBox(height: 20),
              pw.Text(
                  'Payment Reference (if paid): ${_paymentReferenceNumber ?? (_currentStep == InvoiceFlowStep.paymentComplete ? _generatedInvoiceNumber : 'N/A')}',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),

              pw.Spacer(), // Pushes footer to bottom

              // Footer (Optional)
              // pw.Align(
              //   alignment: pw.Alignment.center,
              //   child: pw.Text('Generated by Clinic Management System', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              // ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _savePdfInvoice(Uint8List pdfBytes, String invoiceNumber) async {
    if (pdfBytes.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save empty PDF.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      // Get the directory where the database file is located.
      final dbFile = File((await _dbHelper.database).path);
      final String databaseParentDirectoryPath = dbFile.parent.path;
      
      final invoiceDir = Directory('$databaseParentDirectoryPath/Invoice');

      if (!await invoiceDir.exists()) {
        await invoiceDir.create(recursive: true);
        print("Created Invoice directory at: ${invoiceDir.path}");
      }
      final filePath = '${invoiceDir.path}/$invoiceNumber.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      if(mounted) { // Ensure widget is still mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $filePath'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                OpenFilex.open(filePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print("Error saving PDF relative to database path: $e");
      if(mounted) { // Ensure widget is still mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printPdfInvoice(Uint8List pdfBytes) async {
    if (pdfBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot print empty PDF.'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing PDF: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  // --- End PDF Methods ---

  Widget _buildInConsultationPatientList() {
    if (_isLoadingPatients) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_inConsultationPatients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No patients currently "In Consultation" and eligible for invoicing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _inConsultationPatients.length,
      itemBuilder: (context, index) {
        final patient = _inConsultationPatients[index];
        final bool isSelected =
            _selectedPatientQueueItem?.queueEntryId == patient.queueEntryId;
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.teal[100] : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: Colors.teal[700],
              child: Text(
                patient.queueNumber.toString(),
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(patient.patientName,
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
                'ID: ${patient.patientId?.substring(0, patient.patientId!.length > 8 ? 8 : patient.patientId!.length) ?? "N/A"}\nServices: ${patient.conditionOrPurpose ?? "N/A"}'),
            trailing: Text('₱${(patient.totalPrice ?? 0.0).toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.bold)),
            selected: isSelected,
            onTap: () {
              setState(() {
                _selectedPatientQueueItem = patient;
                _currentStep = InvoiceFlowStep.patientSelection; // Back to selection, will show gen button
                _resetInvoiceAndPaymentState(); 
              });
            },
          ),
        );
      },
    );
  }
  
  Widget _buildInvoiceView() {
    if (_selectedPatientQueueItem == null || _invoiceDate == null || _generatedInvoiceNumber == null) {
      // This case should ideally not be reached if _currentStep is managed correctly
      return Center(child: Text("Error: Invoice data is missing for view."));
    }
    final patient = _selectedPatientQueueItem!;
    double subtotal = _currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.00; 
    double taxAmount = 0.0; // Tax removed
    double total = subtotal - discount + taxAmount; // Tax is now 0

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container( 
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: Text("Your Company Logo", style: TextStyle(color: Colors.grey[700])),
              ),
              Text("Invoice", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[800])),
            ],
          ),
          SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("BILLED TO:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    Text(patient.patientName),
                    Text("Street Address Line 01"), 
                    Text("Street Address Line 02"), 
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("INVOICE DETAILS:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    Text("Invoice #: ${_generatedInvoiceNumber ?? 'N/A'}"),
                    Text("Date of Issue: ${DateFormat('MM/dd/yyyy').format(_invoiceDate!)}"),
                    Text("Due Date: ${DateFormat('MM/dd/yyyy').format(_invoiceDate!.add(Duration(days: 30)))}"), 
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            color: Colors.blue[800],
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text("ITEM/SERVICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 4, child: Text("DESCRIPTION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("QTY/HRS", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Container(
            color: Colors.yellow[100],
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _currentBillItems.length,
              itemBuilder: (context, index) {
                final item = _currentBillItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(item.description.length > 15 ? item.description.substring(0,15)+"..." : item.description )),
                      Expanded(flex: 4, child: Text(item.description)),
                      Expanded(flex: 1, child: Text(item.quantity.toString(), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.unitPrice.toStringAsFixed(2), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(item.itemTotal.toStringAsFixed(2), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              },
            ),
          ),
          Divider(color: Colors.blue[800], thickness: 2),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TERMS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    Text("Text here"), 
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildTotalRow("Subtotal", subtotal),
                    _buildTotalRow("Discount", discount, isDiscount: true),
                    _buildTotalRow("Tax (0%)", taxAmount), // Label updated to show 0%
                    Divider(),
                    _buildTotalRow("TOTAL", total, isTotal: true),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text("CONDITIONS/INSTRUCTIONS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
          Text("Text here"), 
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
               ElevatedButton(
                onPressed: () async {
                  if (_generatedInvoiceNumber == null || _currentBillItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot print: Invoice data incomplete.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  final pdfBytes = await _generatePdfInvoiceBytes();
                  if (mounted) { // Check if the widget is still in the tree
                    await _printPdfInvoice(pdfBytes);
                  }
                }, 
                child: Text("Print Invoice")
              ),
               ElevatedButton(
                onPressed: () async {
                  if (_generatedInvoiceNumber == null || _currentBillItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot save: Invoice data incomplete.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  final pdfBytes = await _generatePdfInvoiceBytes();
                  if (mounted) { // Check if the widget is still in the tree
                     await _savePdfInvoice(pdfBytes, _generatedInvoiceNumber!);
                  }
                }, 
                child: Text("Save PDF")
              ),
            ],
          ),
          SizedBox(height:10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.payment),
              label: Text("Proceed to Payment"),
              onPressed: () {
                setState(() {
                  _currentStep = InvoiceFlowStep.paymentProcessing;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical:12), textStyle: TextStyle(fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentProcessingView() {
    if (_selectedPatientQueueItem == null || _generatedInvoiceNumber == null) {
       return Center(child: Text("Error: Patient or invoice details missing for payment."));
    }
    double subtotal = _currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.0; // Assuming discount is 0 for now, can be fetched if needed
    double totalAmountDue = subtotal - discount; // No tax

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Process Payment for Invoice: $_generatedInvoiceNumber", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[700])),
          SizedBox(height: 10),
          Text("Patient: ${_selectedPatientQueueItem!.patientName}", style: TextStyle(fontSize: 16)),
          SizedBox(height: 20),
          Text("Total Amount Due: ₱${totalAmountDue.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          TextFormField(
            controller: _amountPaidController,
            style: TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Enter Amount Paid (Cash)',
              hintText: 'e.g., ${totalAmountDue.toStringAsFixed(2)}',
              prefixText: '₱ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: Icon(Icons.money, color: Colors.green[700]),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter amount paid.';
              final pVal = double.tryParse(value);
              if (pVal == null) return 'Invalid amount.';
              if (pVal < totalAmountDue) return 'Amount is less than total due.';
              return null;
            },
          ),
          SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm & Pay'),
              onPressed: _processInvoicePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Invoice'),
              onPressed: () {
                setState(() {
                  _currentStep = InvoiceFlowStep.invoiceGenerated;
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildPaymentCompleteView() {
     if (_selectedPatientQueueItem == null || _generatedInvoiceNumber == null || _paymentReferenceNumber == null) {
       return Center(child: Text("Error: Payment summary data missing."));
    }
    double subtotal = _currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.0; // Assuming discount is 0
    double totalBillAmount = subtotal - discount; // No tax
    double amountPaid = totalBillAmount + _paymentChange; // This is correct as change is amountPaid - totalBill

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 60),
          SizedBox(height: 20),
          Text("Payment Successful!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[700])),
          SizedBox(height: 20),
          Text("Invoice #: $_generatedInvoiceNumber", style: TextStyle(fontSize: 16)),
          Text("Payment Ref #: $_paymentReferenceNumber", style: TextStyle(fontSize: 16)),
          Text("Patient: ${_selectedPatientQueueItem!.patientName}", style: TextStyle(fontSize: 16)),
          SizedBox(height: 15),
          Text("Total Bill: ₱${totalBillAmount.toStringAsFixed(2)}", style: TextStyle(fontSize: 16)),
          Text("Amount Paid: ₱${amountPaid.toStringAsFixed(2)}", style: TextStyle(fontSize: 16)),
          Text("Change Given: ₱${_paymentChange.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 30),
          ElevatedButton.icon(
            icon: Icon(Icons.print_outlined),
            label: Text("Print Receipt"),
            onPressed: () async {
              if (_generatedInvoiceNumber == null || _currentBillItems.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot print receipt: Invoice data missing.'), backgroundColor: Colors.orange),
                );
                return;
              }
              final pdfBytes = await _generatePdfInvoiceBytes();
              if (mounted) { // Check if the widget is still in the tree
                await _printPdfInvoice(pdfBytes);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _fetchInConsultationPatients(); // Resets to patient selection
            },
            child: Text("New Invoice/Payment"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
          ),
        ],
      )
    );
  }


  Widget _buildTotalRow(String label, double value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16: 14)),
          Text(
            "${isDiscount ? '-' : ''}${value.toStringAsFixed(2)}",
            style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16: 14, color: isTotal ? Colors.black : Colors.grey[800])
          ),
        ],
      ),
    );
  }

  Widget _buildRightPaneContent() {
    switch(_currentStep) {
      case InvoiceFlowStep.patientSelection:
        if (_selectedPatientQueueItem == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Select a patient from the list to generate an invoice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          );
        }
        // Show pre-generation summary and button to generate
        final patient = _selectedPatientQueueItem!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prepare Invoice for: ${patient.patientName}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                  ),
                  const SizedBox(height: 10),
                  Text('Patient ID: ${patient.patientId ?? "N/A"}'),
                  Text('Queue Number: ${patient.queueNumber}'),
                  Text('Total Price (from consultation): ₱${(patient.totalPrice ?? 0.0).toStringAsFixed(2)}'),
                  const Divider(height: 25),
                  Text('Services/Items to be Invoiced:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (patient.selectedServices != null && patient.selectedServices!.isNotEmpty)
                    ...patient.selectedServices!.map((service) {
                      final serviceName = service['name'] ?? 'Unknown Service';
                      final price = service['price'] as double? ?? 0.0;
                      return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(serviceName), trailing: Text('₱${price.toStringAsFixed(2)}'));
                    }).toList()
                  else if (patient.conditionOrPurpose != null && patient.conditionOrPurpose!.isNotEmpty)
                     ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(patient.conditionOrPurpose!), trailing: Text('₱${(patient.totalPrice ?? 0.0).toStringAsFixed(2)}'))
                  else
                    Padding(padding: const EdgeInsets.symmetric(vertical:8.0), child: Text("No specific services listed. Invoice will use total price.", style: TextStyle(fontStyle: FontStyle.italic))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.receipt_long),
                          label: Text('Generate & Pay'),
                          onPressed: _generateInvoice, 
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.save_alt_outlined),
                          label: Text('Save Unpaid'),
                          onPressed: _saveInvoiceAsUnpaid,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      case InvoiceFlowStep.invoiceGenerated:
        return _buildInvoiceView();
      case InvoiceFlowStep.paymentProcessing:
        return _buildPaymentProcessingView();
      case InvoiceFlowStep.paymentComplete:
        return _buildPaymentCompleteView();
      default:
        return Center(child: Text("Something went wrong."));
    }
  }

  Future<void> _saveInvoiceAsUnpaid() async {
    if (_selectedPatientQueueItem == null || _currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Patient or user data missing.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_isLoadingPatients) return; // Prevent action if already loading

    setState(() {
      _isLoadingPatients = true; // Use loading indicator
    });

    final patientQueueItem = _selectedPatientQueueItem!;
    Patient? fetchedPatientDetails;

    // Fetch full patient details if not already available (or re-fetch if necessary)
    if (patientQueueItem.patientId != null && patientQueueItem.patientId!.isNotEmpty) {
      try {
        final patientDataMap = await _dbHelper.getPatient(patientQueueItem.patientId!);
        if (patientDataMap != null) {
          fetchedPatientDetails = Patient.fromJson(patientDataMap);
        }
      } catch (e) {
        print("Error fetching patient details for unpaid invoice: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching patient details: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
        setState(() {
          _isLoadingPatients = false;
        });
        return;
      }
    }

    final invoiceIdSuffix = _uuid.v4().substring(0, 6).toUpperCase();
    final displayInvoiceNumber = "INV-$invoiceIdSuffix";
    final dbBillId = "BILL-${_uuid.v4()}"; // This ID is generated internally by recordUnpaidInvoice, no need to pass
    final now = DateTime.now();
    final dueDate = now.add(const Duration(days: 30));

    List<BillItem> tempBillItems = [];
    // This logic correctly populates tempBillItems based on selectedServices or conditionOrPurpose
    if (patientQueueItem.selectedServices != null && patientQueueItem.selectedServices!.isNotEmpty) {
      for (var service in patientQueueItem.selectedServices!) {
        tempBillItems.add(BillItem(
          billId: "TEMP-" + dbBillId, // Temporary, actual billId is set in DB method
          description: service['name'] as String? ?? 'Unknown Service',
          quantity: 1, 
          unitPrice: (service['price'] as num?)?.toDouble() ?? 0.0,
          itemTotal: (service['price'] as num?)?.toDouble() ?? 0.0,
          serviceId: service['id'] as String?,
        ));
      }
    } else if (patientQueueItem.conditionOrPurpose != null && patientQueueItem.conditionOrPurpose!.isNotEmpty) {
      tempBillItems.add(BillItem(
        billId: "TEMP-" + dbBillId,
        description: patientQueueItem.conditionOrPurpose!,
        quantity: 1,
        unitPrice: patientQueueItem.totalPrice ?? 0.0,
        itemTotal: patientQueueItem.totalPrice ?? 0.0,
      ));
    } else {
       tempBillItems.add(BillItem(
        billId: "TEMP-" + dbBillId,
        description: "General Clinic Services",
        quantity: 1,
        unitPrice: patientQueueItem.totalPrice ?? 0.0,
        itemTotal: patientQueueItem.totalPrice ?? 0.0,
      ));
    }

    double subtotal = tempBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    double discount = 0.00;
    double taxAmount = 0.0; // Tax removed
    double totalBillAmount = subtotal - discount + taxAmount; // Tax is now 0

    // Convert List<BillItem> to List<Map<String, dynamic>> for the DB helper method
    List<Map<String, dynamic>> billItemsJsonForDb = tempBillItems.map((item) => {
      'serviceId': item.serviceId, // Can be null
      'description': item.description,
      'quantity': item.quantity,
      'unitPrice': item.unitPrice,
      'itemTotal': item.itemTotal,
      // The DB method also checks for 'name' and 'price' from selectedServices structure,
      // so ensure these are covered or that DB method handles this conversion gracefully.
      // For clarity, we are using the BillItem model structure here.
    }).toList();

    try {
      final String savedInvoiceNumber = await _dbHelper.recordUnpaidInvoice(
        displayInvoiceNumber: displayInvoiceNumber,
        patientId: patientQueueItem.patientId,
        billItemsJson: billItemsJsonForDb,
        subtotal: subtotal,
        discountAmount: discount,
        taxAmount: taxAmount,
        totalAmount: totalBillAmount,
        invoiceDate: now,
        dueDate: dueDate,
        currentUserId: _currentUserId!,
        notes: "Invoice for ${patientQueueItem.patientName} - Unpaid",
      );

      await _dbHelper.logUserActivity(
        _currentUserId!,
        'Saved Unpaid Invoice $savedInvoiceNumber for patient ${patientQueueItem.patientName}',
        targetRecordId: savedInvoiceNumber, 
        targetTable: DatabaseHelper.tablePatientBills,
        details: jsonEncode({
          'patientId': patientQueueItem.patientId,
          'totalAmount': totalBillAmount,
          'status': 'Unpaid',
          'billItems_summary': tempBillItems.map((item) => item.description).join(', '),
        }),
      );
      
      // Update state for potential PDF generation/display if needed immediately
      setState(() {
        _generatedInvoiceNumber = savedInvoiceNumber;
        _currentBillItems = tempBillItems; 
        _invoiceDate = now;
        _detailedPatientForInvoice = fetchedPatientDetails;
        _isLoadingPatients = false;
        // Optionally, clear selection or update UI to indicate save was successful
        // _selectedPatientQueueItem = null; 
        // _currentStep = InvoiceFlowStep.patientSelection; // Or a new confirmation step
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice $savedInvoiceNumber saved as Unpaid for ${patientQueueItem.patientName}.'),
          backgroundColor: Colors.green,
        ),
      );

      // Optionally generate and save PDF for the unpaid invoice
      final pdfBytes = await _generatePdfInvoiceBytes(); // Uses the state variables set above
      if (mounted && pdfBytes.isNotEmpty) {
         await _savePdfInvoice(pdfBytes, savedInvoiceNumber);
      }

    } catch (e) {
      print("Error saving unpaid invoice: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save unpaid invoice: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _isLoadingPatients = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          'Generate Invoice & Process Payment', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _fetchInConsultationPatients(); // This will reset states and fetch
            },
            tooltip: 'Refresh Patient List / New Invoice',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.only(right: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("Patients In Consultation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Expanded(child: _buildInConsultationPatientList()),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2, 
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2)),
                  ],
                ),
                child: SingleChildScrollView( 
                  child: _buildRightPaneContent(), // Dynamically builds content based on _currentStep
                )
              ),
              ),
          ],
        ),
      ),
    );
  }
}