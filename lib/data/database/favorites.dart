import 'package:drift/drift.dart';

import 'foods.dart';

class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade).unique()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
