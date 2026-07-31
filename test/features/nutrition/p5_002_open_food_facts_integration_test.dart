import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/integrations/open_food_facts/open_food_facts_client.dart';
import 'package:body_intelligence_log/features/nutrition/integrations/open_food_facts/open_food_facts_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid barcode is rejected without calling the client', () async {
    final client = _FakeClient(null);
    final result = await OpenFoodFactsLookupService(
      client: client,
    ).lookup('123');
    expect(result.status, OpenFoodFactsLookupStatus.invalidBarcode);
    expect(client.calls, 0);
  });

  test('not found and unavailable remain explicit', () async {
    final notFound = await OpenFoodFactsLookupService(
      client: _FakeClient(<String, Object?>{'status': 0}),
    ).lookup('4006381333931');
    expect(notFound.status, OpenFoodFactsLookupStatus.notFound);

    final unavailable = await OpenFoodFactsLookupService(
      client: _ThrowingClient(),
    ).lookup('4006381333931');
    expect(unavailable.status, OpenFoodFactsLookupStatus.unavailable);
  });

  test(
    'product maps to unified branded food preserving missing data',
    () async {
      final result = await OpenFoodFactsLookupService(
        client: _FakeClient(<String, Object?>{
          'status': 1,
          'product': <String, Object?>{
            'product_name': 'Greek Yogurt',
            'product_name_ar': 'زبادي يوناني',
            'brands': 'Example Brand',
            'categories_tags': <String>['en:yogurts'],
            'nutriments': <String, Object?>{
              'energy-kcal_100g': 100,
              'proteins_100g': 10,
              'carbohydrates_100g': 8,
              'fat_100g': 3,
              'sodium_100g': 0.08,
            },
          },
        }),
      ).lookup('٤٠٠٦٣٨١٣٣٣٩٣١');

      expect(result.status, OpenFoodFactsLookupStatus.resolved);
      final food = result.food!;
      expect(food.id, 'openfoodfacts:4006381333931');
      expect(food.source, FoodDataSource.branded);
      expect(food.sourceLabel, 'openfoodfacts');
      expect(food.barcode, '4006381333931');
      expect(food.knownValue(FoodNutrient.sodium), 80);
      expect(food.hasEvidence(FoodNutrient.fiber), isFalse);
      expect(food.verified, isFalse);
    },
  );

  test('product without a usable name is malformed', () async {
    final result = await OpenFoodFactsLookupService(
      client: _FakeClient(<String, Object?>{
        'status': 1,
        'product': <String, Object?>{
          'nutriments': <String, Object?>{'energy-kcal_100g': 10},
        },
      }),
    ).lookup('4006381333931');
    expect(result.status, OpenFoodFactsLookupStatus.malformedProduct);
  });
}

class _FakeClient implements OpenFoodFactsClient {
  final Map<String, Object?>? response;
  int calls = 0;

  _FakeClient(this.response);

  @override
  Future<Map<String, Object?>?> fetchProduct(String canonicalBarcode) async {
    calls++;
    return response;
  }
}

class _ThrowingClient implements OpenFoodFactsClient {
  @override
  Future<Map<String, Object?>?> fetchProduct(String canonicalBarcode) {
    throw StateError('offline');
  }
}
