import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bundled USDA core opens and returns attributed search results',
    () async {
      final repository = UsdaCoreCatalogRepository.open(
        'assets/catalogs/bil_food_core.sqlite',
      );
      addTearDown(repository.close);

      final hits = await repository.searchUnified('apple', limit: 10);

      expect(hits, isNotEmpty);
      expect(hits.first.food.id, startsWith('usda:'));
      expect(hits.first.food.sourceLabel, startsWith('USDA FoodData Central'));
      expect(hits.first.food.verified, isTrue);
    },
  );

  test(
    'everyday search prefers a diary-usable complete nutrient row',
    () async {
      final repository = UsdaCoreCatalogRepository.open(
        'assets/catalogs/bil_food_core.sqlite',
      );
      addTearDown(repository.close);

      final hits = await repository.searchUnified('egg', limit: 10);

      expect(hits, isNotEmpty);
      final first = hits.first.food;
      expect(first.nutrient(FoodNutrient.calories).isKnown, isTrue);
      expect(first.nutrient(FoodNutrient.calories).value, greaterThan(0));
      expect(first.nutrient(FoodNutrient.protein).isKnown, isTrue);
      expect(first.nutrient(FoodNutrient.carbohydrates).isKnown, isTrue);
      expect(first.nutrient(FoodNutrient.fat).isKnown, isTrue);
    },
  );

  test('bundled core advertises its immutable offline contract', () {
    final repository = UsdaCoreCatalogRepository.open(
      'assets/catalogs/bil_food_core.sqlite',
    );
    addTearDown(repository.close);

    expect(repository.metadata['catalog_role'], 'offline_core');
    expect(repository.metadata['excluded_sources'], 'branded');
    expect(
      repository.metadata['online_enrichment'],
      'USDA FoodData Central + Open Food Facts',
    );
  });

  test('runtime search authority materializes a real USDA result', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final authority = FoodRuntimeSearchAuthority(
      FoodRepository(database),
      catalogResolver: () async => UsdaCoreCatalogRepository.open(
        'assets/catalogs/bil_food_core.sqlite',
      ),
    );

    final result = await authority.searchDetailed('apple', limit: 5);

    expect(result.source, FoodRuntimeSearchSource.catalogAndLocal);
    expect(result.foods, isNotEmpty);
    final food = result.foods.first;
    expect(food.uuid, startsWith('usda:'));
    expect(food.source, startsWith('USDA FoodData Central'));
    expect(food.verified, isTrue);
    expect(food.isCustom, isFalse);
    expect(food.calories, greaterThan(0));
    expect(food.protein, greaterThanOrEqualTo(0));
    expect(food.carbs, greaterThanOrEqualTo(0));
    expect(food.fats, greaterThanOrEqualTo(0));
    expect(food.sodium, greaterThanOrEqualTo(0));
    expect(food.potassium, greaterThanOrEqualTo(0));
    for (final nutrient in const <FoodNutrient>[
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
      FoodNutrient.sodium,
      FoodNutrient.potassium,
    ]) {
      expect(
        UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient),
        isTrue,
        reason: nutrient.name,
      );
    }
  });

  test(
    'nutrientless USDA components are not verified search candidates',
    () async {
      final repository = UsdaCoreCatalogRepository.open(
        'assets/catalogs/bil_food_core.sqlite',
      );
      addTearDown(repository.close);

      final hits = await repository.searchUnified('apple', limit: 250);
      expect(hits, isNotEmpty);
      expect(hits.map((hit) => hit.food.id), isNot(contains('usda:1105782')));
      expect(
        hits.every(
          (hit) => const <FoodNutrient>[
            FoodNutrient.calories,
            FoodNutrient.protein,
            FoodNutrient.carbohydrates,
            FoodNutrient.fat,
          ].every(hit.food.hasEvidence),
        ),
        isTrue,
      );

      final component = await repository.findById('usda:1105782');
      expect(component, isNotNull);
      expect(component!.name, 'APPLES, FUJI');
      expect(component.nutrients, isEmpty);
      expect(component.verified, isFalse);
    },
  );

  test('real bundled catalog resolves supported writing systems', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final authority = FoodRuntimeSearchAuthority(
      FoodRepository(database),
      catalogResolver: () async => UsdaCoreCatalogRepository.open(
        'assets/catalogs/bil_food_core.sqlite',
      ),
    );

    for (final query in ['яблоко', 'りんご', '苹果', 'सेब', 'تفاح']) {
      final result = await authority.searchDetailed(query, limit: 3);
      expect(result.foods, isNotEmpty, reason: query);
      expect(
        result.foods.any((food) => food.name.toLowerCase().contains('apple')),
        isTrue,
        reason: query,
      );
    }
  });

  test(
    'real catalog never collapses duck rows to one lossy Arabic word',
    () async {
      final repository = UsdaCoreCatalogRepository.open(
        'assets/catalogs/bil_food_core.sqlite',
      );
      addTearDown(repository.close);

      final hits = await repository.searchUnified('duck', limit: 20);

      expect(hits, isNotEmpty);
      expect(hits.map((hit) => hit.food.arabicName), isNot(contains('بط')));
    },
  );
}
