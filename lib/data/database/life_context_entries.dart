import 'package:drift/drift.dart';

import 'database_ids.dart';

class LifeContextEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get dayKey => text()();
  TextColumn get type => text()();
  TextColumn get details => text().nullable()();
  BoolColumn get useInInsights => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
