part of 'meal_repository.dart';

/// Shared local-database lookup, day closure and food quantity guards.
extension _MealRepositoryValidation on MealRepository {
  Future<MealItem> _mealItem(int id) async {
    final item = await (_database.select(
      _database.mealItems,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (item == null) throw StateError('Meal item $id does not exist');
    return item;
  }

  /// Call only inside the transaction that writes the diary. A closedAt
  /// marker also fences a partially recovered legacy lifecycle state.
  Future<void> _requireOpenDayForMeals(String dayKey) async {
    final log = await (_database.select(
      _database.dailyLogs,
    )..where((row) => row.dayKey.equals(dayKey))).getSingleOrNull();
    if (log?.lifecycleState == 'closed' || log?.closedAt != null) {
      throw const CoachMealConflict(CoachMealConflictReason.closedDay);
    }
  }

  Future<void> _requireOpenMealDay(int mealId) async {
    final meal = await (_database.select(
      _database.meals,
    )..where((row) => row.id.equals(mealId))).getSingleOrNull();
    if (meal == null) throw StateError('Meal $mealId does not exist');
    await _requireOpenDayForMeals(meal.dayKey);
  }

  Future<Food> _activeFood(int id) async {
    final food =
        await (_database.select(_database.foods)
              ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
            .getSingleOrNull();
    if (food == null) throw StateError('Food $id does not exist');
    if (food.servingSize <= 0) {
      throw StateError('Food $id has an invalid serving size');
    }
    return food;
  }

  void _validateQuantity(double quantity) {
    if (!quantity.isFinite || quantity <= 0 || quantity > 100000) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be 0–100000');
    }
  }
}
