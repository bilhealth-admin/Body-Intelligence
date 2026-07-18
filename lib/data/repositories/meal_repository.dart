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
    if (!const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported meal type');
    }
    final key = dayKeyFor(date);
    final existing =
        await (_database.select(_database.meals)
              ..where(
                (row) =>
                    row.dayKey.equals(key) &
                    row.type.equals(type) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    return _database
        .into(_database.meals)
        .insert(
          MealsCompanion.insert(
            date: date,
            dayKey: key,
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
    double fiber = 0,
    double sodium = 0,
    double potassium = 0,
  }) async {
    if (quantity <= 0 ||
        calories < 0 ||
        protein < 0 ||
        carbs < 0 ||
        fats < 0 ||
        fiber < 0 ||
        sodium < 0 ||
        potassium < 0) {
      throw ArgumentError('Meal quantities and nutrients must be non-negative');
    }
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
            fiber: Value(fiber),
            sodium: Value(sodium),
            potassium: Value(potassium),
          ),
        );
  }

  Future<void> updateMealItem({
    required int id,
    required double quantity,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    double fiber = 0,
    double sodium = 0,
    double potassium = 0,
  }) async {
    if (quantity <= 0) throw ArgumentError.value(quantity, 'quantity');
    await (_database.update(
      _database.mealItems,
    )..where((row) => row.id.equals(id))).write(
      MealItemsCompanion(
        quantity: Value(quantity),
        calories: Value(calories),
        protein: Value(protein),
        carbs: Value(carbs),
        fats: Value(fats),
        fiber: Value(fiber),
        sodium: Value(sodium),
        potassium: Value(potassium),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteMealItem(int id) async {
    await (_database.update(
      _database.mealItems,
    )..where((row) => row.id.equals(id))).write(
      MealItemsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<MealWithItems>> watchMealsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final query = _database.select(_database.meals)
      ..where(
        (tbl) => tbl.date.isBetweenValues(start, end) & tbl.deletedAt.isNull(),
      );

    return query.watch().asyncMap((meals) async {
      final rows = <MealWithItems>[];
      for (final meal in meals) {
        final items =
            await (_database.select(_database.mealItems)..where(
                  (tbl) => tbl.mealId.equals(meal.id) & tbl.deletedAt.isNull(),
                ))
                .get();
        rows.add(MealWithItems(meal: meal, items: items));
      }
      return rows;
    });
  }

  Stream<List<MealWithItems>> watchAll() {
    final query = _database.select(_database.meals)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.date)]);
    return query.watch().asyncMap((meals) async {
      final rows = <MealWithItems>[];
      for (final meal in meals) {
        final items =
            await (_database.select(_database.mealItems)..where(
                  (row) => row.mealId.equals(meal.id) & row.deletedAt.isNull(),
                ))
                .get();
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
