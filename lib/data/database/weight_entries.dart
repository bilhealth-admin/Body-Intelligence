import 'package:drift/drift.dart';

import 'database_ids.dart';

class WeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();

  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  /// Local calendar date used to enforce one logical check-in per day.
  TextColumn get dayKey => text().nullable()();

  RealColumn get weight => real()();

  TextColumn get note => text().nullable()();

  /// Stable, non-localized measurement condition selected by the user.
  TextColumn get measurementContext =>
      text().withDefault(const Constant('differentConditions'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
