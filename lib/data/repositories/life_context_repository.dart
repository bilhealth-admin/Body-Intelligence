import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';

class LifeContextRepository {
  LifeContextRepository(this.database);

  final AppDatabase database;

  static const allowedTypes = {
    'travel',
    'illness',
    'medicationChange',
    'menstrualContext',
    'stress',
    'event',
    'poorSleep',
    'stoppedTraining',
    'fasting',
    'ramadan',
    'highSodiumMeal',
    'other',
  };

  Future<int> add({
    required DateTime occurredAt,
    required String type,
    String? details,
    bool useInInsights = true,
  }) {
    if (!allowedTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported life context');
    }
    return database
        .into(database.lifeContextEntries)
        .insert(
          LifeContextEntriesCompanion.insert(
            occurredAt: occurredAt,
            dayKey: dayKeyFor(occurredAt),
            type: type,
            details: Value(
              details?.trim().isEmpty == true ? null : details?.trim(),
            ),
            useInInsights: Value(useInInsights),
          ),
        );
  }

  Stream<List<LifeContextEntry>> watchForDay(DateTime date) {
    return (database.select(database.lifeContextEntries)
          ..where(
            (row) =>
                row.dayKey.equals(dayKeyFor(date)) & row.deletedAt.isNull(),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .watch();
  }

  Stream<List<LifeContextEntry>> watchAllForInsights() {
    return (database.select(database.lifeContextEntries)
          ..where(
            (row) => row.deletedAt.isNull() & row.useInInsights.equals(true),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .watch();
  }

  Future<void> setInsightConsent(int id, bool enabled) async {
    await (database.update(
      database.lifeContextEntries,
    )..where((row) => row.id.equals(id))).write(
      LifeContextEntriesCompanion(
        useInInsights: Value(enabled),
        updatedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (database.update(
      database.lifeContextEntries,
    )..where((row) => row.id.equals(id))).write(
      LifeContextEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }
}
