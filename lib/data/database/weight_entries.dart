import 'package:drift/drift.dart';

class WeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date =>
      dateTime().withDefault(currentDateAndTime)();

  RealColumn get weight => real()();

  TextColumn get note => text().nullable()();
}