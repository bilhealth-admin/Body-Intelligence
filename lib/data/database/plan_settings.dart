import 'package:drift/drift.dart';

import 'database_ids.dart';
import 'user_profile.dart';

class PlanSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  TextColumn get profileUuid => text()
      .references(UserProfile, #uuid, onDelete: KeyAction.cascade)
      .unique()();
  IntColumn get recommendedCalories => integer()();
  IntColumn get recommendedProtein => integer()();
  IntColumn get recommendedCarbs => integer()();
  IntColumn get recommendedFats => integer()();
  IntColumn get recommendedFiber => integer()();
  IntColumn get recommendedWater => integer()();
  IntColumn get overrideCalories => integer().nullable()();
  IntColumn get overrideProtein => integer().nullable()();
  IntColumn get overrideCarbs => integer().nullable()();
  IntColumn get overrideFats => integer().nullable()();
  IntColumn get overrideFiber => integer().nullable()();
  IntColumn get overrideWater => integer().nullable()();
  TextColumn get assumptionsVersion =>
      text().withDefault(const Constant('deterministic-v1'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
