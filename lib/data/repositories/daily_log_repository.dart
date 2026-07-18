import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';

class DailyLogRepository {
  final AppDatabase _database;

  DailyLogRepository(this._database);

  Future<void> save({
    required DateTime date,
    String? notes,
    double? sleepHours,
    int? steps,
    String? exerciseNotes,
  }) async {
    final key = dayKeyFor(date);
    final existing = await (_database.select(
      _database.dailyLogs,
    )..where((row) => row.dayKey.equals(key))).getSingleOrNull();
    final companion = DailyLogsCompanion(
      id: existing == null ? const Value.absent() : Value(existing.id),
      uuid: existing == null ? const Value.absent() : Value(existing.uuid),
      date: Value(date),
      dayKey: Value(key),
      notes: Value(notes),
      sleepHours: Value(sleepHours),
      steps: Value(steps),
      exerciseNotes: Value(exerciseNotes),
      createdAt: existing == null
          ? const Value.absent()
          : Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
    );
    await _database.into(_database.dailyLogs).insertOnConflictUpdate(companion);
  }

  Future<List<DailyLog>> getAll() {
    return _database.select(_database.dailyLogs).get();
  }

  Stream<List<DailyLog>> watchAll() {
    return (_database.select(
      _database.dailyLogs,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  Stream<DailyLog?> watchLatest() {
    return (_database.select(_database.dailyLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<DailyLog?> watchForDay(DateTime date) {
    return (_database.select(_database.dailyLogs)
          ..where((row) => row.dayKey.equals(dayKeyFor(date)))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.dailyLogs).go();
  }
}
