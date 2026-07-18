import 'package:drift/drift.dart';

import 'database_ids.dart';

class PersonalExperiments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  TextColumn get hypothesis => text()();
  TextColumn get changedVariable => text()();
  TextColumn get controlledFactors => text().withDefault(const Constant(''))();
  TextColumn get requiredData => text().withDefault(const Constant(''))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  RealColumn get adherence => real().nullable()();
  TextColumn get result => text().nullable()();
  TextColumn get confidence =>
      text().withDefault(const Constant('insufficient'))();
  TextColumn get limitations => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
