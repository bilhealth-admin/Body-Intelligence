import 'dart:io';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schema22 upgrade adds nullable photo snapshot without rewriting legacy closed rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-vision-v23-',
      );
      final file = File('${directory.path}/database.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final day = DateTime(2026, 11, 18);
        await DailyLogRepository(db).startDay(day);
        await DailyLogRepository(db).closeDay(day);
        final before = (await DailyLogRepository(db).getForDay(day))!;
        await db.customStatement(
          'ALTER TABLE daily_logs DROP COLUMN final_vision_nutrient_evidence_json',
        );
        await db.customStatement('PRAGMA user_version=22');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        final after = (await DailyLogRepository(db).getForDay(day))!;
        expect(db.schemaVersion, 23);
        expect(after, before);
        expect(after.finalVisionNutrientEvidenceJson, isNull);
        expect(
          (await DailyLogRepository(db).readLedger(day)).netCarbohydrates,
          isNull,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
