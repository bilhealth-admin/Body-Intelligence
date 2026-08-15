import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FoodRepository foods;
  late MealRepository meals;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    foods = FoodRepository(database);
    meals = MealRepository(database);
  });

  tearDown(() => database.close());

  test('meal item captures source, verification, serving, and unit', () async {
    final foodId = await foods.addFood(
      name: 'USDA oats',
      category: 'grain',
      servingSize: 40,
      servingUnit: 'g',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
      source: 'usda',
      isCustom: false,
      verified: true,
    );
    final mealId = await meals.createMeal(
      date: DateTime(2026, 8, 1),
      name: 'breakfast',
      type: 'breakfast',
    );

    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 80);

    final item = await database.select(database.mealItems).getSingle();

    expect(item.foodSourceSnapshot, 'usda');
    expect(item.foodVerifiedSnapshot, isTrue);
    expect(item.servingSizeSnapshot, 40);
    expect(item.servingUnitSnapshot, 'g');
  });

  test('quantity update preserves original meal evidence snapshot', () async {
    final foodId = await foods.addFood(
      name: 'Verified yogurt',
      category: 'dairy',
      servingSize: 170,
      servingUnit: 'g',
      calories: 59,
      protein: 10,
      carbs: 3.6,
      fats: 0.4,
      source: 'branded',
      isCustom: false,
      verified: true,
    );
    final mealId = await meals.createMeal(
      date: DateTime(2026, 8, 1),
      name: 'snack',
      type: 'snack',
    );
    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 170);

    final before = await database.select(database.mealItems).getSingle();
    await meals.updateMealItem(id: before.id, quantity: 85);
    final after = await database.select(database.mealItems).getSingle();

    expect(after.quantity, 85);
    expect(after.foodSourceSnapshot, before.foodSourceSnapshot);
    expect(after.foodVerifiedSnapshot, before.foodVerifiedSnapshot);
    expect(after.servingSizeSnapshot, before.servingSizeSnapshot);
    expect(after.servingUnitSnapshot, before.servingUnitSnapshot);
  });

  test('custom unverified food is snapshotted without false trust', () async {
    final foodId = await foods.addFood(
      name: 'Label entry',
      category: 'custom',
      servingSize: 1,
      servingUnit: 'piece',
      calories: 120,
      protein: 3,
      carbs: 20,
      fats: 3,
      source: 'local',
      isCustom: true,
      verified: false,
    );
    final mealId = await meals.createMeal(
      date: DateTime(2026, 8, 1),
      name: 'lunch',
      type: 'lunch',
    );

    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 1);

    final item = await database.select(database.mealItems).getSingle();

    expect(item.foodSourceSnapshot, 'local');
    expect(item.foodVerifiedSnapshot, isFalse);
    expect(item.servingSizeSnapshot, 1);
    expect(item.servingUnitSnapshot, 'piece');
  });
}
