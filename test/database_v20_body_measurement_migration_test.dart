import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema 19 upgrades through 22 without losing existing data', () async {
    final directory = await Directory.systemTemp.createTemp('bil-v20-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/bil.sqlite');

    var database = AppDatabase.forTesting(NativeDatabase(file));
    await database.customSelect('SELECT 1').get();
    await database.customStatement(
      "INSERT INTO preferences (key, value) VALUES ('migration-proof', 'kept')",
    );
    await database.customStatement('DROP TABLE body_measurement_entries');
    // This fixture starts from today's schema and then models schema 19.
    // Remove later columns as well as the v20 table before setting its version.
    await database.customStatement(
      'ALTER TABLE meal_items DROP COLUMN food_evidence_json',
    );
    await database.customStatement(
      'ALTER TABLE foods DROP COLUMN food_evidence_json',
    );
    await database.customStatement('PRAGMA user_version = 19');
    await database.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);
    expect(database.schemaVersion, 22);
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

    final foreignKeyViolations = await database
        .customSelect('PRAGMA foreign_key_check')
        .get();
    expect(foreignKeyViolations, isEmpty);
    final integrity = await database
        .customSelect('PRAGMA integrity_check')
        .get();
    expect(integrity.single.read<String>('integrity_check'), 'ok');
  });
}
