import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/daily_nutrition_intelligence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'daily report aggregates macros, water, and electrolyte evidence',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final foodId = await foods.addFood(
        name: 'Evidence food',
        category: 'test',
        calories: 200,
        protein: 20,
        carbs: 20,
        fats: 4,
        fiber: 8,
        sodium: 400,
        potassium: 800,
      );
      final date = DateTime(2026, 7, 23, 12);
      final mealId = await meals.createMeal(
        date: date,
        name: 'Lunch',
        type: 'lunch',
      );
      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);

      final report = await meals.analyzeDay(
        date: date,
        waterMl: 1800,
        targets: const DailyNutritionTargets(
          calories: 2000,
          protein: 120,
          carbohydrates: 220,
          fat: 65,
          fiber: 30,
          sodium: 2300,
          potassium: 3500,
          waterMl: 2500,
        ),
      );

      expect(report.mealCount, 1);
      expect(report.itemCount, 1);
      expect(report.calories, 200);
      expect(report.protein, 20);
      expect(report.waterMl, 1800);
      expect(report.fiberEvidenceComplete, isTrue);
      expect(report.sodiumEvidenceComplete, isTrue);
      expect(report.potassiumEvidenceComplete, isTrue);
      expect(report.proteinEnergyShare, isNotNull);
      expect(
        report.insights.map((insight) => insight.kind),
        contains(DailyNutritionInsightKind.hydrationBelowTarget),
      );
    },
  );

  test(
    'missing electrolyte evidence is never interpreted as known zero',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final foodId = await foods.addFood(
        name: 'Incomplete food',
        category: 'test',
        calories: 100,
        protein: 5,
        carbs: 15,
        fats: 2,
      );
      final date = DateTime(2026, 7, 24, 12);
      final mealId = await meals.createMeal(
        date: date,
        name: 'Lunch',
        type: 'lunch',
      );
      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);

      final report = await meals.analyzeDay(
        date: date,
        waterMl: 2500,
        targets: const DailyNutritionTargets(
          calories: 2000,
          protein: 100,
          carbohydrates: 200,
          fat: 70,
          fiber: 30,
          sodium: 2300,
          potassium: 3500,
          waterMl: 2500,
        ),
      );

      expect(report.sodium, 0);
      expect(report.sodiumEvidenceComplete, isFalse);
      expect(report.potassiumEvidenceComplete, isFalse);
      expect(
        report.insights.map((insight) => insight.kind),
        contains(DailyNutritionInsightKind.incompleteElectrolyteEvidence),
      );
      expect(
        report.insights.map((insight) => insight.kind),
        isNot(contains(DailyNutritionInsightKind.sodiumAboveTarget)),
      );
    },
  );
}
