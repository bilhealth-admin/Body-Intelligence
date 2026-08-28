import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import '../database_scope.dart';

QueryExecutor createDatabaseConnection({String? localOwnerId}) {
  final scopedName = LocalDatabaseScope.keyForOwner(localOwnerId);
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'body_intelligence_log_$scopedName',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.dart.js'),
      );
      return result.resolvedExecutor;
    }),
  );
}
