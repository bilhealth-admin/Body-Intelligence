import 'package:drift/drift.dart';

QueryExecutor createDatabaseConnection({String? localOwnerId}) =>
    throw UnsupportedError(
      'No local database implementation for this platform.',
    );
