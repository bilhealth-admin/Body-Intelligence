import 'package:drift/drift.dart';

import 'foods.dart';

class RecentFoods extends Table {
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get lastUsedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get useCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {foodId};
}
