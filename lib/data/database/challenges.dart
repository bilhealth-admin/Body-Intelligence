import 'package:drift/drift.dart';

import 'database_ids.dart';

class Challenges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get audience => text().withDefault(const Constant('private'))();
  IntColumn get targetDays => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
