import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

part 'coach_meal_journal_cases.dart';
part 'coach_meal_owner_atomicity_cases.dart';

void main() {
  group('Coach meal journal', _coachMealJournalCases);
  group('Coach meal owner atomicity', _coachMealOwnerAtomicityCases);
  test(
    'quantity correction scales the logged nutrition after catalog changes',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final meals = MealRepository(database);
      final foodId = await FoodRepository(database).addFood(
        name: 'Saved label yogurt',
        category: 'dairy',
        servingSize: 100,
        servingUnit: 'g',
        calories: 60,
        protein: 10,
        carbs: 4,
        fats: 1,
        source: 'label',
        verified: false,
      );
      final mealId = await meals.createMeal(
        date: DateTime(2026, 10, 6),
        name: 'snack',
        type: 'snack',
      );
      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 200);
      final original = await database.select(database.mealItems).getSingle();
      await (database.update(
        database.foods,
      )..where((row) => row.id.equals(foodId))).write(
        const FoodsCompanion(
          calories: Value(900),
          protein: Value(90),
          carbs: Value(80),
          fats: Value(70),
          fiber: Value(60),
          nutrientEvidenceMask: Value(2047),
          source: Value('later_catalog_revision'),
          servingSize: Value(25),
        ),
      );

      await meals.updateMealItem(id: original.id, quantity: 100);
      final corrected = await meals.getMealItem(original.id);

      expect(corrected.calories, original.calories / 2);
      expect(corrected.protein, original.protein / 2);
      expect(corrected.carbs, original.carbs / 2);
      expect(corrected.fats, original.fats / 2);
      expect(corrected.fiber, original.fiber / 2);
      expect(corrected.nutrientEvidenceMask, original.nutrientEvidenceMask);
      expect(corrected.foodSourceSnapshot, original.foodSourceSnapshot);
      expect(corrected.foodVerifiedSnapshot, original.foodVerifiedSnapshot);
      expect(corrected.servingSizeSnapshot, original.servingSizeSnapshot);
      expect(corrected.servingUnitSnapshot, original.servingUnitSnapshot);
      expect(corrected.uuid, original.uuid);
      expect(corrected.revision, original.revision + 1);
    },
  );
}
