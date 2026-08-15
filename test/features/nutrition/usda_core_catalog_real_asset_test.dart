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
    expect(result.foods.first.uuid, startsWith('usda:'));
    expect(result.foods.first.source, startsWith('USDA FoodData Central'));
  });
}
