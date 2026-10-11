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
            ownerKey: _coachOwnerKey,
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
      if (meals.isEmpty) return const <MealWithItems>[];

      // The dashboard and analytics pages subscribe to this stream together.
      // The old implementation issued two extra queries per meal (items then
      // foods), which made a large diary block the UI while the first frame
      // was being assembled. Fetch the same data in three bounded queries and
      // rebuild the exact model shape in memory.
      final mealIds = meals.map((meal) => meal.id).toList(growable: false);
      final items =
          await (_database.select(_database.mealItems)
                ..where(
                  (row) => row.mealId.isIn(mealIds) & row.deletedAt.isNull(),
                )
                ..orderBy([
                  (item) => OrderingTerm.asc(item.mealId),
                  (item) => OrderingTerm.asc(item.position),
                  (item) => OrderingTerm.asc(item.id),
                ]))
              .get();
      final foodsById = await _foodsForItems(items);
      final itemsByMeal = <int, List<MealItem>>{};
      for (final item in items) {
        itemsByMeal.putIfAbsent(item.mealId, () => <MealItem>[]).add(item);
      }
      return [
        for (final meal in meals)
          MealWithItems(
            meal: meal,
            ownerKey: _coachOwnerKey,
            items: itemsByMeal[meal.id] ?? const <MealItem>[],
            foodsById: {
              for (final item in itemsByMeal[meal.id] ?? const <MealItem>[])
                if (foodsById.containsKey(item.foodId))
                  item.foodId: foodsById[item.foodId]!,
            },
          ),
      ];
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
              ownerKey: _coachOwnerKey,
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
    bool appendToExisting = false,
  }) async {
    final canonical = _mealBuilderEngine.canonicalize(draft);
    return _database.transaction(() async {
      final firstFood = await _firstFoodMilestoneBeforeInsert();
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
      if (existingItems.isNotEmpty && !appendToExisting) {
        throw StateError(
          'Cannot build a meal over an existing meal that already has items',
        );
      }

      final offset = existingItems.fold<int>(
        0,
        (value, item) => item.position > value ? item.position : value,
      );
      if (existingItems.isEmpty) {
        await (_database.update(_database.meals)
              ..where((row) => row.id.equals(mealId)))
            .write(MealsCompanion(name: Value(canonical.name)));
      }
      for (final item in canonical.items) {
        final food = await _activeFood(item.foodId);
        final values = _mealFoodPortionValues(
          food,
          item.quantityGrams,
          quantityInGrams: true,
        );
        final itemId = await _database
            .into(_database.mealItems)
            .insert(
              values.copyWith(
                mealId: Value(mealId),
                foodId: Value(item.foodId),
                position: Value(offset + item.position),
              ),
            );
        await _verifyAddedFoodEvidence(itemId);
      }
      await _firstFoodMilestoneAfterInsert(firstFood);
      return mealId;
    });
  }

  MealTemplate createTemplateFromHistoricalMeal({
    required MealWithItems meal,
    required String templateId,
    required String templateName,
    DateTime? createdAt,
  }) {
    if (meal.ownerKey != null && meal.ownerKey != _coachOwnerKey) {
      throw const CoachMealConflict(CoachMealConflictReason.ownerChanged);
    }
    for (final item in meal.items) {
      if (!MealFoodEvidence.read(item, ownerKey: _coachOwnerKey).isValid) {
        throw const CoachMealConflict(CoachMealConflictReason.invalidEvidence);
      }
    }
    final source = _mealTemplateEngine.fromHistoricalMeal(
      meal: meal.meal,
      items: meal.items,
      templateId: templateId,
      templateName: templateName,
      createdAt: createdAt,
    );
    return MealTemplate(
      id: source.id,
      name: source.name,
      mealType: source.mealType,
      items: source.items,
      createdAt: source.createdAt,
      sourceMealUuid: source.sourceMealUuid,
      ownerKey: _coachOwnerKey,
    );
  }

  Future<int> instantiateTemplate({
    required MealTemplate template,
    required DateTime date,
    bool appendToExisting = false,
    String? destinationMealType,
  }) async {
    if (template.ownerKey != null && template.ownerKey != _coachOwnerKey) {
      throw const CoachMealConflict(CoachMealConflictReason.ownerChanged);
    }
    _mealTemplateEngine.validateForInstantiation(template);
    return _database.transaction(() async {
      final firstFood = await _firstFoodMilestoneBeforeInsert();
      final mealId = await createMeal(
        date: date,
        name: template.name,
        type: destinationMealType ?? template.mealType,
      );
      final existingItems =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(mealId) & item.deletedAt.isNull(),
              ))
              .get();
      if (existingItems.isNotEmpty && !appendToExisting) {
        throw StateError(
          'Cannot instantiate a template into a meal that already has items',
        );
      }

      final offset = existingItems.fold<int>(
        0,
        (value, item) => item.position > value ? item.position : value,
      );
      final ordered = List<MealTemplateItem>.from(template.items)
        ..sort((left, right) => left.position.compareTo(right.position));
      for (final item in ordered) {
        await _activeFood(item.foodId);
        final itemId = await _database
            .into(_database.mealItems)
            .insert(
              MealItemsCompanion.insert(
                mealId: mealId,
                foodId: item.foodId,
                quantity: Value(item.quantityGrams),
                position: Value(offset + item.position),
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
                foodEvidenceJson: Value(item.foodEvidenceJson),
                foodSourceSnapshot: Value(item.foodSourceSnapshot),
                foodVerifiedSnapshot: Value(item.foodVerifiedSnapshot),
                servingSizeSnapshot: Value(item.servingSizeSnapshot),
                servingUnitSnapshot: Value(item.servingUnitSnapshot),
              ),
            );
        if (!MealFoodEvidence.read(
          await _mealItem(itemId),
          ownerKey: _coachOwnerKey,
        ).isValid) {
          throw const CoachMealConflict(
            CoachMealConflictReason.invalidEvidence,
          );
        }
      }
      await _firstFoodMilestoneAfterInsert(firstFood);
      return mealId;
    });
  }
}
