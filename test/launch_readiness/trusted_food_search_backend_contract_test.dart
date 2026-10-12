import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_presentation_localizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'USDA units preserve kJ conversion, mcg RAE, known zero and missing instead of IU or wrong fat units',
    () {
      const resolver = TrustedFoodNetworkSearchResolver();
      final food = resolver.decodeServerFoodForTesting({
        'fdc_id': 9001,
        'name': 'TEST units',
        'nutrients': [
          {'name': 'Energy', 'unit': 'kJ', 'amount': 418.4},
          {'name': 'Vitamin A, RAE', 'unit': 'UG', 'amount': 120},
          {'name': 'Vitamin C, total ascorbic acid', 'unit': 'MG', 'amount': 8},
          {'name': 'Sugars, total including NLEA', 'unit': 'G', 'amount': 0},
          {'name': 'Fatty acids, total saturated', 'unit': 'MG', 'amount': 200},
          {'name': 'Cholesterol', 'unit': 'MG', 'amount': 0},
        ],
      });
      expect(food, isNotNull);
      expect(food!.knownValue(FoodNutrient.calories), closeTo(100, 1e-9));
      expect(food.knownValue(FoodNutrient.vitaminA), 120);
      expect(food.knownValue(FoodNutrient.vitaminC), 8);
      expect(food.knownValue(FoodNutrient.sugar), 0);
      expect(food.knownValue(FoodNutrient.cholesterol), 0);
      expect(food.knownValue(FoodNutrient.saturatedFat), isNull);
      expect(
        resolver.decodeServerFoodForTesting({
          'fdc_id': 9,
          'name': 'TEST no energy unit',
          'nutrients': [
            {'name': 'Energy', 'amount': 100},
          ],
        }),
        isNull,
      );
    },
  );
  test('trusted food search keeps USDA credentials server-side', () {
    final backend = File(
      'supabase/functions/food-search/index.ts',
    ).readAsStringSync();
    final client = File(
      'lib/features/nutrition/services/trusted_food_network_search_resolver.dart',
    ).readAsStringSync();

    expect(backend, contains('BIL_USDA_API_KEY'));
    expect(backend, contains('SUPABASE_ANON_KEY'));
    expect(backend, contains('SUPABASE_SECRET_KEYS'));
    expect(backend, contains('auth.auth.getUser(token)'));
    expect(backend, contains('Authorization: `Bearer \${token}`'));
    expect(
      backend,
      contains('return env("SUPABASE_SERVICE_ROLE_KEY")'),
      reason:
          'Legacy server-key fallback remains Edge-only during key migration.',
    );
    expect(backend, contains('bil_food_translation_cache'));
    expect(backend, contains('google-translate-v2-display-only'));
    expect(backend, contains('localized_name'));
    expect(backend, contains('localized_locale'));
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
    expect(backend, contains('BIL_TRANSLATION_API_KEY'));
    expect(backend, contains('query: translatedQuery'));
    expect(backend, contains('search_query: translatedQuery'));
    expect(client, contains("'food-search'"));
    expect(client, contains('Duration(seconds: 16)'));
    expect(client, isNot(contains('BIL_USDA_API_KEY')));
    expect(client, isNot(contains('SUPABASE_SECRET_KEYS')));
    expect(client, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(client, isNot(contains('api.nal.usda.gov')));
  });

  test(
    'trusted localized label is registered without changing USDA identity',
    () {
      FoodPresentationLocalizer.clearTrustedRuntimeTranslationsForTesting();
      addTearDown(
        FoodPresentationLocalizer.clearTrustedRuntimeTranslationsForTesting,
      );
      const resolver = TrustedFoodNetworkSearchResolver();

      final food = resolver.decodeServerFoodForTesting(<String, dynamic>{
        'fdc_id': 321,
        'name': 'Turkey breast, roasted',
        'localized_name': 'صدر ديك رومي مشوي',
        'localized_locale': 'ar',
        'nutrients': <Map<String, Object>>[
          <String, Object>{'name': 'Energy', 'unit': 'KCAL', 'amount': 135},
        ],
      });

      expect(food, isNotNull);
      expect(food!.name, 'Turkey breast, roasted');
      expect(
        FoodPresentationLocalizer.foodName(
          name: food.name,
          localeTag: 'ar',
          source: food.sourceLabel,
        ),
        'صدر ديك رومي مشوي',
      );
    },
  );

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
