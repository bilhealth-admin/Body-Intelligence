import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';

final class BodyMeasurementRepository {
  BodyMeasurementRepository(this._database);
  final AppDatabase _database;

  Stream<List<BodyMeasurementEntry>> watchHistory() {
    final query = _database.select(_database.bodyMeasurementEntries)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.date)]);
    return query.watch();
  }

  Future<BodyMeasurementEntry?> getLatest() {
    final query = _database.select(_database.bodyMeasurementEntries)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.date)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> saveForDay({
    required DateTime date,
    double? neckCm,
    double? waistCm,
    double? hipsCm,
    double? chestCm,
    double? armCm,
    double? thighCm,
  }) async {
    final values = [neckCm, waistCm, hipsCm, chestCm, armCm, thighCm];
    if (values.every((value) => value == null)) return;
    for (final value in values.whereType<double>()) {
      if (!value.isFinite || value < 20 || value > 300) {
        throw ArgumentError.value(value, 'measurementCm');
      }
    }
    final key = dayKeyFor(date);
    final existing = await (_database.select(
      _database.bodyMeasurementEntries,
    )..where((row) => row.dayKey.equals(key))).getSingleOrNull();
    await _database
        .into(_database.bodyMeasurementEntries)
        .insert(
          BodyMeasurementEntriesCompanion(
            id: existing == null ? const Value.absent() : Value(existing.id),
            uuid: existing == null
                ? const Value.absent()
                : Value(existing.uuid),
            date: Value(date),
            dayKey: Value(key),
            neckCm: Value(neckCm),
            waistCm: Value(waistCm),
            hipsCm: Value(hipsCm),
            chestCm: Value(chestCm),
            armCm: Value(armCm),
            thighCm: Value(thighCm),
            createdAt: existing == null
                ? const Value.absent()
                : Value(existing.createdAt),
            updatedAt: Value(DateTime.now()),
            revision: Value((existing?.revision ?? 0) + 1),
            syncStatus: const Value('pending'),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
