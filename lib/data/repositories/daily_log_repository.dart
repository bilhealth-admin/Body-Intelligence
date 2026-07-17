import 'package:drift/drift.dart';

import '../database/app_database.dart';

class DailyLogRepository {
  final AppDatabase _database;

  DailyLogRepository(this._database);

  Future<void> save({
    required DateTime date,
    double? weight,
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    int? water,
    String? notes,
  }) async {
    await _database.into(_database.dailyLogs).insert(
      DailyLogsCompanion.insert(
        date: date,
        weight: Value(weight),
        calories: Value(calories),
        protein: Value(protein),
        carbs: Value(carbs),
        fats: Value(fats),
        water: Value(water),
        notes: Value(notes),
      ),
    );
  }

  Future<List<DailyLog>> getAll() {
    return _database.select(_database.dailyLogs).get();
  }

  Stream<List<DailyLog>> watchAll() {
    return (_database.select(_database.dailyLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<DailyLog?> watchLatest() {
    return (_database.select(_database.dailyLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.dailyLogs).go();
  }
}