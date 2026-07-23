import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('legacy meal item API and meal builder API coexist', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final foodId = await foods.addFood(
      name: 'Chicken breast',
      category: 'protein',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      sodium: 74,
    );

    final lunchId = await meals.createMeal(
      date: DateTime(2026, 7, 22),
      name: 'Lunch',
      type: 'lunch',
    );
    await meals.addMealItem(mealId: lunchId, foodId: foodId, quantity: 200);

    final dinnerId = await meals.createMealFromDraft(
      date: DateTime(2026, 7, 23),
      draft: MealBuilderDraft(
        name: 'Dinner',
        mealType: 'dinner',
        items: <MealBuilderItemDraft>[
          MealBuilderItemDraft(foodId: foodId, quantityGrams: 150, position: 1),
        ],
      ),
    );

    final allMeals = await database.select(database.meals).get();
    final allItems = await database.select(database.mealItems).get();
    expect(allMeals, hasLength(2));
    expect(allItems, hasLength(2));
    expect(
      allItems.singleWhere((item) => item.mealId == lunchId).calories,
      closeTo(330, 0.001),
    );
    expect(
      allItems.singleWhere((item) => item.mealId == dinnerId).calories,
      closeTo(247.5, 0.001),
    );
  });

  test('builder refuses to overwrite an existing populated meal', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final foodId = await foods.addFood(
      name: 'Rice',
      category: 'grain',
      calories: 130,
      protein: 2.7,
      carbs: 28,
      fats: 0.3,
    );
    final date = DateTime(2026, 7, 23);
    final mealId = await meals.createMeal(
      date: date,
      name: 'Lunch',
      type: 'lunch',
    );
    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);

    await expectLater(
      meals.createMealFromDraft(
        date: date,
        draft: MealBuilderDraft(
          name: 'Replacement lunch',
          mealType: 'lunch',
          items: <MealBuilderItemDraft>[
            MealBuilderItemDraft(
              foodId: foodId,
              quantityGrams: 200,
              position: 1,
            ),
          ],
        ),
      ),
      throwsStateError,
    );

    final items = await database.select(database.mealItems).get();
    expect(items, hasLength(1));
    expect(items.single.quantity, 100);
  });
}
