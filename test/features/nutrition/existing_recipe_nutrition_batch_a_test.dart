import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const artifactPath =
      'artifacts/meal_catalog/existing_recipe_nutrition_batch_a.json';

  test('batch A has nine complete standardized formulations', () {
    final artifact = jsonDecode(File(artifactPath).readAsStringSync())
        as Map<String, dynamic>;
    final records = (artifact['records'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(records, hasLength(9));
    for (final record in records) {
      expect(record['status'], 'verified-calculation');
      expect((record['servings'] as num), greaterThan(0));
      final nutrients = record['nutritionPerServing'] as Map<String, dynamic>;
      expect(nutrients.values, everyElement(isA<num>()));
      expect(nutrients.values, everyElement(greaterThanOrEqualTo(0)));
    }
  });

  test('all declared USDA source refs resolve in the shipped local catalog', () {
    final artifact = jsonDecode(File(artifactPath).readAsStringSync())
        as Map<String, dynamic>;
    final database = sqlite3.open(
      'assets/catalogs/bil_food_core.sqlite',
      mode: OpenMode.readOnly,
    );
    try {
      for (final record in artifact['records'] as List<dynamic>) {
        for (final ingredient
            in (record as Map<String, dynamic>)['formulation'] as List<dynamic>) {
          for (final ref in (ingredient as Map<String, dynamic>)['sourceRefs']
              as List<dynamic>) {
            final sourceRef = ref as Map<String, dynamic>;
            final rows = database.select(
              'SELECT description FROM foods WHERE fdc_id = ?',
              [sourceRef['fdcId']],
            );
            expect(rows, hasLength(1));
            expect(rows.single['description'], sourceRef['description']);
          }
        }
      }
    } finally {
      database.close();
    }
  });

  test('per-serving nutrition exactly follows the declared calculation', () {
    final artifact = jsonDecode(File(artifactPath).readAsStringSync())
        as Map<String, dynamic>;
    final policy = artifact['calculationPolicy'] as Map<String, dynamic>;
    expect(policy['requiresCompleteGramFormulation'], isTrue);
    expect(policy['requiresPositiveServingCount'], isTrue);
    expect(policy['missingValuePolicy'], 'blocked-not-zero');
    for (final record in artifact['records'] as List<dynamic>) {
      final typed = record as Map<String, dynamic>;
      final servings = (typed['servings'] as num).toDouble();
      final formulation =
          typed['formulation'] as List<dynamic>;
      final expected = <String, double>{};
      for (final ingredient in formulation.cast<Map<String, dynamic>>()) {
        final grams = (ingredient['grams'] as num).toDouble();
        final nutrients = ingredient['nutrientsPer100g'] as Map<String, dynamic>;
        for (final entry in nutrients.entries) {
          expected[entry.key] = (expected[entry.key] ?? 0) +
              (entry.value as num).toDouble() * grams / 100 / servings;
        }
      }
      final actual = typed['nutritionPerServing'] as Map<String, dynamic>;
      for (final entry in expected.entries) {
        expect((actual[entry.key] as num).toDouble(), closeTo(entry.value, 0.011));
      }
    }
  });
}
