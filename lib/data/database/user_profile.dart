import 'package:drift/drift.dart';

class UserProfile extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get gender => text()();

  IntColumn get age => integer()();

  RealColumn get height => real()();

  RealColumn get currentWeight => real()();

  RealColumn get targetWeight => real()();

  TextColumn get activityLevel => text()();

  BoolColumn get exercises => boolean()();

  TextColumn get medicalConditions =>
      text().nullable()();

  RealColumn get waist =>
      real().nullable()();

  RealColumn get neck =>
      real().nullable()();

  RealColumn get chest =>
      real().nullable()();

  RealColumn get arm =>
      real().nullable()();

  RealColumn get thigh =>
      real().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}