import 'package:drift/drift.dart';

import 'database_ids.dart';

class DailyLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();

  DateTimeColumn get date => dateTime()();

  TextColumn get dayKey => text().unique()();

  // Kept read-only so databases created before schema v5 remain upgradeable.
  RealColumn get weight => real().nullable()();

  // Legacy nutrition snapshots. Current totals are derived from meal items.
  IntColumn get calories => integer().nullable()();

  IntColumn get protein => integer().nullable()();

  IntColumn get carbs => integer().nullable()();

  IntColumn get fats => integer().nullable()();

  IntColumn get water => integer().nullable()();

  TextColumn get notes => text().nullable()();

  RealColumn get sleepHours => real().nullable()();

  IntColumn get steps => integer().nullable()();

  TextColumn get exerciseNotes => text().nullable()();

  TextColumn get lifecycleState => text().nullable()();

  DateTimeColumn get closedAt => dateTime().nullable()();

  RealColumn get finalFiber => real().nullable()();

  IntColumn get finalNutrientEvidenceMask => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
