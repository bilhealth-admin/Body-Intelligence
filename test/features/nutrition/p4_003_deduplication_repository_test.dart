import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_deduplication_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'duplicate discovery is offline, deterministic, and non-destructive',
    () async {
      final repository = FoodRepository(database);
      await repository.addFood(
        name: 'Greek Yogurt',
        category: 'dairy',
        barcode: '6221234567890',
        calories: 100,
        protein: 10,
        carbs: 8,
        fats: 3,
        source: 'branded',
        isCustom: false,
        verified: true,
      );
      await repository.addFood(
        name: 'Greek Yogurt plain',
        category: 'dairy',
        calories: 102,
        protein: 10.1,
        carbs: 8.1,
        fats: 3,
        source: 'foundation',
        isCustom: false,
        verified: true,
      );
      await repository.addFood(
        name: 'Apple',
        category: 'fruit',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fats: 0.2,
        servingSize: 100,
        servingUnit: 'g',
      );

      const incoming = UnifiedFood(
        id: 'import:greek-yogurt',
        name: 'Greek Yogurt',
        category: 'dairy',
        barcode: '6221234567890',
        serving: FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(100),
          FoodNutrient.protein: NutrientAmount.known(10),
          FoodNutrient.carbohydrates: NutrientAmount.known(8),
          FoodNutrient.fat: NutrientAmount.known(3),
        },
        source: FoodDataSource.branded,
        sourceLabel: 'import',
        verified: true,
        isCustom: false,
      );

      final candidates = await repository.findDuplicateCandidates(incoming);

      expect(candidates, hasLength(2));
      expect(candidates.first.food.barcode, '6221234567890');
      expect(
        candidates.first.assessment.kind,
        FoodDuplicateKind.highConfidence,
      );
      expect(candidates.first.assessment.shouldAutoMerge, isFalse);
      expect(candidates[1].assessment.kind, FoodDuplicateKind.possible);
      expect(
        candidates[1].assessment.reasons,
        contains('related-primary-name'),
      );
      expect(await repository.getFoods(), hasLength(3));
    },
  );

  test('candidate threshold and limit are enforced', () {
    const incoming = UnifiedFood(
      id: 'incoming',
      name: 'Oats',
      serving: FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: NutrientAmount.known(389),
        FoodNutrient.protein: NutrientAmount.known(16.9),
        FoodNutrient.carbohydrates: NutrientAmount.known(66.3),
        FoodNutrient.fat: NutrientAmount.known(6.9),
      },
      source: FoodDataSource.foundation,
      sourceLabel: 'foundation',
      verified: true,
      isCustom: false,
    );
    const existing = <UnifiedFood>[
      UnifiedFood(
        id: 'one',
        name: 'Oats',
        serving: FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(389),
          FoodNutrient.protein: NutrientAmount.known(16.9),
          FoodNutrient.carbohydrates: NutrientAmount.known(66.3),
          FoodNutrient.fat: NutrientAmount.known(6.9),
        },
        source: FoodDataSource.legacy,
        sourceLabel: 'legacy',
        verified: false,
        isCustom: false,
      ),
      UnifiedFood(
        id: 'two',
        name: 'Apple',
        serving: FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{},
        source: FoodDataSource.foundation,
        sourceLabel: 'foundation',
        verified: true,
        isCustom: false,
      ),
    ];

    final candidates = FoodDeduplicationEngine.findCandidates(
      incoming: incoming,
      existing: existing,
      minimumKind: FoodDuplicateKind.highConfidence,
      limit: 1,
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.food.id, 'one');
  });
}
