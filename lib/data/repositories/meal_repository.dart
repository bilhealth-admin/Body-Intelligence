import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';
import '../../features/nutrition/adapters/unified_food_adapter.dart';
import '../../features/nutrition/domain/meal_builder.dart';
import '../../features/nutrition/domain/meal_template.dart';
import '../../features/nutrition/domain/unified_food.dart';
import '../../features/nutrition/services/meal_builder_engine.dart';
import '../../features/nutrition/services/meal_template_engine.dart';
import '../../features/nutrition/services/nutrition_calculation_engine.dart';

class MealRepository {
  final AppDatabase _database;
  final UnifiedFoodAdapter _foodAdapter;
  final NutritionCalculationEngine _nutritionEngine;
  final MealTemplateEngine _mealTemplateEngine;
  final MealBuilderEngine _mealBuilderEngine;

  MealRepository(
    this._database, {
    UnifiedFoodAdapter foodAdapter = const UnifiedFoodAdapter(),
    NutritionCalculationEngine nutritionEngine =
        const NutritionCalculationEngine(),
    MealTemplateEngine mealTemplateEngine = const MealTemplateEngine(),
    MealBuilderEngine mealBuilderEngine = const MealBuilderEngine(),
  }) : _foodAdapter = foodAdapter,
       _nutritionEngine = nutritionEngine,
       _mealTemplateEngine = mealTemplateEngine,
       _mealBuilderEngine = mealBuilderEngine;

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
              sugar: Value(portion.valueOrZero(FoodNutrient.sugar)),
              nutrientEvidenceMask: Value(portion.nutrientEvidenceMask),
            ),
          );
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

    final query = _database.select(_database.meals)
      ..where((tbl) => tbl.dayKey.equals(key) & tbl.deletedAt.isNull());

    return query.watch().asyncMap((meals) async {
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
    final query = _database.select(_database.meals)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.date)]);
    return query.watch().asyncMap((meals) async {
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
                sugar: Value(item.sugar),
                nutrientEvidenceMask: Value(item.nutrientEvidenceMask),
              ),
            );
      }
    });
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
