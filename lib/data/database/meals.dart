import 'package:drift/drift.dart';

import 'database_ids.dart';

class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();

  DateTimeColumn get date => dateTime()();

  TextColumn get dayKey => text()();

  TextColumn get name => text().withDefault(const Constant('Meal'))();

  TextColumn get type => text().withDefault(const Constant('other'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
