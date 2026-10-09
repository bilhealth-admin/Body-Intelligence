import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a meal bucket alone is not a first committed food', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final meals = MealRepository(database);
    final preferences = PreferencesRepository(database);

    await meals.createMeal(
      date: DateTime(2026, 10, 10),
      name: 'breakfast',
      type: 'breakfast',
    );
    expect(await preferences.get(firstMealCelebrationPreferenceKey), isNull);
    expect(await database.select(database.mealItems).get(), isEmpty);
  });

  test(
    'manual food marks ready and edits or later foods cannot rearm',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final meals = MealRepository(database);
      final preferences = PreferencesRepository(database);
      final foodId = await FoodRepository(database).addFood(
        name: 'First breakfast',
        category: 'fruit',
        calories: 80,
        protein: 1,
        carbs: 18,
        fats: 0,
        servingSize: 100,
        servingUnit: 'g',
      );
      final mealId = await meals.createMeal(
        date: DateTime(2026, 10, 10),
        name: 'breakfast',
        type: 'breakfast',
      );

      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
      expect(await preferences.get(firstMealCelebrationPreferenceKey), 'ready');
      expect(
        await preferences.mutateIfUnchanged(
          expected: const {firstMealCelebrationPreferenceKey: 'ready'},
          set: const {firstMealCelebrationPreferenceKey: 'done'},
        ),
        isTrue,
      );
      final first = await database.select(database.mealItems).getSingle();
      await meals.updateMealItem(id: first.id, quantity: 125);
      await meals.deleteMealItem(first.id);
      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 50);
      expect(await preferences.get(firstMealCelebrationPreferenceKey), 'done');
    },
  );

  test('a failed atomic first food cannot create a celebration', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final meals = MealRepository(database);
    final preferences = PreferencesRepository(database);

    await expectLater(
      meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'lunch',
        items: const [(foodId: 999999, quantity: 100.0)],
      ),
      throwsStateError,
    );
    expect(await database.select(database.mealItems).get(), isEmpty);
    expect(await preferences.get(firstMealCelebrationPreferenceKey), isNull);
  });

  test(
    'calculated recipe first serving creates milestone atomically',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final meals = MealRepository(database);
      final preferences = PreferencesRepository(database);

      await meals.addCalculatedRecipeServingAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'lunch',
        foodUuid: 'first-recipe-snapshot',
        recipeName: 'Test recipe serving',
        source: 'user-reviewed-calculation',
        calories: 320,
        protein: 20,
        carbohydrates: 18,
        fat: 12,
      );
      expect(await database.select(database.mealItems).get(), hasLength(1));
      expect(await preferences.get(firstMealCelebrationPreferenceKey), 'ready');
    },
  );

  test('legacy deleted food is not classified as a new first food', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final meals = MealRepository(database);
    final preferences = PreferencesRepository(database);
    final foodId = await FoodRepository(database).addFood(
      name: 'Historical food',
      category: 'other',
      calories: 100,
      protein: 2,
      carbs: 15,
      fats: 3,
      servingSize: 100,
      servingUnit: 'g',
    );
    final mealId = await meals.createMeal(
      date: DateTime(2026, 10, 10),
      name: 'breakfast',
      type: 'breakfast',
    );
    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
    final item = await database.select(database.mealItems).getSingle();
    await meals.deleteMealItem(item.id);
    await preferences.remove(firstMealCelebrationPreferenceKey);

    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 80);
    expect(await preferences.get(firstMealCelebrationPreferenceKey), 'done');
  });
}
