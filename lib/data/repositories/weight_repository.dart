import 'package:drift/drift.dart';

import '../database/app_database.dart';

class WeightRepository {
  final AppDatabase _database;

  WeightRepository(this._database);

  Future<int> addWeight(double weight, {DateTime? date, String? note}) async {
    _validateWeight(weight);
    return _database
        .into(_database.weightEntries)
        .insert(
          WeightEntriesCompanion.insert(
            weight: weight,
            date: Value(date ?? DateTime.now()),
            note: Value(note),
          ),
        );
  }

  Future<void> updateWeight({
    required int id,
    required double weight,
    required DateTime date,
    String? note,
  }) async {
    _validateWeight(weight);
    await (_database.update(
      _database.weightEntries,
    )..where((row) => row.id.equals(id))).write(
      WeightEntriesCompanion(
        weight: Value(weight),
        date: Value(date),
        note: Value(note),
        updatedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> deleteWeight(int id) async {
    await (_database.update(
      _database.weightEntries,
    )..where((row) => row.id.equals(id))).write(
      WeightEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }

  Stream<List<WeightEntry>> watchWeights() {
    return (_database.select(_database.weightEntries)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<WeightEntry?> watchLatestWeight() {
    return (_database.select(_database.weightEntries)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<WeightEntry>> getAll() {
    return (_database.select(_database.weightEntries)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.weightEntries).go();
  }

  void _validateWeight(double weight) {
    if (!weight.isFinite || weight < 20 || weight > 500) {
      throw ArgumentError.value(weight, 'weight', 'Must be 20–500 kg');
    }
  }
}
