import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';
import '../database/nutrient_evidence.dart';
import '../../features/nutrition/adapters/unified_food_adapter.dart';
import '../../features/nutrition/domain/daily_nutrition_intelligence.dart';
import '../../features/nutrition/domain/meal_builder.dart';
import '../../features/nutrition/domain/meal_template.dart';
import '../../features/nutrition/domain/unified_food.dart';
import '../../features/nutrition/services/daily_nutrition_intelligence_engine.dart';
import '../../features/nutrition/services/meal_builder_engine.dart';
import '../../features/nutrition/services/meal_template_engine.dart';
import '../../features/nutrition/services/nutrition_calculation_engine.dart';

class MealRepository {
  final AppDatabase _database;
  final UnifiedFoodAdapter _foodAdapter;
  final NutritionCalculationEngine _nutritionEngine;
  final MealTemplateEngine _mealTemplateEngine;
  final MealBuilderEngine _mealBuilderEngine;
  final DailyNutritionIntelligenceEngine _dailyNutritionEngine;

  MealRepository(
    this._database, {
    this._foodAdapter = const UnifiedFoodAdapter(),
    this._nutritionEngine = const NutritionCalculationEngine(),
    this._mealTemplateEngine = const MealTemplateEngine(),
    this._mealBuilderEngine = const MealBuilderEngine(),
    this._dailyNutritionEngine = const DailyNutritionIntelligenceEngine(),
  });

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
  }) async {
    _validateQuantity(quantity);
    await _database.transaction(() async {
      final food = await _activeFood(foodId);
      final portion = _calculatePortion(food, quantity);
      final siblings =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(mealId) & item.deletedAt.isNull(),
              ))
              .get();
      final nextPosition =
          siblings.fold<int>(
            0,
            (maximum, item) =>
                item.position > maximum ? item.position : maximum,
          ) +
          1;
      await _database
          .into(_database.mealItems)
          .insert(
            MealItemsCompanion.insert(
              mealId: mealId,
              foodId: foodId,
              quantity: Value(quantity),
              position: Value(nextPosition),
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
              foodSourceSnapshot: Value(food.source),
              foodVerifiedSnapshot: Value(food.verified),
              servingSizeSnapshot: Value(food.servingSize),
              servingUnitSnapshot: Value(food.servingUnit),
            ),
          );
    });
  }

  /// Adds a reviewed set of foods as one diary mutation.
  ///
  /// Either the meal and every item are committed, or none of them are. This
  /// is used by multi-candidate image review so a mid-write failure cannot
  /// leave a partially logged meal.
  Future<int> addReviewedMealItemsAtomically({
    required DateTime date,
    required String mealType,
    required List<({int foodId, double quantity})> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Must not be empty');
    }
    for (final item in items) {
      _validateQuantity(item.quantity);
    }
    return _database.transaction(() async {
      final mealId = await createMeal(
        date: date,
        name: mealType,
        type: mealType,
      );
      for (final item in items) {
        await addMealItem(
          mealId: mealId,
          foodId: item.foodId,
          quantity: item.quantity,
        );
      }
      return mealId;
    });
  }

  /// Persists one user-reviewed calculated recipe serving as a single commit.
  ///
  /// Calculated catalog nutrition remains explicitly unverified. The caller
  /// supplies a content-addressed [foodUuid], so later recipe edits cannot
  /// mutate an older diary snapshot.
  Future<int> addCalculatedRecipeServingAtomically({
    required DateTime date,
    required String mealType,
    required String foodUuid,
    required String recipeName,
    required String source,
    required double calories,
    required double protein,
    required double carbohydrates,
    required double fat,
  }) async {
    if (!const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType', 'Unsupported meal type');
    }
    final nutrients = [calories, protein, carbohydrates, fat];
    if (foodUuid.trim().isEmpty ||
        recipeName.trim().isEmpty ||
        source.trim().isEmpty ||
        nutrients.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Recipe snapshot fields must be finite and valid.');
    }
    final evidence = NutrientEvidenceMask.fromValues(
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
    );
    return _database.transaction(() async {
      var food =
          await (_database.select(_database.foods)
                ..where((row) => row.uuid.equals(foodUuid))
                ..limit(1))
              .getSingleOrNull();
      if (food == null) {
        final id = await _database
            .into(_database.foods)
            .insert(
              FoodsCompanion.insert(
                uuid: Value(foodUuid),
                name: recipeName.trim(),
                category: const Value('calculated-recipe'),
                servingSize: const Value(1),
                servingUnit: const Value('serving'),
                calories: calories,
                protein: protein,
                carbs: carbohydrates,
                fats: fat,
                nutrientEvidenceMask: Value(evidence),
                source: Value(source.trim()),
                verified: const Value(false),
                isCustom: const Value(true),
              ),
            );
        food = await (_database.select(
          _database.foods,
        )..where((row) => row.id.equals(id))).getSingle();
      } else {
        final exactSnapshot =
            food.name == recipeName.trim() &&
            food.category == 'calculated-recipe' &&
            food.servingSize == 1 &&
            food.servingUnit == 'serving' &&
            food.calories == calories &&
            food.protein == protein &&
            food.carbs == carbohydrates &&
            food.fats == fat &&
            food.nutrientEvidenceMask == evidence &&
            food.source == source.trim() &&
            !food.verified &&
            food.deletedAt == null;
        if (!exactSnapshot) {
          throw StateError(
            'Recipe snapshot identity conflicts with stored food',
          );
        }
      }
      final mealId = await createMeal(
        date: date,
        name: mealType,
        type: mealType,
      );
      final siblings =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(mealId) & item.deletedAt.isNull(),
              ))
              .get();
      final position =
          siblings.fold<int>(
            0,
            (maximum, item) =>
                item.position > maximum ? item.position : maximum,
          ) +
          1;
      await _database
          .into(_database.mealItems)
          .insert(
            MealItemsCompanion.insert(
              mealId: mealId,
              foodId: food.id,
              quantity: const Value(1),
              position: Value(position),
              calories: Value(calories),
              protein: Value(protein),
              carbs: Value(carbohydrates),
              fats: Value(fat),
              nutrientEvidenceMask: Value(evidence),
              foodSourceSnapshot: Value(source.trim()),
              foodVerifiedSnapshot: const Value(false),
              servingSizeSnapshot: const Value(1),
              servingUnitSnapshot: const Value('serving'),
            ),
          );
      return mealId;
    });
  }

  /// Records a user-entered calorie/macro snapshot without inventing a food.
  ///
  /// The timestamp is preserved in the immutable food snapshot label because
  /// legacy meal items do not have a dedicated occurred-at column.
  Future<int> addQuickMacroEntry({
    required DateTime date,
    required String mealType,
    required double calories,
    required double protein,
    required double carbohydrates,
    required double fat,
    required bool caloriesKnown,
    required bool proteinKnown,
    required bool carbohydratesKnown,
    required bool fatKnown,
    DateTime? occurredAt,
  }) async {
    if (!const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType', 'Unsupported meal type');
    }
    final values = [calories, protein, carbohydrates, fat];
    final known = [caloriesKnown, proteinKnown, carbohydratesKnown, fatKnown];
    if (List.generate(
      values.length,
      (index) => !known[index] && values[index] != 0,
    ).any((mismatch) => mismatch)) {
      throw ArgumentError('An unknown Quick Add nutrient must have value 0.');
    }
    if (values.any((value) => !value.isFinite || value < 0) ||
        calories > 10000 ||
        protein > 2000 ||
        carbohydrates > 2000 ||
        fat > 2000 ||
        !known.any((value) => value) ||
        List.generate(
          values.length,
          (index) => known[index] ? values[index] : 0,
        ).every((value) => value == 0)) {
      throw ArgumentError(
        'Quick Add values must be finite, non-negative, and not all zero.',
      );
    }
    final clock = occurredAt ?? DateTime.now();
    final timestamp = DateTime(
      date.year,
      date.month,
      date.day,
      clock.hour,
      clock.minute,
    );
    return _database.transaction(() async {
      final label =
          'Quick Add • ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      final foodId = await _database
          .into(_database.foods)
          .insert(
            FoodsCompanion.insert(
              name: label,
              category: const Value('quick_add'),
              servingSize: const Value(1),
              servingUnit: const Value('entry'),
              calories: calories,
              protein: protein,
              carbs: carbohydrates,
              fats: fat,
              nutrientEvidenceMask: Value(
                NutrientEvidenceMask.fromValues(
                  calories: caloriesKnown ? calories : null,
                  protein: proteinKnown ? protein : null,
                  carbohydrates: carbohydratesKnown ? carbohydrates : null,
                  fat: fatKnown ? fat : null,
                ),
              ),
              isCustom: const Value(true),
              source: const Value('quick_add'),
            ),
          );
      final mealId = await createMeal(
        date: timestamp,
        name: mealType,
        type: mealType,
      );
      await addMealItem(mealId: mealId, foodId: foodId, quantity: 1);
      return mealId;
    });
  }

  Future<void> updateMealItem({
    required int id,
    required double quantity,
  }) async {
    _validateQuantity(quantity);
    await _database.transaction(() async {
      final existing = await _mealItem(id);
      final food = await _activeFood(existing.foodId);
      final portion = _calculatePortion(food, quantity);
      await (_database.update(
        _database.mealItems,
      )..where((row) => row.id.equals(id))).write(
        MealItemsCompanion(
          quantity: Value(quantity),
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
          updatedAt: Value(DateTime.now()),
          revision: Value(existing.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  Future<void> deleteMealItem(int id) async {
    final existing = await _mealItem(id);
    await (_database.update(
      _database.mealItems,
    )..where((row) => row.id.equals(id))).write(
      MealItemsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        revision: Value(existing.revision + 1),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }

  Future<void> moveMealItem({required int id, required int offset}) async {
    if (offset != -1 && offset != 1) {
      throw ArgumentError.value(offset, 'offset', 'Must be -1 or 1');
    }
    await _database.transaction(() async {
      final current = await _mealItem(id);
      final siblings =
          await (_database.select(_database.mealItems)
                ..where(
                  (item) =>
                      item.mealId.equals(current.mealId) &
                      item.deletedAt.isNull(),
                )
                ..orderBy([
                  (item) => OrderingTerm.asc(item.position),
                  (item) => OrderingTerm.asc(item.id),
                ]))
              .get();
      final index = siblings.indexWhere((item) => item.id == id);
      final targetIndex = index + offset;
      if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) {
        return;
      }
      final target = siblings[targetIndex];
      final now = DateTime.now();
      await (_database.update(
        _database.mealItems,
      )..where((item) => item.id.equals(current.id))).write(
        MealItemsCompanion(
          position: Value(target.position),
          updatedAt: Value(now),
          revision: Value(current.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
      await (_database.update(
        _database.mealItems,
      )..where((item) => item.id.equals(target.id))).write(
        MealItemsCompanion(
          position: Value(current.position),
          updatedAt: Value(now),
          revision: Value(target.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  /// Moves an item to a meal bucket on the same local diary day.
  ///
  /// The item identity and nutrition snapshot are preserved. The destination
  /// is resolved inside the same transaction, avoiding a partial copy/delete.
  Future<void> moveMealItemToType({
    required int id,
    required String mealType,
  }) async {
    if (!const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType');
    }
    await _database.transaction(() async {
      final item = await _mealItem(id);
      final sourceMeal =
          await (_database.select(_database.meals)..where(
                (row) => row.id.equals(item.mealId) & row.deletedAt.isNull(),
              ))
              .getSingle();
      if (sourceMeal.type == mealType) return;
      final candidates =
          await (_database.select(_database.meals)..where(
                (row) =>
                    row.dayKey.equals(sourceMeal.dayKey) &
                    row.type.equals(mealType) &
                    row.deletedAt.isNull(),
              ))
              .get();
      final destinationId = candidates.isNotEmpty
          ? candidates.first.id
          : await _database
                .into(_database.meals)
                .insert(
                  MealsCompanion.insert(
                    date: sourceMeal.date,
                    dayKey: sourceMeal.dayKey,
                    name: Value(mealType),
                    type: Value(mealType),
                  ),
                );
      final last =
          await (_database.select(_database.mealItems)
                ..where(
                  (row) =>
                      row.mealId.equals(destinationId) & row.deletedAt.isNull(),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.position)])
                ..limit(1))
              .getSingleOrNull();
      await (_database.update(
        _database.mealItems,
      )..where((row) => row.id.equals(id))).write(
        MealItemsCompanion(
          mealId: Value(destinationId),
          position: Value((last?.position ?? -1) + 1),
          updatedAt: Value(DateTime.now()),
          revision: Value(item.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  Future<int> duplicateMealItem(int id) async {
    return _database.transaction(() async {
      final source = await _mealItem(id);
      final siblings =
          await (_database.select(_database.mealItems)..where(
                (item) =>
                    item.mealId.equals(source.mealId) & item.deletedAt.isNull(),
              ))
              .get();
      final nextPosition =
          siblings.fold<int>(
            0,
            (maximum, item) =>
                item.position > maximum ? item.position : maximum,
          ) +
          1;
      return _database
          .into(_database.mealItems)
          .insert(
            MealItemsCompanion.insert(
              mealId: source.mealId,
              foodId: source.foodId,
              quantity: Value(source.quantity),
              position: Value(nextPosition),
              calories: Value(source.calories),
              protein: Value(source.protein),
              carbs: Value(source.carbs),
              fats: Value(source.fats),
              fiber: Value(source.fiber),
              sodium: Value(source.sodium),
              potassium: Value(source.potassium),
              calcium: Value(source.calcium),
              magnesium: Value(source.magnesium),
              phosphorus: Value(source.phosphorus),
              sugar: Value(source.sugar),
              nutrientEvidenceMask: Value(source.nutrientEvidenceMask),
            ),
          );
    });
  }

  NutritionPortion _calculatePortion(Food food, double quantityGrams) {
    return _nutritionEngine.calculate(
      food: _foodAdapter.adapt(food),
      grams: quantityGrams,
    );
  }

  Future<MealItem> _mealItem(int id) async {
    final item = await (_database.select(
      _database.mealItems,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (item == null) throw StateError('Meal item $id does not exist');
    return item;
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

class MealWithItems {
  final Meal meal;
  final List<MealItem> items;
  final Map<int, Food> foodsById;

  const MealWithItems({
    required this.meal,
    required this.items,
    this.foodsById = const {},
  });
}

class UsualMealCandidate {
  const UsualMealCandidate({required this.source, required this.occurrences});

  final MealWithItems source;
  final int occurrences;
}
