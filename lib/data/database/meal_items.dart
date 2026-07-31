import 'package:drift/drift.dart';

import 'database_ids.dart';
import 'foods.dart';
import 'meals.dart';

class MealItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();

  IntColumn get mealId =>
      integer().references(Meals, #id, onDelete: KeyAction.cascade)();

  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.restrict)();

  RealColumn get quantity => real().withDefault(const Constant(100))();

  IntColumn get position => integer().withDefault(const Constant(0))();

  RealColumn get calories => real().withDefault(const Constant(0))();

  RealColumn get protein => real().withDefault(const Constant(0))();

  RealColumn get carbs => real().withDefault(const Constant(0))();

  RealColumn get fats => real().withDefault(const Constant(0))();

  RealColumn get fiber => real().withDefault(const Constant(0))();

  RealColumn get sodium => real().withDefault(const Constant(0))();

  RealColumn get potassium => real().withDefault(const Constant(0))();

  RealColumn get calcium => real().withDefault(const Constant(0))();

  RealColumn get magnesium => real().withDefault(const Constant(0))();

  RealColumn get phosphorus => real().withDefault(const Constant(0))();

  RealColumn get sugar => real().withDefault(const Constant(0))();

  IntColumn get nutrientEvidenceMask =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
