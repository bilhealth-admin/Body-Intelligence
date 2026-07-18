import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';

class WeightRepository {
  final AppDatabase _database;

  WeightRepository(this._database);

  Future<int> addWeight(
    double weight, {
    DateTime? date,
    String? note,
    String measurementContext = 'differentConditions',
  }) async {
    _validateWeight(weight);
    _validateContext(measurementContext);
    final occurredAt = date ?? DateTime.now();
    final existing = await getForDay(occurredAt);
    if (existing != null) {
      await updateWeight(
        id: existing.id,
        weight: weight,
        date: occurredAt,
        note: note,
        measurementContext: measurementContext,
      );
      return existing.id;
    }
    return _database
        .into(_database.weightEntries)
        .insert(
          WeightEntriesCompanion.insert(
            weight: weight,
            date: Value(occurredAt),
            dayKey: Value(dayKeyFor(occurredAt)),
            note: Value(note),
            measurementContext: Value(measurementContext),
          ),
        );
  }

  Future<WeightEntry?> getForDay(DateTime date) {
    return (_database.select(_database.weightEntries)..where(
          (row) => row.dayKey.equals(dayKeyFor(date)) & row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Stream<WeightEntry?> watchForDay(DateTime date) {
    return (_database.select(_database.weightEntries)..where(
          (row) => row.dayKey.equals(dayKeyFor(date)) & row.deletedAt.isNull(),
        ))
        .watchSingleOrNull();
  }

  Future<void> updateWeight({
    required int id,
    required double weight,
    required DateTime date,
    String? note,
    String measurementContext = 'differentConditions',
  }) async {
    _validateWeight(weight);
    _validateContext(measurementContext);
    final revision = await _nextRevision(id);
    await (_database.update(
      _database.weightEntries,
    )..where((row) => row.id.equals(id))).write(
      WeightEntriesCompanion(
        weight: Value(weight),
        date: Value(date),
        dayKey: Value(dayKeyFor(date)),
        note: Value(note),
        measurementContext: Value(measurementContext),
        updatedAt: Value(DateTime.now()),
        revision: Value(revision),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> deleteWeight(int id) async {
    final revision = await _nextRevision(id);
    await (_database.update(
      _database.weightEntries,
    )..where((row) => row.id.equals(id))).write(
      WeightEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        revision: Value(revision),
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

  Future<int> _nextRevision(int id) async {
    final row = await (_database.select(
      _database.weightEntries,
    )..where((entry) => entry.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('Weight entry $id does not exist');
    return row.revision + 1;
  }

  void _validateWeight(double weight) {
    if (!weight.isFinite || weight < 20 || weight > 500) {
      throw ArgumentError.value(weight, 'weight', 'Must be 20–500 kg');
    }
  }

  void _validateContext(String value) {
    if (!const {
      'morning',
      'afterBathroom',
      'beforeFoodDrink',
      'differentConditions',
    }.contains(value)) {
      throw ArgumentError.value(value, 'measurementContext');
    }
  }
}
