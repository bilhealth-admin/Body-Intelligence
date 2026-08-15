import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_diary_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late MealRepository meals;
  late TrustedRecipeDiaryService service;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    meals = MealRepository(database);
    service = TrustedRecipeDiaryService(FoodRepository(database), meals);
  });
  tearDown(() => database.close());

  test(
    'calculated recipe becomes an unverified immutable diary serving',
    () async {
      final saved = _saved(withNutrition: true);
      final day = DateTime(2026, 8, 11);
      await service.addServing(saved: saved, date: day, mealType: 'lunch');
      await service.addServing(saved: saved, date: day, mealType: 'lunch');

      final logged = await meals.watchMealsForDate(day).first;
      expect(logged, hasLength(1));
      expect(logged.single.items, hasLength(2));
      expect(logged.single.items.first.calories, 420);
      expect(logged.single.items.first.protein, 28);
      expect(logged.single.foodsById.values.single.verified, isFalse);
      expect(logged.single.items.first.foodVerifiedSnapshot, isFalse);
      expect(
        logged.single.items.first.foodSourceSnapshot,
        startsWith('recipe-calculation:'),
      );
      expect((await database.select(database.foods).get()), hasLength(1));
      final mask = logged.single.items.first.nutrientEvidenceMask;
      for (final nutrient in const [
        TrackedNutrient.calories,
        TrackedNutrient.protein,
        TrackedNutrient.carbohydrates,
        TrackedNutrient.fat,
      ]) {
        expect(NutrientEvidenceMask.contains(mask, nutrient), isTrue);
      }
      expect(
        NutrientEvidenceMask.contains(mask, TrackedNutrient.fiber),
        isFalse,
      );
    },
  );

  test('snapshot food rolls back when the meal item insert fails', () async {
    await database.customStatement('''
      CREATE TRIGGER fail_recipe_item
      BEFORE INSERT ON meal_items
      BEGIN
        SELECT RAISE(ABORT, 'injected item failure');
      END;
    ''');
    await expectLater(
      service.addServing(
        saved: _saved(withNutrition: true),
        date: DateTime(2026, 8, 11),
        mealType: 'lunch',
      ),
      throwsA(anything),
    );
    expect(await database.select(database.foods).get(), isEmpty);
    expect(await database.select(database.meals).get(), isEmpty);
    expect(await database.select(database.mealItems).get(), isEmpty);
  });

  test('an existing snapshot UUID with altered content fails closed', () async {
    final saved = _saved(withNutrition: true);
    final day = DateTime(2026, 8, 11);
    await service.addServing(saved: saved, date: day, mealType: 'lunch');
    final food = (await database.select(database.foods).get()).single;
    await (database.update(database.foods)
          ..where((row) => row.id.equals(food.id)))
        .write(const FoodsCompanion(source: Value('foreign-source')));
    await expectLater(
      service.addServing(saved: saved, date: day, mealType: 'lunch'),
      throwsA(isA<StateError>()),
    );
    final logged = await meals.watchMealsForDate(day).first;
    expect(logged.single.items, hasLength(1));
  });

  test('recipe without sourced nutrition is never logged', () async {
    expect(
      () => service.addServing(
        saved: _saved(withNutrition: false),
        date: DateTime(2026, 8, 11),
        mealType: 'dinner',
      ),
      throwsA(isA<RecipeNutritionUnavailableException>()),
    );
  });
}

SavedTrustedRecipe _saved({required bool withNutrition}) => SavedTrustedRecipe(
  id: 'recipe-test',
  savedAt: DateTime.utc(2026, 8, 11),
  recipe: TrustedRecipeDraft(
    name: 'Verified bowl',
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 10,
    ingredients: const [
      TrustedRecipeIngredient(name: 'Beans', quantity: 1, unit: 'cup'),
    ],
    steps: const ['Cook and serve.'],
    sourceUrl: null,
    nutrition: withNutrition
        ? TrustedRecipeNutrition(
            caloriesKcal: 420,
            proteinG: 28,
            carbohydrateG: 50,
            fatG: 12,
            provenance: RecipeNutritionProvenance(
              source: 'USDA',
              recordId: '123',
              verifiedAt: DateTime.utc(2026, 8, 1),
            ),
          )
        : null,
  ),
);
