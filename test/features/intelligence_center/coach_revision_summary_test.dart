import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('empty revision summaries have no invented dates', () async {
    expect(await WeightRepository(database).revisionSummary(), (
      count: 0,
      updatedAt: null,
      firstDay: null,
      lastDay: null,
    ));
    expect(await DailyLogRepository(database).revisionSummary(), (
      count: 0,
      updatedAt: null,
    ));
  });

  test(
    'weight aggregate matches full history including deleted rows',
    () async {
      final weights = WeightRepository(database);
      await weights.addWeight(85, date: DateTime(2026, 9, 8));
      final deleted = await weights.addWeight(86, date: DateTime(2026, 9, 5));
      await weights.addWeight(84, date: DateTime(2026, 9, 9));
      await weights.deleteWeight(deleted);
      final all = await weights.getAll();
      final summary = await weights.revisionSummary();
      final days = all.map((row) => row.dayKey!).toList()..sort();
      final revisions = all.map((row) => row.updatedAt).toList()..sort();
      expect(summary.count, all.length);
      expect(summary.firstDay, days.first);
      expect(summary.lastDay, days.last);
      expect(summary.updatedAt, revisions.last);
    },
  );

  test('daily aggregate matches its existing full-history scope', () async {
    final logs = DailyLogRepository(database);
    await logs.save(date: DateTime(2026, 9, 8), steps: 1250);
    await logs.save(date: DateTime(2026, 9, 9), steps: 640);
    final all = await logs.getAll();
    final summary = await logs.revisionSummary();
    final revisions = all.map((row) => row.updatedAt).toList()..sort();
    expect(summary.count, all.length);
    expect(summary.updatedAt, revisions.last);
  });
}
