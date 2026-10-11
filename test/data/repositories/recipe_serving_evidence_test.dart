import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MealRepository meals;
  final day = DateTime(2026, 10, 11);
  final owner = LocalDatabaseScope.keyForOwner('recipe-owner');
  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'recipe-owner',
    );
    meals = MealRepository(db);
  });
  tearDown(() => db.close());

  Future<MealItem> log({double? iron = 2, double? vitaminC = 12}) async {
    await meals.addCalculatedRecipeServingAtomically(
      date: day,
      mealType: 'lunch',
      foodUuid: 'reviewed-recipe-snapshot',
      recipeName: 'سلطة الفاصوليا',
      source: 'reviewed-exact-ingredient-snapshot',
      calories: 200,
      protein: 20,
      carbohydrates: 25,
      fat: 4,
      fiber: 6,
      sodium: 100,
      iron: iron,
      vitaminC: vitaminC,
      servings: 1.5,
    );
    return db.select(db.mealItems).getSingle();
  }

  test(
    'fractional servings retain all 13 fields without inventing grams',
    () async {
      final item = await log();
      final evidence = MealFoodEvidence.read(item, ownerKey: owner);
      expect(evidence.isValid, isTrue);
      expect(evidence.foodName, 'سلطة الفاصوليا');
      expect(evidence.portion, isNull);
      expect(item.servingUnitSnapshot, 'serving');
      expect(item.quantity, 1.5);
      expect(evidence.fullValue(FoodNutrient.calories), 300);
      expect(evidence.fullValue(FoodNutrient.fiber), 9);
      expect(evidence.fullValue(FoodNutrient.sodium), 150);
      expect(evidence.fullValue(FoodNutrient.iron), 3);
      expect(evidence.fullValue(FoodNutrient.vitaminC), 18);
      expect(evidence.fullValue(FoodNutrient.magnesium), isNull);
    },
  );

  test('known zero is different from an unavailable nutrient', () async {
    final item = await log(iron: 0, vitaminC: null);
    final evidence = MealFoodEvidence.read(item, ownerKey: owner);
    expect(evidence.fullValue(FoodNutrient.iron), 0);
    expect(evidence.fullValue(FoodNutrient.vitaminC), isNull);
  });

  test(
    'editing portion reuses immutable nutrition, never updated catalog',
    () async {
      final original = await log();
      await (db.update(
        db.foods,
      )..where((f) => f.id.equals(original.foodId))).write(
        const FoodsCompanion(
          iron: Value(999),
          vitaminC: Value(888),
          name: Value('Changed name'),
        ),
      );
      await meals.updateMealItem(id: original.id, quantity: .5);
      final saved = await meals.getMealItem(original.id);
      final evidence = MealFoodEvidence.read(saved, ownerKey: owner);
      expect(evidence.isValid, isTrue);
      expect(evidence.foodName, 'سلطة الفاصوليا');
      expect(evidence.fullValue(FoodNutrient.iron), 1);
      expect(evidence.fullValue(FoodNutrient.vitaminC), 6);
      expect(evidence.fullValue(FoodNutrient.calories), 100);
    },
  );

  test(
    'explicit historical copy preserves serving evidence and source',
    () async {
      final original = await log();
      final source = (await meals.watchAll().first).single;
      final template = meals.createTemplateFromHistoricalMeal(
        meal: source,
        templateId: 'recipe-copy',
        templateName: 'Copy',
      );
      await meals.instantiateTemplate(
        template: template,
        date: DateTime(2026, 10, 12),
        destinationMealType: 'dinner',
      );
      final copy = (await meals.watchAll().first)
          .singleWhere((m) => m.meal.type == 'dinner')
          .items
          .single;
      expect(copy.foodEvidenceJson, original.foodEvidenceJson);
      expect(
        MealFoodEvidence.read(
          copy,
          ownerKey: owner,
        ).fullValue(FoodNutrient.iron),
        3,
      );
      expect((await meals.getMealItem(original.id)).quantity, 1.5);
    },
  );

  test(
    'wrong owner and missing envelope fail closed without legacy fallback',
    () async {
      final item = await log();
      final wrong = MealFoodEvidence.read(item, ownerKey: 'other-account');
      expect(wrong.isValid, isFalse);
      expect(wrong.fullValue(FoodNutrient.iron), isNull);
      final missing = item.copyWith(foodEvidenceJson: const Value(null));
      expect(MealFoodEvidence.read(missing, ownerKey: owner).isValid, isFalse);
    },
  );

  test(
    'changed projection, malformed JSON and unknown schema are unavailable',
    () async {
      final item = await log();
      final badProjection = item.copyWith(calories: item.calories + 1);
      expect(
        MealFoodEvidence.read(badProjection, ownerKey: owner).isValid,
        isFalse,
      );
      final encoded =
          jsonDecode(item.foodEvidenceJson!) as Map<String, dynamic>;
      encoded['schema'] = 'unknown';
      for (final raw in ['{bad', jsonEncode(encoded)]) {
        final altered = item.copyWith(foodEvidenceJson: Value(raw));
        expect(
          MealFoodEvidence.read(altered, ownerKey: owner).isValid,
          isFalse,
        );
      }
    },
  );

  test('invalid serving update rolls back the whole snapshot', () async {
    final item = await log();
    await expectLater(
      meals.updateMealItem(id: item.id, quantity: 101),
      throwsFormatException,
    );
    expect(await meals.getMealItem(item.id), item);
  });
}
