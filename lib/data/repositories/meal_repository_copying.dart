part of 'meal_repository.dart';

extension MealRepositoryCopying on MealRepository {
  Future<void> repeatMeal({
    required UsualMealCandidate candidate,
    required DateTime date,
  }) => repeatHistoricalMeal(meal: candidate.source, date: date);

  Future<void> repeatHistoricalMeal({
    required MealWithItems meal,
    required DateTime date,
  }) async {
    await _database.transaction(() async {
      final mealId = await createMeal(
        date: date,
        name: meal.meal.name,
        type: meal.meal.type,
      );
      for (var index = 0; index < meal.items.length; index++) {
        final item = meal.items[index];
        await _database
            .into(_database.mealItems)
            .insert(
              MealItemsCompanion.insert(
                mealId: mealId,
                foodId: item.foodId,
                quantity: Value(item.quantity),
                position: Value(index + 1),
                calories: Value(item.calories),
                protein: Value(item.protein),
                carbs: Value(item.carbs),
                fats: Value(item.fats),
                fiber: Value(item.fiber),
                sodium: Value(item.sodium),
                potassium: Value(item.potassium),
                calcium: Value(item.calcium),
                magnesium: Value(item.magnesium),
                phosphorus: Value(item.phosphorus),
                sugar: Value(item.sugar),
                nutrientEvidenceMask: Value(item.nutrientEvidenceMask),
              ),
            );
      }
    });
  }

  Future<int> copyDay({
    required DateTime sourceDate,
    required DateTime destinationDate,
  }) async {
    final sourceKey = dayKeyFor(sourceDate);
    final destinationKey = dayKeyFor(destinationDate);
    if (sourceKey == destinationKey) {
      throw ArgumentError('Source and destination days must be different.');
    }

    return _database.transaction(() async {
      final existingDestination =
          await (_database.select(_database.meals)..where(
                (row) =>
                    row.dayKey.equals(destinationKey) & row.deletedAt.isNull(),
              ))
              .get();
      if (existingDestination.isNotEmpty) {
        throw StateError('Destination day already contains meals.');
      }

      final sourceMeals =
          await (_database.select(_database.meals)
                ..where(
                  (row) =>
                      row.dayKey.equals(sourceKey) & row.deletedAt.isNull(),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.date),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      var copied = 0;
      for (final sourceMeal in sourceMeals) {
        final destinationMealId = await _database
            .into(_database.meals)
            .insert(
              MealsCompanion.insert(
                date: destinationDate,
                dayKey: destinationKey,
                name: Value(sourceMeal.name),
                type: Value(sourceMeal.type),
              ),
            );
        final sourceItems =
            await (_database.select(_database.mealItems)
                  ..where(
                    (item) =>
                        item.mealId.equals(sourceMeal.id) &
                        item.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (item) => OrderingTerm.asc(item.position),
                    (item) => OrderingTerm.asc(item.id),
                  ]))
                .get();
        for (final item in sourceItems) {
          await _activeFood(item.foodId);
          await _database
              .into(_database.mealItems)
              .insert(
                MealItemsCompanion.insert(
                  mealId: destinationMealId,
                  foodId: item.foodId,
                  quantity: Value(item.quantity),
                  position: Value(item.position),
                  calories: Value(item.calories),
                  protein: Value(item.protein),
                  carbs: Value(item.carbs),
                  fats: Value(item.fats),
                  fiber: Value(item.fiber),
                  sodium: Value(item.sodium),
                  potassium: Value(item.potassium),
                  calcium: Value(item.calcium),
                  magnesium: Value(item.magnesium),
                  phosphorus: Value(item.phosphorus),
                  sugar: Value(item.sugar),
                  nutrientEvidenceMask: Value(item.nutrientEvidenceMask),
                ),
              );
        }
        copied++;
      }
      return copied;
    });
  }

  /// Copies one authoritative diary day to several empty destination days.
  ///
  /// All destinations are validated before the first write. The enclosing
  /// transaction makes this all-or-nothing, so a conflicting day cannot leave
  /// a partially copied multi-day plan.
  Future<Map<DateTime, int>> copyDayToDates({
    required DateTime sourceDate,
    required Iterable<DateTime> destinationDates,
  }) async {
    final sourceKey = dayKeyFor(sourceDate);
    final byKey = <String, DateTime>{};
    for (final date in destinationDates) {
      final key = dayKeyFor(date);
      if (key == sourceKey) {
        throw ArgumentError('Source cannot also be a destination day.');
      }
      byKey[key] = DateTime(date.year, date.month, date.day);
    }
    if (byKey.length < 2 || byKey.length > 30) {
      throw ArgumentError('Choose between 2 and 30 distinct destination days.');
    }
    return _database.transaction(() async {
      for (final key in byKey.keys) {
        final occupied =
            await (_database.select(_database.meals)
                  ..where(
                    (row) => row.dayKey.equals(key) & row.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (occupied != null) {
          throw StateError('A destination day already contains meals.');
        }
      }
      final result = <DateTime, int>{};
      for (final date in byKey.values) {
        result[date] = await copyDay(
          sourceDate: sourceDate,
          destinationDate: date,
        );
      }
      return result;
    });
  }

  Future<DailyNutritionReport> analyzeDay({
    required DateTime date,
    required int waterMl,
    required DailyNutritionTargets targets,
    DietaryPreferences dietaryPreferences = const DietaryPreferences(),
  }) async {
    final key = dayKeyFor(date);
    final meals = await (_database.select(
      _database.meals,
    )..where((row) => row.dayKey.equals(key) & row.deletedAt.isNull())).get();
    final snapshots = <DailyNutritionItemSnapshot>[];
    for (final meal in meals) {
      final items =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(meal.id) & item.deletedAt.isNull(),
              ))
              .get();
      for (final item in items) {
        snapshots.add(
          DailyNutritionItemSnapshot(
            calories: item.calories,
            protein: item.protein,
            carbohydrates: item.carbs,
            fat: item.fats,
            fiber: item.fiber,
            sodium: item.sodium,
            potassium: item.potassium,
            fiberKnown: NutrientEvidenceMask.contains(
              item.nutrientEvidenceMask,
              TrackedNutrient.fiber,
            ),
            sodiumKnown: NutrientEvidenceMask.contains(
              item.nutrientEvidenceMask,
              TrackedNutrient.sodium,
            ),
            potassiumKnown: NutrientEvidenceMask.contains(
              item.nutrientEvidenceMask,
              TrackedNutrient.potassium,
            ),
          ),
        );
      }
    }
    return _dailyNutritionEngine.analyze(
      items: snapshots,
      mealCount: meals.length,
      waterMl: waterMl,
      targets: targets,
      dietaryPreferences: dietaryPreferences,
    );
  }

  Future<Map<int, Food>> _foodsForItems(List<MealItem> items) async {
    final ids = items.map((item) => item.foodId).toSet();
    if (ids.isEmpty) return const {};
    final foods = await (_database.select(
      _database.foods,
    )..where((food) => food.id.isIn(ids))).get();
    return {for (final food in foods) food.id: food};
  }
}
