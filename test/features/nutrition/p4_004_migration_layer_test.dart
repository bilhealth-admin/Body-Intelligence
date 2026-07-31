import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_migration_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration audit canonicalizes metadata without mutating nutrition', () {
    const food = UnifiedFood(
      id: '  stable-id  ',
      name: '  Greek Yogurt  ',
      arabicName: '  زبادي يوناني  ',
      category: '  dairy  ',
      keywords: <String>['Greek', ' greek ', '', 'Yogurt'],
      barcode: '٦٢٢-١٢٣ ٤٥٦',
      serving: FoodServing(amount: 100, unit: 'grams', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: NutrientAmount.known(100),
        FoodNutrient.sodium: NutrientAmount.missing(),
      },
      source: FoodDataSource.branded,
      sourceLabel: 'Brand',
      verified: true,
      isCustom: false,
    );

    final plan = FoodMigrationEngine.audit(food);

    expect(plan.requiresPersistence, isTrue);
    expect(plan.shouldAutoPersist, isFalse);
    expect(plan.canonical.id, 'stable-id');
    expect(plan.canonical.name, 'Greek Yogurt');
    expect(plan.canonical.arabicName, 'زبادي يوناني');
    expect(plan.canonical.category, 'dairy');
    expect(plan.canonical.keywords, <String>['Greek', 'Yogurt']);
    expect(plan.canonical.barcode, '622123456');
    expect(plan.canonical.serving.unit, 'g');
    expect(plan.canonical.nutrient(FoodNutrient.calories).value, 100);
    expect(plan.canonical.hasEvidence(FoodNutrient.sodium), isFalse);
    expect(
      plan.issues.map((issue) => issue.kind),
      containsAll(<FoodMigrationIssueKind>[
        FoodMigrationIssueKind.nonCanonicalSourceLabel,
        FoodMigrationIssueKind.nonCanonicalServingUnit,
        FoodMigrationIssueKind.nonCanonicalBarcode,
        FoodMigrationIssueKind.duplicateKeyword,
        FoodMigrationIssueKind.blankKeyword,
      ]),
    );
  });

  test('unknown source and invalid serving remain explicit and read-only', () {
    const food = UnifiedFood(
      id: 'unknown-food',
      name: 'Unknown food',
      serving: FoodServing(amount: 0, unit: 'piece', grams: 0),
      nutrients: <FoodNutrient, NutrientAmount>{},
      source: FoodDataSource.unknown,
      sourceLabel: 'import-x',
      verified: false,
      isCustom: false,
    );

    final plan = FoodMigrationEngine.audit(food);

    expect(plan.shouldAutoPersist, isFalse);
    expect(
      plan.issues.map((issue) => issue.kind),
      containsAll(<FoodMigrationIssueKind>[
        FoodMigrationIssueKind.unknownSource,
        FoodMigrationIssueKind.nonCanonicalSourceLabel,
        FoodMigrationIssueKind.invalidServingBasis,
      ]),
    );
    expect(plan.canonical.serving.grams, 0);
  });

  test(
    'repository migration audit is deterministic and non-destructive',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = FoodRepository(database);

      await repository.addFood(
        name: 'Canonical oats',
        category: 'grain',
        calories: 389,
        protein: 16.9,
        carbs: 66.3,
        fats: 6.9,
        source: 'foundation',
        isCustom: false,
        verified: true,
      );
      await repository.addFood(
        name: 'Legacy apple',
        category: 'fruit',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fats: 0.2,
        source: 'legacy ',
        isCustom: false,
      );

      final before = await repository.getFoods();
      final first = await repository.auditMigration();
      final second = await repository.auditMigration();
      final after = await repository.getFoods();

      expect(
        first.map((plan) => plan.original.id),
        second.map((plan) => plan.original.id),
      );
      expect(after.map((food) => food.uuid), before.map((food) => food.uuid));
      expect(
        after.map((food) => food.revision),
        before.map((food) => food.revision),
      );
    },
  );
}
