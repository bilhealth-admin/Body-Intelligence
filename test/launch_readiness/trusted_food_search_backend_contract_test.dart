import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusted food search keeps USDA credentials server-side', () {
    final backend = File(
      'supabase/functions/food-search/index.ts',
    ).readAsStringSync();
    final client = File(
      'lib/features/nutrition/services/trusted_food_network_search_resolver.dart',
    ).readAsStringSync();

    expect(backend, contains('BIL_USDA_API_KEY'));
    expect(backend, contains('SUPABASE_ANON_KEY'));
    expect(backend, contains('auth.auth.getUser()'));
    expect(backend, contains('Authorization: authorization'));
    expect(backend, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(backend, contains('request.body.getReader()'));
    expect(backend, contains('total > maxRequestBytes'));
    expect(backend, contains('food_search_minute'));
    expect(backend, contains('food_search_hour'));
    expect(backend, contains('auth.rpc("bil_consume_rate_limit"'));
    expect(
      backend.indexOf('const quota = await access.consumeQuota()'),
      lessThan(backend.indexOf('await runtime.fetch(')),
    );
    expect(backend, contains('requireAllWords: true'));
    expect(backend, contains('Math.min(requestedLimit, 20)'));
    expect(client, contains("'food-search'"));
    expect(client, isNot(contains('BIL_USDA_API_KEY')));
    expect(client, isNot(contains('api.nal.usda.gov')));
  });

  test('USDA search nutrients stay on their documented 100 gram basis', () {
    const resolver = TrustedFoodNetworkSearchResolver();

    final food = resolver.decodeServerFoodForTesting(<String, dynamic>{
      'fdc_id': 123,
      'name': 'Example branded food',
      'data_type': 'Branded',
      'serving_size': 30,
      'serving_unit': 'g',
      'nutrients': <Map<String, Object>>[
        <String, Object>{'name': 'Energy', 'unit': 'KCAL', 'amount': 400},
        <String, Object>{'name': 'Protein', 'unit': 'G', 'amount': 12},
      ],
    });

    expect(food, isNotNull);
    expect(food!.serving.amount, 100);
    expect(food.serving.unit, 'g');
    expect(food.serving.grams, 100);
    expect(food.knownValue(FoodNutrient.calories), 400);
    expect(food.knownValue(FoodNutrient.protein), 12);
    expect(food.sourceLabel, 'USDA FoodData Central — verified');
  });
}
