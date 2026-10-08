import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';
import '../database/nutrient_evidence.dart';
import '../database/meal_food_evidence.dart';
import '../database/food_basis_evidence.dart';
import '../database/database_scope.dart';
import '../../features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'preferences_repository.dart';
import '../../features/nutrition/adapters/unified_food_adapter.dart';
import '../../features/nutrition/domain/daily_nutrition_intelligence.dart';
import '../../features/nutrition/domain/dietary_preferences.dart';
import '../../features/nutrition/domain/meal_builder.dart';
import '../../features/nutrition/domain/meal_template.dart';
import '../../features/nutrition/services/daily_nutrition_intelligence_engine.dart';
import '../../features/nutrition/services/meal_builder_engine.dart';
import '../../features/nutrition/services/meal_template_engine.dart';
import '../../features/nutrition/services/nutrition_calculation_engine.dart';
part 'meal_repository_models.dart';
part 'meal_repository_copying.dart';
part 'meal_repository_queries.dart';
part 'meal_repository_coach_models.dart';
part 'meal_repository_coach_commands.dart';
part 'meal_repository_coach_journal.dart';
part 'meal_repository_coach_undo.dart';
part 'meal_repository_coach_food.dart';
part 'meal_repository_food_portions.dart';

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
    return _database.transaction(() async {
      await _requireOpenDayForMeals(key);
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
    });
  }

  Future<void> addMealItem({
    required int mealId,
    required int foodId,
    required double quantity,
    bool quantityInGrams = false,
  }) async {
    _validateQuantity(quantity);
    await _database.transaction(() async {
      await _requireOpenMealDay(mealId);
      final food = await _activeFood(foodId);
      final values = _mealFoodPortionValues(
        food,
        quantity,
        quantityInGrams: quantityInGrams,
      );
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
      final itemId = await _database
          .into(_database.mealItems)
          .insert(
            values.copyWith(
              mealId: Value(mealId),
              foodId: Value(foodId),
              position: Value(nextPosition),
            ),
          );
      await _verifyAddedFoodEvidence(itemId);
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
    bool quantitiesInGrams = true,
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
          quantityInGrams: quantitiesInGrams,
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
      await _requireOpenDayForMeals(dayKeyFor(date));
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
      await _requireOpenDayForMeals(dayKeyFor(timestamp));
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
      await _requireOpenMealDay(existing.mealId);
      if (existing.deletedAt != null) {
        throw StateError('Cannot change a deleted meal item');
      }
      _validateQuantity(existing.quantity);
      if (await _updateCoachFoodQuantity(existing, quantity)) return;
      // A diary item owns its historical nutrition and evidence. A catalog
      // refresh must not relabel new nutrition as that older source snapshot.
      final scale = quantity / existing.quantity;
      await (_database.update(
        _database.mealItems,
      )..where((row) => row.id.equals(id))).write(
        MealItemsCompanion(
          quantity: Value(quantity),
          calories: Value(existing.calories * scale),
          protein: Value(existing.protein * scale),
          carbs: Value(existing.carbs * scale),
          fats: Value(existing.fats * scale),
          fiber: Value(existing.fiber * scale),
          sodium: Value(existing.sodium * scale),
          potassium: Value(existing.potassium * scale),
          calcium: Value(existing.calcium * scale),
          magnesium: Value(existing.magnesium * scale),
          phosphorus: Value(existing.phosphorus * scale),
          sugar: Value(existing.sugar * scale),
          nutrientEvidenceMask: Value(existing.nutrientEvidenceMask),
          updatedAt: Value(DateTime.now()),
          revision: Value(existing.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  Future<void> deleteMealItem(int id) async {
    await _database.transaction(() async {
      final existing = await _mealItem(id);
      await _requireOpenMealDay(existing.mealId);
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
    });
  }

  Future<MealItem> getMealItem(int id) => _mealItem(id);

  Future<String> getMealTypeForItem(int id) async {
    final item = await _mealItem(id);
    final meal =
        await (_database.select(_database.meals)..where(
              (row) => row.id.equals(item.mealId) & row.deletedAt.isNull(),
            ))
            .getSingle();
    return meal.type;
  }

  Future<void> restoreMealItem(int id) async {
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.mealItems,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) throw StateError('Meal item $id does not exist');
      await _requireOpenMealDay(existing.mealId);
      await (_database.update(
        _database.mealItems,
      )..where((row) => row.id.equals(id))).write(
        MealItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
          revision: Value(existing.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  Future<void> deleteMealCascade(int mealId) async {
    await _database.transaction(() async {
      final meal = await (_database.select(
        _database.meals,
      )..where((row) => row.id.equals(mealId))).getSingleOrNull();
      if (meal == null) return;
      await _requireOpenDayForMeals(meal.dayKey);
      final now = DateTime.now();
      await (_database.update(
        _database.mealItems,
      )..where((row) => row.mealId.equals(mealId))).write(
        MealItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pendingDelete'),
        ),
      );
      await (_database.update(
        _database.meals,
      )..where((row) => row.id.equals(mealId))).write(
        MealsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(meal.revision + 1),
          syncStatus: const Value('pendingDelete'),
        ),
      );
    });
  }

  Future<void> moveMealItem({required int id, required int offset}) async {
    if (offset != -1 && offset != 1) {
      throw ArgumentError.value(offset, 'offset', 'Must be -1 or 1');
    }
    await _database.transaction(() async {
      final current = await _mealItem(id);
      await _requireOpenMealDay(current.mealId);
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
      await _requireOpenDayForMeals(sourceMeal.dayKey);
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
      await _requireOpenMealDay(source.mealId);
      if (!MealFoodEvidence.read(source, ownerKey: _coachOwnerKey).isValid) {
        throw const CoachMealConflict(CoachMealConflictReason.invalidEvidence);
      }
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
              foodSourceSnapshot: Value(source.foodSourceSnapshot),
              foodEvidenceJson: Value(source.foodEvidenceJson),
              foodVerifiedSnapshot: Value(source.foodVerifiedSnapshot),
              servingSizeSnapshot: Value(source.servingSizeSnapshot),
              servingUnitSnapshot: Value(source.servingUnitSnapshot),
            ),
          );
    });
  }

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
