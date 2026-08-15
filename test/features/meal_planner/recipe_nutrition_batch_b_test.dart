import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final artifact =
      jsonDecode(
            File(
              'artifacts/meal_catalog/existing_recipe_nutrition_batch_b.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final records = (artifact['records'] as List).cast<Map<String, Object?>>();
  test(
    'batch B is nine recipes with truthful calculated or blocked status',
    () {
      final summary = artifact['summary'] as Map;
      expect(records, hasLength(9));
      expect(summary['calculated'], 9);
      expect(summary['blocked'], 0);
      expect(
        records
            .where((r) => r['formulationStatus'] == 'blocked')
            .map((r) => r['canonicalId']),
        isEmpty,
      );
    },
  );
  test(
    'calculated nutrients exactly aggregate local USDA per-100g evidence',
    () {
      final db = sqlite3.open(
        'assets/catalogs/bil_food_core.sqlite',
        mode: OpenMode.readOnly,
      );
      addTearDown(db.close);
      const columns = {
        'kcal': 'energy_kcal',
        'proteinG': 'protein_g',
        'carbohydrateG': 'carbs_g',
        'fatG': 'fat_g',
        'fiberG': 'fiber_g',
        'sugarG': 'sugars_g',
        'sodiumMg': 'sodium_mg',
        'potassiumMg': 'potassium_mg',
      };
      for (final recipe in records.where(
        (r) => r['formulationStatus'] == 'calculated',
      )) {
        final nutrition = recipe['nutrition'] as Map<String, Object?>;
        final actual = nutrition['perServing'] as Map<String, Object?>;
        for (final nutrient in columns.entries) {
          var expected = 0.0;
          for (final raw in recipe['ingredients'] as List) {
            final ingredient = (raw as Map).cast<String, Object?>();
            final row = db.select(
              'SELECT ${nutrient.value} FROM foods WHERE fdc_id=?',
              [ingredient['fdcId']],
            ).single;
            expected +=
                (row[nutrient.value] as num).toDouble() *
                (ingredient['grams'] as num).toDouble() /
                100;
          }
          expect(
            (actual[nutrient.key] as num).toDouble(),
            double.parse(expected.toStringAsFixed(2)),
            reason: '${recipe['canonicalId']}:${nutrient.key}',
          );
        }
      }
    },
  );
}
