import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending A calculations are exact and blocked values are never zero-filled',
    () {
      final artifact = jsonDecode(
        File(
          'artifacts/meal_catalog/recipe_nutrition_pending_a.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final records = (artifact['records'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(records, hasLength(17));

      for (final record in records) {
        final blocked =
            (record['blockedIngredientIds'] as List<dynamic>).isNotEmpty;
        expect(
          record['status'],
          blocked ? 'blocked' : 'verified-calculation',
        );
        final nutrition =
            record['nutritionPerServing'] as Map<String, dynamic>;
        if (blocked) {
          expect(nutrition.values, everyElement(isNull));
          continue;
        }
        final servings = (record['servings'] as num).toDouble();
        final expected = <String, double>{};
        for (final ingredient
            in (record['formulation'] as List<dynamic>)
                .cast<Map<String, dynamic>>()) {
          final grams = (ingredient['grams'] as num).toDouble();
          final nutrients =
              ingredient['nutrientsPer100g'] as Map<String, dynamic>;
          for (final entry in nutrients.entries) {
            expected[entry.key] =
                (expected[entry.key] ?? 0) +
                (entry.value as num).toDouble() * grams / 100 / servings;
          }
        }
        for (final entry in expected.entries) {
          expect(
            (nutrition[entry.key] as num).toDouble(),
            closeTo(entry.value, .011),
          );
        }
      }
    },
  );
}
