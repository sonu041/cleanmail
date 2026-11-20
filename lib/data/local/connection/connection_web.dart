import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    try {
      final result = await WasmDatabase.open(
        databaseName: 'cleanmail_db',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      if (result.missingFeatures.isNotEmpty) {
        debugPrint('Drift web info: using ${result.chosenImplementation} (missing: ${result.missingFeatures})');
      }
      return result.resolvedExecutor;
    } catch (e) {
      debugPrint('WasmDatabase.open encountered: $e. Retrying in-memory session...');
      final fallback = await WasmDatabase.open(
        databaseName: 'cleanmail_fallback',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return fallback.resolvedExecutor;
    }
  });
}
