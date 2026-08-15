import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema 19 upgrades to 20 without losing existing data', () async {
    final directory = await Directory.systemTemp.createTemp('bil-v20-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/bil.sqlite');

    var database = AppDatabase.forTesting(NativeDatabase(file));
    await database.customSelect('SELECT 1').get();
    await database.customStatement(
      "INSERT INTO preferences (key, value) VALUES ('migration-proof', 'kept')",
    );
    await database.customStatement('DROP TABLE body_measurement_entries');
    await database.customStatement('PRAGMA user_version = 19');
    await database.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'body_measurement_entries'",
        )
        .get();
    expect(tables, hasLength(1));
    final proof = await database
        .customSelect(
          "SELECT value FROM preferences WHERE key = 'migration-proof'",
        )
        .getSingle();
    expect(proof.read<String>('value'), 'kept');
  });
}
