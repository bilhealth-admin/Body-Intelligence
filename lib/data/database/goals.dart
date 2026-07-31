import 'package:drift/drift.dart';

import 'database_ids.dart';
import 'user_profile.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  TextColumn get profileUuid =>
      text().references(UserProfile, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  RealColumn get targetWeight => real()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
