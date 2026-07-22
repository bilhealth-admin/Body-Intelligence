import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_quality_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('quality audit is deterministic, explainable, and read-only', () async {
    final repository = FoodRepository(database);
    await repository.addFood(
      name: 'Verified oats',
      arabicName: 'شوفان',
      category: 'grain',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
      fiber: 10.6,
      sugar: 0.9,
      sodium: 2,
      potassium: 429,
      calcium: 54,
      magnesium: 177,
      source: 'foundation',
      verified: true,
      isCustom: false,
    );
    await repository.addFood(
      name: 'Sparse custom food',
      category: '',
      calories: 100,
      protein: 0,
      carbs: 0,
      fats: 0,
      source: 'local',
      verified: false,
    );

    final before = await repository.getFoods();
    final audit = await repository.auditQuality();
    final after = await repository.getFoods();

    expect(audit.totalFoods, 2);
    expect(audit.records, hasLength(2));
    expect(audit.records.first.food.name, 'Sparse custom food');
    expect(
      audit.records.first.assessment.issues,
      contains(FoodQualityIssue.unverified),
    );
    expect(audit.highConfidenceCount, 1);
    expect(audit.mediumConfidenceCount + audit.lowConfidenceCount, 1);
    expect(after.map((food) => food.id), before.map((food) => food.id));
  });

  test(
    'quality audit filters confidence and issue without changing totals',
    () {
      const foods = <UnifiedFood>[
        UnifiedFood(
          id: 'high',
          name: 'Complete food',
          arabicName: 'طعام كامل',
          category: 'foundation',
          serving: FoodServing(amount: 100, unit: 'g', grams: 100),
          nutrients: <FoodNutrient, NutrientAmount>{
            FoodNutrient.calories: NutrientAmount.known(100),
            FoodNutrient.protein: NutrientAmount.known(10),
            FoodNutrient.carbohydrates: NutrientAmount.known(10),
            FoodNutrient.fat: NutrientAmount.known(2),
            FoodNutrient.fiber: NutrientAmount.known(3),
            FoodNutrient.sugar: NutrientAmount.known(1),
            FoodNutrient.sodium: NutrientAmount.known(0),
            FoodNutrient.potassium: NutrientAmount.known(100),
            FoodNutrient.calcium: NutrientAmount.known(20),
            FoodNutrient.magnesium: NutrientAmount.known(10),
          },
          source: FoodDataSource.foundation,
          sourceLabel: 'foundation',
          verified: true,
          isCustom: false,
        ),
        UnifiedFood(
          id: 'low',
          name: 'Unknown sparse food',
          serving: FoodServing(amount: 100, unit: 'g', grams: 100),
          nutrients: <FoodNutrient, NutrientAmount>{},
          source: FoodDataSource.unknown,
          sourceLabel: 'mystery',
          verified: false,
          isCustom: false,
        ),
      ];

      final audit = FoodQualityAuditEngine.audit(
        foods,
        maximumConfidence: FoodConfidenceLevel.low,
        issue: FoodQualityIssue.unknownSource,
        limit: 1,
      );

      expect(audit.totalFoods, 2);
      expect(audit.highConfidenceCount, 1);
      expect(audit.lowConfidenceCount, 1);
      expect(audit.records, hasLength(1));
      expect(audit.records.single.food.id, 'low');
    },
  );
}
