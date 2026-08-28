part of 'meal_repository.dart';

extension MealRepositoryQueries on MealRepository {
  Stream<List<MealWithItems>> watchMealsForDate(DateTime date) {
    final key = dayKeyFor(date);
    final invalidations = _database.customSelect(
      'SELECT 1 AS marker',
      readsFrom: {_database.meals, _database.mealItems},
    );

    return invalidations.watch().asyncMap((_) async {
      final meals = await (_database.select(
        _database.meals,
      )..where((tbl) => tbl.dayKey.equals(key) & tbl.deletedAt.isNull())).get();
      final rows = <MealWithItems>[];
      for (final meal in meals) {
        final items =
            await (_database.select(_database.mealItems)
                  ..where(
                    (tbl) =>
                        tbl.mealId.equals(meal.id) & tbl.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (item) => OrderingTerm.asc(item.position),
                    (item) => OrderingTerm.asc(item.id),
                  ]))
                .get();
        rows.add(
          MealWithItems(
            meal: meal,
            items: items,
            foodsById: await _foodsForItems(items),
          ),
        );
      }
      return rows;
    });
  }

  Stream<List<MealWithItems>> watchAll() {
    final invalidations = _database.customSelect(
      'SELECT 1 AS marker',
      readsFrom: {_database.meals, _database.mealItems},
    );
    return invalidations.watch().asyncMap((_) async {
      final meals =
          await (_database.select(_database.meals)
                ..where((row) => row.deletedAt.isNull())
                ..orderBy([(row) => OrderingTerm.asc(row.date)]))
              .get();
      final rows = <MealWithItems>[];
      for (final meal in meals) {
        final items =
            await (_database.select(_database.mealItems)
                  ..where(
                    (row) =>
                        row.mealId.equals(meal.id) & row.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (item) => OrderingTerm.asc(item.position),
                    (item) => OrderingTerm.asc(item.id),
                  ]))
                .get();
        rows.add(
          MealWithItems(
            meal: meal,
            items: items,
            foodsById: await _foodsForItems(items),
          ),
        );
      }
      return rows;
    });
  }

  Future<List<UsualMealCandidate>> usualMeals({
    required String type,
    DateTime? before,
    int lookbackDays = 60,
  }) async {
    final cutoff = (before ?? DateTime.now()).subtract(
      Duration(days: lookbackDays),
    );
    final meals =
        await (_database.select(_database.meals)
              ..where(
                (row) =>
                    row.type.equals(type) &
                    row.date.isBiggerOrEqualValue(cutoff) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.date)]))
            .get();
    final grouped = <String, List<MealWithItems>>{};
    for (final meal in meals) {
      final items =
          await (_database.select(_database.mealItems)
                ..where(
                  (row) => row.mealId.equals(meal.id) & row.deletedAt.isNull(),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.foodId)]))
              .get();
      if (items.isEmpty) continue;
      final signature = items
          .map((item) => '${item.foodId}:${item.quantity.toStringAsFixed(1)}')
          .join('|');
      grouped
          .putIfAbsent(signature, () => [])
          .add(
            MealWithItems(
              meal: meal,
              items: items,
              foodsById: await _foodsForItems(items),
            ),
          );
    }
    final candidates =
        grouped.values
            .where((matches) => matches.length >= 2)
            .map(
              (matches) => UsualMealCandidate(
                source: matches.first,
                occurrences: matches.length,
              ),
            )
            .toList()
          ..sort((a, b) {
            final frequency = b.occurrences.compareTo(a.occurrences);
            return frequency != 0
                ? frequency
                : b.source.meal.date.compareTo(a.source.meal.date);
          });
    return candidates.take(3).toList(growable: false);
  }

  Future<int> createMealFromDraft({
    required MealBuilderDraft draft,
    required DateTime date,
  }) async {
    final canonical = _mealBuilderEngine.canonicalize(draft);
    return _database.transaction(() async {
      final mealId = await createMeal(
        date: date,
        name: canonical.name,
        type: canonical.mealType,
      );
      final existingItems =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(mealId) & item.deletedAt.isNull(),
              ))
              .get();
      if (existingItems.isNotEmpty) {
        throw StateError(
          'Cannot build a meal over an existing meal that already has items',
        );
      }

      for (final item in canonical.items) {
        final food = await _activeFood(item.foodId);
        final portion = _calculatePortion(food, item.quantityGrams);
        await _database
            .into(_database.mealItems)
            .insert(
              MealItemsCompanion.insert(
                mealId: mealId,
                foodId: item.foodId,
                quantity: Value(item.quantityGrams),
                position: Value(item.position),
                calories: Value(portion.valueOrZero(FoodNutrient.calories)),
                protein: Value(portion.valueOrZero(FoodNutrient.protein)),
                carbs: Value(portion.valueOrZero(FoodNutrient.carbohydrates)),
                fats: Value(portion.valueOrZero(FoodNutrient.fat)),
                fiber: Value(portion.valueOrZero(FoodNutrient.fiber)),
                sodium: Value(portion.valueOrZero(FoodNutrient.sodium)),
                potassium: Value(portion.valueOrZero(FoodNutrient.potassium)),
                calcium: Value(portion.valueOrZero(FoodNutrient.calcium)),
                magnesium: Value(portion.valueOrZero(FoodNutrient.magnesium)),
                phosphorus: Value(portion.valueOrZero(FoodNutrient.phosphorus)),
                sugar: Value(portion.valueOrZero(FoodNutrient.sugar)),
                nutrientEvidenceMask: Value(portion.nutrientEvidenceMask),
              ),
            );
      }
      return mealId;
    });
  }

  MealTemplate createTemplateFromHistoricalMeal({
    required MealWithItems meal,
    required String templateId,
    required String templateName,
    DateTime? createdAt,
  }) {
    return _mealTemplateEngine.fromHistoricalMeal(
      meal: meal.meal,
      items: meal.items,
      templateId: templateId,
      templateName: templateName,
      createdAt: createdAt,
    );
  }

  Future<int> instantiateTemplate({
    required MealTemplate template,
    required DateTime date,
  }) async {
    _mealTemplateEngine.validateForInstantiation(template);
    return _database.transaction(() async {
      final mealId = await createMeal(
        date: date,
        name: template.name,
        type: template.mealType,
      );
      final existingItems =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(mealId) & item.deletedAt.isNull(),
              ))
              .get();
      if (existingItems.isNotEmpty) {
        throw StateError(
          'Cannot instantiate a template into a meal that already has items',
        );
      }

      final ordered = List<MealTemplateItem>.from(template.items)
        ..sort((left, right) => left.position.compareTo(right.position));
      for (final item in ordered) {
        await _activeFood(item.foodId);
        await _database
            .into(_database.mealItems)
            .insert(
              MealItemsCompanion.insert(
                mealId: mealId,
                foodId: item.foodId,
                quantity: Value(item.quantityGrams),
                position: Value(item.position),
                calories: Value(item.calories),
                protein: Value(item.protein),
                carbs: Value(item.carbohydrates),
                fats: Value(item.fat),
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
      return mealId;
    });
  }
}
