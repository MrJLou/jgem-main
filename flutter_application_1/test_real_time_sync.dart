// Temporary file to test real-time sync
import 'package:flutter/foundation.dart';

import 'lib/services/real_time_sync_service.dart';
import 'lib/services/lan_sync_service.dart';
import 'lib/services/database_helper.dart';

void main() async {
  if (kDebugMode) {
    print('Testing real-time sync setup...');
  }

  // Initialize services
  final dbHelper = DatabaseHelper();
  await LanSyncService.initialize(dbHelper);
  await RealTimeSyncService.initialize();

  if (kDebugMode) {
    print('Services initialized successfully');
  }
}
