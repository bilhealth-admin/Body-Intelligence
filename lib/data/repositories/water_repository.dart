import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';

class WaterRepository {
  WaterRepository(this._database);

  final AppDatabase _database;

  Future<int> add({required DateTime occurredAt, required int amountMl}) {
    if (amountMl <= 0 || amountMl > 5000) {
      throw ArgumentError.value(
        amountMl,
        'amountMl',
        'Must be between 1 and 5000',
      );
    }
    return _database
        .into(_database.waterEntries)
        .insert(
          WaterEntriesCompanion.insert(
            occurredAt: occurredAt,
            dayKey: dayKeyFor(occurredAt),
            amountMl: amountMl,
          ),
        );
  }

  Future<int> totalForDay(DateTime date) async {
    final amount = _database.waterEntries.amountMl.sum();
    final query = _database.selectOnly(_database.waterEntries)
      ..addColumns([amount])
      ..where(
        _database.waterEntries.dayKey.equals(dayKeyFor(date)) &
            _database.waterEntries.deletedAt.isNull(),
      );
    return (await query.getSingle()).read(amount) ?? 0;
  }

  Stream<List<WaterEntry>> watchForDay(DateTime date) {
    return (_database.select(_database.waterEntries)
          ..where(
            (row) =>
                row.dayKey.equals(dayKeyFor(date)) & row.deletedAt.isNull(),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.occurredAt)]))
        .watch();
  }

  Future<void> delete(int id) async {
    await (_database.update(
      _database.waterEntries,
    )..where((row) => row.id.equals(id))).write(
      WaterEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }
}
