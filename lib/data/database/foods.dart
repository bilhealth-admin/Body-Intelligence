import 'package:drift/drift.dart';

class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get arabicName => text().nullable()();

  TextColumn get category => text().nullable()();

  TextColumn get barcode => text().nullable()();

  RealColumn get servingSize =>
      real().withDefault(const Constant(100))();

  TextColumn get servingUnit =>
      text().withDefault(const Constant('g'))();

  RealColumn get calories => real()();

  RealColumn get protein => real()();

  RealColumn get carbs => real()();

  RealColumn get fats => real()();

  RealColumn get fiber =>
      real().withDefault(const Constant(0))();

  RealColumn get sugar =>
      real().withDefault(const Constant(0))();

  RealColumn get potassium =>
      real().withDefault(const Constant(0))();

  RealColumn get sodium =>
      real().withDefault(const Constant(0))();

  RealColumn get calcium =>
      real().withDefault(const Constant(0))();

  RealColumn get iron =>
      real().withDefault(const Constant(0))();

  RealColumn get magnesium =>
      real().withDefault(const Constant(0))();

  RealColumn get vitaminC =>
      real().withDefault(const Constant(0))();

  BoolColumn get verified =>
      boolean().withDefault(const Constant(false))();
}