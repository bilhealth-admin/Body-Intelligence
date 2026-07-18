import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';

class MealRepository {
  final AppDatabase _database;

  MealRepository(this._database);

  Future<int> createMeal({
    required DateTime date,
    required String name,
    required String type,
  }) async {
    return _database
        .into(_database.meals)
        .insert(
          MealsCompanion.insert(
            date: date,
            dayKey: dayKeyFor(date),
            name: Value(name),
            type: Value(type),
          ),
        );
  }

  Future<void> addMealItem({
    required int mealId,
    required int foodId,
    required double quantity,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    await _database
        .into(_database.mealItems)
        .insert(
          MealItemsCompanion.insert(
            mealId: mealId,
            foodId: foodId,
            quantity: Value(quantity),
            calories: Value(calories),
            protein: Value(protein),
            carbs: Value(carbs),
            fats: Value(fats),
          ),
        );
  }

  Stream<List<MealWithItems>> watchMealsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final query = _database.select(_database.meals)
      ..where((tbl) => tbl.date.isBetweenValues(start, end));

    return query.watch().asyncMap((meals) async {
      final rows = <MealWithItems>[];
      for (final meal in meals) {
        final items = await (_database.select(
          _database.mealItems,
        )..where((tbl) => tbl.mealId.equals(meal.id))).get();
        rows.add(MealWithItems(meal: meal, items: items));
      }
      return rows;
    });
  }
}

class MealWithItems {
  final Meal meal;
  final List<MealItem> items;

  const MealWithItems({required this.meal, required this.items});
}
