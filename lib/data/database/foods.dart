import 'package:drift/drift.dart';

import 'database_ids.dart';

class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();

  TextColumn get name => text()();

  TextColumn get arabicName => text().nullable()();

  TextColumn get category => text().nullable()();

  TextColumn get keywords => text().withDefault(const Constant(''))();

  TextColumn get barcode => text().nullable()();

  RealColumn get servingSize => real().withDefault(const Constant(100))();

  TextColumn get servingUnit => text().withDefault(const Constant('g'))();

  RealColumn get calories => real()();

  RealColumn get protein => real()();

  RealColumn get carbs => real()();

  RealColumn get fats => real()();

  RealColumn get fiber => real().withDefault(const Constant(0))();

  RealColumn get sugar => real().withDefault(const Constant(0))();

  RealColumn get potassium => real().withDefault(const Constant(0))();

  RealColumn get sodium => real().withDefault(const Constant(0))();

  RealColumn get calcium => real().withDefault(const Constant(0))();

  RealColumn get iron => real().withDefault(const Constant(0))();

  RealColumn get magnesium => real().withDefault(const Constant(0))();

  RealColumn get vitaminC => real().withDefault(const Constant(0))();

  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  TextColumn get source => text().withDefault(const Constant('local'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}
