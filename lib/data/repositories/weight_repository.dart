import 'package:drift/drift.dart';

import '../database/app_database.dart';

class WeightRepository {
  final AppDatabase _database;

  WeightRepository(this._database);

  Future<void> addWeight(double weight) async {
    await _database
        .into(_database.weightEntries)
        .insert(WeightEntriesCompanion.insert(weight: weight));
  }

  Stream<List<WeightEntry>> watchWeights() {
    return (_database.select(
      _database.weightEntries,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  Stream<WeightEntry?> watchLatestWeight() {
    return (_database.select(_database.weightEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<WeightEntry>> getAll() {
    return (_database.select(
      _database.weightEntries,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.weightEntries).go();
  }
}
