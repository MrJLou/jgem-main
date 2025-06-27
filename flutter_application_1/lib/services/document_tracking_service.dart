import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Service to track document generation (PDFs, receipts, invoices, reports)
/// and ensure they sync across devices via LAN sync
class DocumentTrackingService {
  static const String _documentsTable = 'generated_documents';
  final DatabaseHelper _dbHelper;

  DocumentTrackingService(this._dbHelper);

  /// Initialize the documents tracking table
  static Future<void> createDocumentsTable(DatabaseHelper dbHelper) async {
    final db = await dbHelper.database;

    // Create table for tracking generated documents
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_documentsTable (
        id TEXT PRIMARY KEY,
        documentType TEXT NOT NULL,
        relatedTable TEXT,
        relatedRecordId TEXT,
        fileName TEXT NOT NULL,
        filePath TEXT,
        fileSize INTEGER,
        documentData TEXT,
        generatedAt TEXT NOT NULL,
        generatedByUserId TEXT,
        synced INTEGER DEFAULT 0,
        metadata TEXT,
        FOREIGN KEY (generatedByUserId) REFERENCES ${DatabaseHelper.tableUsers} (id)
      )
    ''');

    // Create indexes for efficient querying
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_type ON $_documentsTable (documentType)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_related ON $_documentsTable (relatedTable, relatedRecordId)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_generated ON $_documentsTable (generatedAt)
    ''');

