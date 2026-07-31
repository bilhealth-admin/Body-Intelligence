import 'package:drift/drift.dart';

import 'database_ids.dart';

class DecisionMemories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  TextColumn get dayKey => text()();
  TextColumn get recommendationKey => text()();
  TextColumn get title => text()();
  TextColumn get reason => text()();
  TextColumn get evidenceJson => text().withDefault(const Constant('[]'))();
  TextColumn get confidence => text().withDefault(const Constant('low'))();
  TextColumn get response => text().withDefault(const Constant('pending'))();
  TextColumn get outcome => text().nullable()();
  IntColumn get helpfulness => integer().nullable()();
  DateTimeColumn get surfacedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get respondedAt => dateTime().nullable()();
  DateTimeColumn get evaluatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {dayKey, recommendationKey},
  ];
}
