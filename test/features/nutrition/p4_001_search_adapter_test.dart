import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/nutrition/adapters/unified_food_adapter.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_food_search_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4-001 adapters and offline search', () {
    test(
      'adapter preserves known zero and missing micronutrient semantics',
      () {
        final adapted = const UnifiedFoodAdapter().adapt(
          _databaseFood(nutrientEvidenceMask: 1, fiber: 0, sodium: 0),
        );

        expect(adapted.source, FoodDataSource.foundation);
        expect(adapted.nutrient(FoodNutrient.fiber).isKnown, isTrue);
        expect(adapted.nutrient(FoodNutrient.fiber).value, 0);
        expect(adapted.nutrient(FoodNutrient.sodium).isKnown, isFalse);
      },
    );

    test('adapter routes foundation legacy branded and custom sources', () {
      const adapter = UnifiedFoodAdapter();
      expect(
        adapter.adapt(_databaseFood(source: 'foundation')).source,
        FoodDataSource.foundation,
      );
      expect(
        adapter.adapt(_databaseFood(source: 'legacy')).source,
        FoodDataSource.legacy,
      );
      expect(
        adapter.adapt(_databaseFood(source: 'branded')).source,
        FoodDataSource.branded,
      );
      expect(
        adapter.adapt(_databaseFood(isCustom: true)).source,
        FoodDataSource.custom,
      );
    });

    test('offline search matches Arabic without diacritics', () {
      final food = const UnifiedFoodAdapter().adapt(
        _databaseFood(name: 'Chicken Breast', arabicName: 'صدر دجاج'),
      );
      final hits = const OfflineFoodSearchPipeline().search(
        foods: <UnifiedFood>[food],
        query: 'صَدْر دجاج',
      );

      expect(hits, hasLength(1));
      expect(hits.single.food.id, food.id);
      expect(hits.single.reasons, contains('arabic-name-exact'));
    });

    test('apple query matches Apple and Apples but not Applebees', () {
      const adapter = UnifiedFoodAdapter();
      final hits = const OfflineFoodSearchPipeline().search(
        foods: <UnifiedFood>[
          adapter.adapt(_databaseFood(id: 1, uuid: 'apple', name: 'Apple')),
          adapter.adapt(
            _databaseFood(id: 2, uuid: 'apples', name: 'APPLES, FUJI'),
          ),
          adapter.adapt(
            _databaseFood(id: 3, uuid: 'applebees', name: 'APPLEBEES - BACON'),
          ),
        ],
        query: 'apple',
      );

      expect(
        hits.map((hit) => hit.food.id),
        containsAll(<String>['apple', 'apples']),
      );
      expect(hits.map((hit) => hit.food.id), isNot(contains('applebees')));
    });

    test('quality bonuses never admit unrelated foods into results', () {
      final adapter = const UnifiedFoodAdapter();
      final unrelatedVerifiedFoundation = adapter.adapt(
        _databaseFood(
          id: 1,
          uuid: 'foundation-unrelated',
          name: 'Chicken Breast',
          arabicName: 'صدر دجاج',
          source: 'foundation',
        ),
      );
      final barcodeFood = adapter.adapt(
        _databaseFood(
          id: 2,
          uuid: 'barcode-match',
          name: 'Brand Yogurt',
          arabicName: 'زبادي تجاري',
          source: 'branded',
          barcode: '6221234567890',
        ),
      );

      final hits = const OfflineFoodSearchPipeline().search(
        foods: <UnifiedFood>[unrelatedVerifiedFoundation, barcodeFood],
        query: '٦٢٢١٢٣٤٥٦٧٨٩٠',
      );

      expect(hits, hasLength(1));
      expect(hits.single.food.id, 'barcode-match');
      expect(hits.single.reasons, contains('barcode-exact'));
    });

    test('barcode exact result outranks text result', () {
      final adapter = const UnifiedFoodAdapter();
      final barcodeFood = adapter.adapt(
        _databaseFood(id: 1, uuid: 'one', name: 'Other', barcode: '622123'),
      );
      final textFood = adapter.adapt(
        _databaseFood(id: 2, uuid: 'two', name: '622123'),
      );
      final hits = const OfflineFoodSearchPipeline().search(
        foods: <UnifiedFood>[textFood, barcodeFood],
        query: '٦٢٢١٢٣',
      );

      expect(hits.first.food.id, 'one');
      expect(hits.first.reasons, contains('barcode-exact'));
    });
  });
}

Food _databaseFood({
  int id = 1,
  String uuid = 'food-1',
  String name = 'Food',
  String? arabicName = 'طعام',
  String source = 'local',
  String? barcode,
  bool isCustom = false,
  int nutrientEvidenceMask = 0,
  double fiber = 0,
  double sodium = 0,
}) {
  final now = DateTime(2026, 7, 22);
  return Food(
    id: id,
    uuid: uuid,
    name: name,
    arabicName: arabicName,
    category: 'Test',
    keywords: 'protein, food',
    barcode: barcode,
    servingSize: 100,
    servingUnit: 'g',
    calories: 100,
    protein: 10,
    carbs: 5,
    fats: 4,
    fiber: fiber,
    sugar: 0,
    potassium: 0,
    sodium: sodium,
    calcium: 0,
    iron: 0,
    magnesium: 0,
    phosphorus: 0,
    vitaminC: 0,
    nutrientEvidenceMask: nutrientEvidenceMask,
    verified: true,
    isCustom: isCustom,
    source: source,
    createdAt: now,
    updatedAt: now,
    revision: 1,
    syncStatus: 'local',
  );
}
