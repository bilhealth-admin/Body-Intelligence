import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';

void main() {
  late AppDatabase db;
  late MealRepository meals;
  late int foodId;
  final day = DateTime(2026, 10, 11);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    meals = MealRepository(db);
    foodId = await FoodRepository(db).addFood(
      name: 'Food',
      category: 'food',
      calories: 100,
      protein: 10,
      carbs: 10,
      fats: 2,
      fiber: 3,
      servingSize: 100,
      servingUnit: 'g',
    );
  });
  tearDown(() => db.close());
  MealBuilderDraft draft() => MealBuilderDraft(
    name: 'Lunch',
    mealType: 'lunch',
    items: [
      MealBuilderItemDraft(foodId: foodId, quantityGrams: 100, position: 1),
    ],
  );
  test(
    'existing food cannot be overwritten; explicit append preserves it',
    () async {
      await meals.createMealFromDraft(draft: draft(), date: day);
      await expectLater(
        meals.createMealFromDraft(draft: draft(), date: day),
        throwsStateError,
      );
      expect(await db.select(db.mealItems).get(), hasLength(1));
      await meals.createMealFromDraft(
        draft: draft(),
        date: day,
        appendToExisting: true,
      );
      expect(await db.select(db.mealItems).get(), hasLength(2));
    },
  );
  test(
    'copy uses the selected date and destination without changing source',
    () async {
      await meals.createMealFromDraft(draft: draft(), date: day);
      final source = (await meals.watchAll().first).single;
      final template = meals.createTemplateFromHistoricalMeal(
        meal: source,
        templateId: 'test-copy',
        templateName: 'copy',
      );
      await meals.instantiateTemplate(
        template: template,
        date: DateTime(2026, 10, 12),
        destinationMealType: 'dinner',
      );
      final all = await meals.watchAll().first;
      expect(all, hasLength(2));
      expect(
        all
            .singleWhere((row) => row.meal.type == 'dinner')
            .items
            .single
            .calories,
        100,
      );
      expect(
        all.singleWhere((row) => row.meal.type == 'lunch').items,
        hasLength(1),
      );
    },
  );
  test(
    'fractional recipe serving scales all evidenced nutrients consistently',
    () async {
      await meals.addCalculatedRecipeServingAtomically(
        date: day,
        mealType: 'lunch',
        foodUuid: 'fractional-recipe',
        recipeName: 'Recipe',
        source: 'user-reviewed-calculation',
        calories: 200,
        protein: 20,
        carbohydrates: 25,
        fat: 4,
        fiber: 6,
        sodium: 100,
        servings: 1.5,
      );
      final item = await db.select(db.mealItems).getSingle();
      expect(item.calories, 300);
      expect(item.protein, 30);
      expect(item.fiber, 9);
      expect(item.sodium, 150);
    },
  );
}
