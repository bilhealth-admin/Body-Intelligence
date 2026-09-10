import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../support/released_recipe_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;
  setUpAll(() async {
    records = (await releasedRecipeRecords())
        .where((r) => originalRecipeBatchB.contains(r['canonicalId']))
        .toList();
  });
  test(
    'all nine batch B recipes retain calculated evidence in the release',
    () {
      expect(
        records.map((r) => r['canonicalId']).toSet(),
        originalRecipeBatchB,
      );
      for (final record in records) {
        expectRecipeCalculation(record);
      }
    },
  );
  test(
    'per-serving nutrients aggregate the actual local USDA rows and divisor',
    () {
      final db = sqlite3.open(
        'assets/catalogs/bil_food_core.sqlite',
        mode: OpenMode.readOnly,
      );
      addTearDown(db.close);
      for (final recipe in records) {
        final nutrition = recipe['nutrition'] as Map;
        final actual = nutrition['perServing'] as Map;
        final servings = (recipe['serving'] as Map)['count'] as num;
        expect(servings, greaterThan(0));
        for (final nutrient in recipeNutrientColumns.entries) {
          var expected = 0.0;
          var unknown = false;
          for (final ingredient
              in (recipe['ingredients'] as List).cast<Map>()) {
            final row = db.select(
              'SELECT ${nutrient.value} FROM foods WHERE fdc_id=?',
              [int.parse((ingredient['recordId'] as String).split(':').last)],
            ).single;
            final value = row[nutrient.value] as num?;
            if (value == null) {
              unknown = true;
            } else {
              expected += value * (ingredient['grams'] as num) / 100 / servings;
            }
          }
          expect(
            actual[nutrient.key],
            unknown ? isNull : closeTo(expected, .00001),
            reason: '${recipe['canonicalId']}:${nutrient.key}',
          );
        }
      }
    },
  );
}
