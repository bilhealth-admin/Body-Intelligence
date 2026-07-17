import 'package:drift/drift.dart';

class DailyLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date => dateTime()();

  RealColumn get weight => real().nullable()();

  IntColumn get calories => integer().nullable()();

  IntColumn get protein => integer().nullable()();

  IntColumn get carbs => integer().nullable()();

  IntColumn get fats => integer().nullable()();

  IntColumn get water => integer().nullable()();

  TextColumn get notes => text().nullable()();
}