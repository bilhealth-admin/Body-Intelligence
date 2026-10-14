import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/database/unit_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
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

    // The declared-unit snapshot carries a versioned source marker so the
    // nineteen-nutrient evidence cannot fall back to legacy zero projections.
    expect(item.foodSourceSnapshot, 'unit_food_v1:local');
    final evidence = MealFoodEvidence.read(item);
    expect(evidence.isValid, isTrue);
    expect(evidence.unit!.source, 'local');
    expect(evidence.unit!.unit, 'piece');
    expect(evidence.unit!.quantity, 1);
    expect(item.foodVerifiedSnapshot, isFalse);
    expect(item.servingSizeSnapshot, 1);
    expect(item.servingUnitSnapshot, 'piece');
  });

  for (final declaredUnit in ['item', 'bottle', 'حصة']) {
    test(
      'declared $declaredUnit snapshot round-trips without gram inference',
      () async {
        final day = DateTime(2026, 10, 6);
        final foodId = await foods.addFood(
          name: 'Explicit item label',
          category: 'custom',
          servingSize: 2,
          servingUnit: declaredUnit,
          calories: 50,
          protein: 0,
          carbs: 3,
          fats: 1,
          sodium: 0,
          source: 'label',
        );
        final mealId = await meals.createMeal(
          date: day,
          name: 'lunch',
          type: 'lunch',
        );
        await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 3);
        final item = await database.select(database.mealItems).getSingle();
        final food = await (database.select(
          database.foods,
        )..where((row) => row.id.equals(foodId))).getSingle();
        final basis = FoodBasisEvidence.read(food);
        expect(basis.isValid, isTrue);
        expect(basis.catalog, isNotNull);
        expect(basis.basisGrams, isNull);
        expect(basis.snapshot, isNull);
        expect(food.servingUnit, declaredUnit);
        expect(item.servingUnitSnapshot, declaredUnit);
        expect(item.servingSizeSnapshot, 2);
        expect(item.quantity, 3);
        expect(item.foodVerifiedSnapshot, isFalse);
        final evidence = MealFoodEvidence.read(item);
        expect(evidence.isValid, isTrue);
        expect(evidence.portion, isNull);
        final unit = evidence.unit!;
        final decoded = UnitFoodEvidence.decode(item.foodEvidenceJson!);
        final roundTrip = UnitFoodEvidence.decode(decoded.encodeForStorage());
        expect(roundTrip.identity, food.uuid);
        expect(roundTrip.ownerKey, unit.ownerKey);
        expect(roundTrip.source, 'label');
        expect(roundTrip.unit, declaredUnit);
        expect(roundTrip.basisQuantity, 2);
        expect(roundTrip.quantity, 3);
        expect(roundTrip.nutrients.values, unit.nutrients.values);
        expect(
          roundTrip.nutrients.values,
          hasLength(FoodNutrient.values.length),
        );
        expect(roundTrip.value(FoodNutrient.calories), 75);
        expect(roundTrip.value(FoodNutrient.protein), 0);
        expect(roundTrip.value(FoodNutrient.sodium), 0);
        expect(roundTrip.value(FoodNutrient.fiber), isNull);
        expect(roundTrip.value(FoodNutrient.vitaminA), isNull);
        expect(evidence.value(TrackedNutrient.calories), 75);
        expect(evidence.value(TrackedNutrient.sodium), 0);
        final ledger = await DailyLogRepository(database).readLedger(day);
        expect(ledger.calories, 75);
        expect(ledger.protein, 0);
        expect(ledger.carbohydrates, 4.5);
        expect(ledger.fat, 1.5);
        expect(ledger.fiber, isNull);
        expect(ledger.netCarbohydrates, isNull);
        await expectLater(
          meals.addMealItem(
            mealId: mealId,
            foodId: foodId,
            quantity: 80,
            quantityInGrams: true,
          ),
          throwsStateError,
        );
        expect(await database.select(database.mealItems).getSingle(), item);
        await meals.updateMealItem(id: item.id, quantity: 6);
        final updated = await database.select(database.mealItems).getSingle();
        expect(updated.servingUnitSnapshot, declaredUnit);
        expect(updated.servingSizeSnapshot, 2);
        expect(updated.calories, 150);
        final updatedEvidence = MealFoodEvidence.read(updated);
        expect(updatedEvidence.isValid, isTrue);
        expect(updatedEvidence.portion, isNull);
        expect(updatedEvidence.unit!.quantity, 6);
        expect(updatedEvidence.value(TrackedNutrient.sodium), 0);
        expect(updatedEvidence.value(TrackedNutrient.fiber), isNull);
      },
    );
  }
}
