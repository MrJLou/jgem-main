import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../models/patient.dart';
import '../../models/patient_bill.dart';
import '../../services/database_helper.dart';
import '../payment/payment_screen.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  late Future<Map<String, List<PatientBill>>> _groupedBillsFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _groupedBillsFuture = _loadAndGroupUnpaidBills();
  }

  Future<Map<String, List<PatientBill>>> _loadAndGroupUnpaidBills() async {
    final billsData = await _dbHelper.getPatientBills(statuses: ['Unpaid', 'Pending']);
    final List<PatientBill> bills = [];

    for (var billData in billsData) {
      Patient? patient;
      if (billData['patientId'] != null) {
        final patientData = await _dbHelper.getPatient(billData['patientId']);
        if (patientData != null) {
          patient = Patient.fromJson(patientData);
        }
      }
      bills.add(PatientBill.fromMap(billData, patient));
    }
    
    // Sort bills by date descending
    bills.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

    // Group bills by month and year
    return groupBy(bills, (bill) => DateFormat('MMMM yyyy').format(bill.invoiceDate));
  }

  void _refreshBills() {
    setState(() {
      _groupedBillsFuture = _loadAndGroupUnpaidBills();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unpaid Bills History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBills,
            tooltip: 'Refresh Bills',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<PatientBill>>>(
        future: _groupedBillsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No unpaid bills found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final groupedBills = snapshot.data!;
          final months = groupedBills.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final billsInMonth = groupedBills[month]!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2.0,
                child: ExpansionTile(
                  title: Text(month, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal[800])),
                  initiallyExpanded: true,
                  children: billsInMonth.map((bill) => _buildBillListTile(bill)).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBillListTile(PatientBill bill) {
    return ListTile(
      title: Text(bill.displayInvoiceNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('Patient: ${bill.patient?.fullName ?? 'N/A'} (ID: ${bill.patientId ?? 'N/A'})'),
          Text('Date: ${DateFormat.yMMMd().format(bill.invoiceDate)}'),
          Text('Amount: PHP ${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      trailing: Chip(
        label: Text(bill.status, style: const TextStyle(color: Colors.white)),
        backgroundColor: bill.status == 'Unpaid' ? Colors.orange[700] : Colors.blue[700],
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      isThreeLine: true,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentScreen(invoiceNumber: bill.displayInvoiceNumber),
          ),
        );
      },
    );
  }
} 