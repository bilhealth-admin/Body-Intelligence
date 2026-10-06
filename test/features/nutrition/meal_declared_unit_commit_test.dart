import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 6, 12);
  late AppDatabase db;
  late MealRepository meals;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    meals = MealRepository(db);
  });
  tearDown(() => db.close());

  Future<int> label(String unit, double basis) => FoodRepository(db).addFood(
    name: 'Synthetic $unit label',
    category: 'custom',
    servingSize: basis,
    servingUnit: unit,
    calories: 200,
    protein: 8,
    carbs: 20,
    fats: 10,
    sodium: 0,
  );

  for (final row in [
    (unit: 'piece', basis: 2.0, amount: 1.0, calories: 100.0),
    (unit: 'ml', basis: 100.0, amount: 250.0, calories: 500.0),
    (unit: 'kg', basis: .25, amount: .5, calories: 400.0),
  ]) {
    test(
      '${row.unit} diary quantity keeps its actual label unit and ratio',
      () async {
        final foodId = await label(row.unit, row.basis);
        await meals.addReviewedMealItemsAtomically(
          date: date,
          mealType: 'lunch',
          items: [(foodId: foodId, quantity: row.amount)],
          quantitiesInGrams: false,
        );
        final item = await db.select(db.mealItems).getSingle();
        expect(item.quantity, row.amount);
        expect(item.calories, row.calories);
        expect(item.servingSizeSnapshot, row.basis);
        expect(item.servingUnitSnapshot, row.unit);
        final evidence = MealFoodEvidence.read(item);
        expect(evidence.value(TrackedNutrient.sodium), 0);
        expect(evidence.value(TrackedNutrient.fiber), isNull);
        await meals.updateMealItem(id: item.id, quantity: row.amount / 2);
        final changed = await db.select(db.mealItems).getSingle();
        expect(changed.calories, row.calories / 2);
        expect(changed.servingUnitSnapshot, row.unit);
        expect(changed.servingSizeSnapshot, row.basis);
      },
    );
  }

  test(
    'known mass basis converts explicit gram requests to a gram snapshot',
    () async {
      final foodId = await label('kg', .25);
      await meals.addReviewedMealItemsAtomically(
        date: date,
        mealType: 'lunch',
        items: [(foodId: foodId, quantity: 500.0)],
      );
      final item = await db.select(db.mealItems).getSingle();
      expect(item.quantity, 500);
      expect(item.calories, 400);
      expect(item.servingUnitSnapshot, 'g');
      expect(item.servingSizeSnapshot, 250);
    },
  );

  for (final unit in ['ml', 'piece']) {
    test(
      'gram batch with unsupported $unit basis rolls back every row',
      () async {
        final grams = await label('g', 100);
        final unknownMass = await label(unit, 100);
        await expectLater(
          meals.addReviewedMealItemsAtomically(
            date: date,
            mealType: 'lunch',
            items: [
              (foodId: grams, quantity: 100.0),
              (foodId: unknownMass, quantity: 50.0),
            ],
          ),
          throwsStateError,
        );
        expect(await db.select(db.meals).get(), isEmpty);
        expect(await db.select(db.mealItems).get(), isEmpty);
        expect(await db.select(db.foods).get(), hasLength(2));
      },
    );
  }

  test(
    'Quick Add entry keeps 1905 calories and unknown macros after readback',
    () async {
      await meals.addQuickMacroEntry(
        date: date,
        mealType: 'lunch',
        calories: 1905,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: false,
        fatKnown: false,
        occurredAt: date,
      );
      final item = await db.select(db.mealItems).getSingle();
      expect(item.quantity, 1);
      expect(item.servingUnitSnapshot, 'entry');
      final evidence = MealFoodEvidence.read(item);
      expect(evidence.value(TrackedNutrient.calories), 1905);
      expect(evidence.value(TrackedNutrient.protein), isNull);
      expect(evidence.value(TrackedNutrient.carbohydrates), isNull);
      expect(evidence.value(TrackedNutrient.fat), isNull);
      final ledger = await DailyLogRepository(db).readLedger(date);
      expect(ledger.calories, 1905);
      expect(ledger.protein, isNull);
      expect(ledger.carbohydrates, isNull);
      expect(ledger.fat, isNull);
    },
  );
}
