import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return NativeDatabase.createInBackground(
      File(p.join(directory.path, 'body_intelligence.sqlite')),
    );
  });
}