    debugPrint('DocumentTrackingService: Documents tracking table created');
  }

  /// Track PDF receipt generation
  Future<String> trackReceiptGeneration({
    required String paymentId,
    required String referenceNumber,
    required Uint8List pdfBytes,
    required String patientName,
    String? filePath,
    String? userId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final documentId =
        'receipt-${DateTime.now().millisecondsSinceEpoch}-$referenceNumber';

    final documentData = {
      'id': documentId,
      'documentType': 'receipt',
      'relatedTable': DatabaseHelper.tablePayments,
      'relatedRecordId': paymentId,
      'fileName':
          'receipt_${referenceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'filePath': filePath,
      'fileSize': pdfBytes.length,
      'documentData': base64Encode(pdfBytes), // Store PDF data for sync
      'generatedAt': DateTime.now().toIso8601String(),
      'generatedByUserId': userId,
      'metadata': jsonEncode({
        'referenceNumber': referenceNumber,
        'patientName': patientName,
        'pdfSize': pdfBytes.length,
        ...?additionalMetadata,
      }),
    };

    final db = await _dbHelper.database;
    await db.insert(_documentsTable, documentData);

    // Log change for sync
    await _dbHelper.logChange(_documentsTable, documentId, 'insert', data: {
      'documentType': 'receipt',
      'referenceNumber': referenceNumber,
      'patientName': patientName,
      'fileSize': pdfBytes.length,
    });

    debugPrint(
        'DocumentTrackingService: Tracked receipt generation for $referenceNumber');
    return documentId;
  }

  /// Track PDF invoice generation
  Future<String> trackInvoiceGeneration({
    required String billId,
    required String invoiceNumber,
    required Uint8List pdfBytes,
    required String patientName,
    String? filePath,
    String? userId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final documentId =
        'invoice-${DateTime.now().millisecondsSinceEpoch}-${invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

    final documentData = {
      'id': documentId,
      'documentType': 'invoice',
      'relatedTable': DatabaseHelper.tablePatientBills,
      'relatedRecordId': billId,
      'fileName':
          'invoice_${invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'filePath': filePath,
      'fileSize': pdfBytes.length,
      'documentData': base64Encode(pdfBytes), // Store PDF data for sync
      'generatedAt': DateTime.now().toIso8601String(),
      'generatedByUserId': userId,
      'metadata': jsonEncode({
        'invoiceNumber': invoiceNumber,
        'patientName': patientName,
        'pdfSize': pdfBytes.length,
        ...?additionalMetadata,
      }),
    };

    final db = await _dbHelper.database;
    await db.insert(_documentsTable, documentData);

    // Log change for sync
    await _dbHelper.logChange(_documentsTable, documentId, 'insert', data: {
      'documentType': 'invoice',
      'invoiceNumber': invoiceNumber,
      'patientName': patientName,
      'fileSize': pdfBytes.length,
    });

    debugPrint(
        'DocumentTrackingService: Tracked invoice generation for $invoiceNumber');
    return documentId;
  }

  /// Track financial report generation
  Future<String> trackFinancialReportGeneration({
    required Uint8List pdfBytes,
    required String reportTitle,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    required int transactionCount,
    String? filePath,
    String? userId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final documentId =
        'financial_report-${DateTime.now().millisecondsSinceEpoch}';

    final documentData = {
      'id': documentId,
      'documentType': 'financial_report',
      'relatedTable': DatabaseHelper.tablePayments,
      'relatedRecordId': 'multiple',
      'fileName':
          'financial_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'filePath': filePath,
      'fileSize': pdfBytes.length,
      'documentData': base64Encode(pdfBytes),
      'generatedAt': DateTime.now().toIso8601String(),
      'generatedByUserId': userId,
      'metadata': jsonEncode({
        'reportTitle': reportTitle,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'totalAmount': totalAmount,
        'transactionCount': transactionCount,
        'pdfSize': pdfBytes.length,
        ...?additionalMetadata,
      }),
    };

    final db = await _dbHelper.database;
    await db.insert(_documentsTable, documentData);

    // Log change for sync
    await _dbHelper.logChange(_documentsTable, documentId, 'insert', data: {
      'documentType': 'financial_report',
      'reportTitle': reportTitle,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalAmount': totalAmount,
      'transactionCount': transactionCount,
      'fileSize': pdfBytes.length,
    });

    debugPrint('DocumentTrackingService: Tracked financial report generation');
    return documentId;
  }

  /// Track queue report PDF generation
  Future<String> trackQueueReportGeneration({
    required String reportId,
    required Uint8List pdfBytes,
    required String reportDate,
    String? filePath,
    String? userId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final documentId =
        'queue_report-${DateTime.now().millisecondsSinceEpoch}-${reportDate.replaceAll('-', '')}';

    final documentData = {
      'id': documentId,
      'documentType': 'queue_report',
      'relatedTable': DatabaseHelper.tablePatientQueue,
      'relatedRecordId': reportId,
      'fileName':
          'queue_report_${reportDate.replaceAll('-', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'filePath': filePath,
      'fileSize': pdfBytes.length,
      'documentData': base64Encode(pdfBytes),
      'generatedAt': DateTime.now().toIso8601String(),
      'generatedByUserId': userId,
      'metadata': jsonEncode({
        'reportDate': reportDate,
        'pdfSize': pdfBytes.length,
        ...?additionalMetadata,
      }),
    };

    final db = await _dbHelper.database;
    await db.insert(_documentsTable, documentData);

    // Log change for sync
    await _dbHelper.logChange(_documentsTable, documentId, 'insert', data: {
      'documentType': 'queue_report',
      'reportDate': reportDate,
      'fileSize': pdfBytes.length,
    });

    debugPrint(
        'DocumentTrackingService: Tracked queue report generation for $reportDate');
    return documentId;
  }

  /// Get all documents for a specific record
  Future<List<Map<String, dynamic>>> getDocumentsForRecord({
    required String relatedTable,
    required String relatedRecordId,
  }) async {
    final db = await _dbHelper.database;
    return await db.query(
      _documentsTable,
      where: 'relatedTable = ? AND relatedRecordId = ?',
      whereArgs: [relatedTable, relatedRecordId],
      orderBy: 'generatedAt DESC',
    );
  }

  /// Get documents by type
  Future<List<Map<String, dynamic>>> getDocumentsByType(String documentType,
      {int? limit}) async {
    final db = await _dbHelper.database;
    return await db.query(
      _documentsTable,
      where: 'documentType = ?',
      whereArgs: [documentType],
      orderBy: 'generatedAt DESC',
      limit: limit,
    );
  }

  /// Get document by ID with PDF data
  Future<Map<String, dynamic>?> getDocumentWithData(String documentId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      _documentsTable,
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );

    if (results.isNotEmpty) {
      final document = Map<String, dynamic>.from(results.first);

      // Parse metadata if available
      if (document['metadata'] != null) {
        try {
          document['parsedMetadata'] = jsonDecode(document['metadata']);
        } catch (e) {
          debugPrint('Error parsing document metadata: $e');
        }
      }

      return document;
    }

    return null;
  }

  /// Get PDF bytes from stored document
  Uint8List? getPdfBytesFromDocument(Map<String, dynamic> document) {
    final documentData = document['documentData'] as String?;
    if (documentData != null) {
      try {
        return base64Decode(documentData);
      } catch (e) {
        debugPrint('Error decoding PDF data: $e');
      }
    }
    return null;
  }

  /// Mark document as synced
  Future<void> markDocumentAsSynced(String documentId) async {
    final db = await _dbHelper.database;
    await db.update(
      _documentsTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Get unsynced documents
  Future<List<Map<String, dynamic>>> getUnsyncedDocuments() async {
    final db = await _dbHelper.database;
    return await db.query(
      _documentsTable,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'generatedAt ASC',
    );
  }

  /// Clean up old documents (optional - for storage management)
  Future<int> cleanupOldDocuments({int daysToKeep = 90}) async {
    final db = await _dbHelper.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    return await db.delete(
      _documentsTable,
      where: 'generatedAt < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Get document statistics
  Future<Map<String, dynamic>> getDocumentStatistics() async {
    final db = await _dbHelper.database;

    final totalCount =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_documentsTable');
    final typeCount = await db.rawQuery('''
      SELECT documentType, COUNT(*) as count 
      FROM $_documentsTable 
      GROUP BY documentType
    ''');
    final totalSize = await db
        .rawQuery('SELECT SUM(fileSize) as totalSize FROM $_documentsTable');

    return {
      'totalDocuments': totalCount.first['count'] ?? 0,
      'documentsByType': typeCount,
      'totalSizeBytes': totalSize.first['totalSize'] ?? 0,
      'lastGenerated': await _getLastGeneratedDocument(),
    };
  }

  Future<Map<String, dynamic>?> _getLastGeneratedDocument() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      _documentsTable,
      orderBy: 'generatedAt DESC',
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }
}
