import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_deduplication_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_foundation_integrity_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_migration_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('foundation integrity audit is deterministic and read-only', () async {
    final repository = FoodRepository(database);
    await repository.addFood(
      name: 'Greek Yogurt',
      category: 'dairy',
      barcode: '٦٢٢١٢٣٤٥٦٧٨٩٠',
      calories: 100,
      protein: 10,
      carbs: 8,
      fats: 3,
      source: 'branded',
      isCustom: false,
      verified: true,
    );
    await repository.addFood(
      name: 'Greek Yogurt Plain',
      category: 'dairy',
      barcode: '6221234567890',
      calories: 101,
      protein: 10.1,
      carbs: 8.1,
      fats: 3,
      source: 'legacy',
      isCustom: false,
    );
    await repository.addFood(
      name: 'Personal oats',
      category: 'grain',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
    );

    final before = await repository.getFoods();
    final first = await repository.auditFoundationIntegrity();
    final second = await repository.auditFoundationIntegrity();
    final after = await repository.getFoods();

    expect(first.totalFoods, 3);
    expect(first.sources.branded, 1);
    expect(first.sources.legacy, 1);
    expect(first.sources.custom, 1);
    expect(first.sources.unknown, 0);
    expect(first.exactBarcodeCollisionGroups, 1);
    expect(first.possibleDuplicatePairs, greaterThanOrEqualTo(1));
    expect(first.quality.totalFoods, 3);
    expect(
      second.exactBarcodeCollisionGroups,
      first.exactBarcodeCollisionGroups,
    );
    expect(second.possibleDuplicatePairs, first.possibleDuplicatePairs);
    expect(
      after.map((food) => food.id).toList(),
      before.map((food) => food.id).toList(),
    );
    expect(
      after.map((food) => food.revision).toList(),
      before.map((food) => food.revision).toList(),
    );
  });

  test('integrity engine respects migration and duplicate limits', () {
    const foods = <UnifiedFood>[
      UnifiedFood(
        id: 'one',
        name: ' Oats ',
        serving: FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(389),
          FoodNutrient.protein: NutrientAmount.known(16.9),
          FoodNutrient.carbohydrates: NutrientAmount.known(66.3),
          FoodNutrient.fat: NutrientAmount.known(6.9),
        },
        source: FoodDataSource.legacy,
        sourceLabel: ' legacy ',
        verified: false,
        isCustom: false,
      ),
      UnifiedFood(
        id: 'two',
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
      ),
    ];

    final directAssessment = FoodDeduplicationEngine.compare(
      foods.first,
      foods.last,
    );
    expect(directAssessment.kind, isNot(FoodDuplicateKind.none));

    final report = FoodFoundationIntegrityEngine.audit(
      foods,
      migrationLimit: 1,
      duplicatePairLimit: 1,
    );

    expect(report.migrationPlans, hasLength(1));
    expect(
      report.migrationPlans.single.issues.map((issue) => issue.kind),
      contains(FoodMigrationIssueKind.nonCanonicalPrimaryName),
    );
    expect(report.migrationPlans.single.canonical.name, 'Oats');
    expect(report.possibleDuplicatePairs, 1);
    expect(report.sources.countFor(FoodDataSource.legacy), 1);
    expect(report.sources.countFor(FoodDataSource.foundation), 1);
  });
}
