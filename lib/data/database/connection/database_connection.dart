import 'package:drift/drift.dart';

import 'database_connection_unsupported.dart'
    if (dart.library.ffi) 'database_connection_native.dart'
    if (dart.library.js_interop) 'database_connection_web.dart';

QueryExecutor openDatabaseConnection({String? localOwnerId}) =>
    createDatabaseConnection(localOwnerId: localOwnerId);
