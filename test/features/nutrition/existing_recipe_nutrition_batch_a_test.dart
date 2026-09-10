import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../support/released_recipe_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;
  setUpAll(() async {
    records = (await releasedRecipeRecords())
        .where((r) => originalRecipeBatchA.contains(r['canonicalId']))
        .toList();
  });

  test(
    'all nine original batch A formulations survive in the shipped release',
    () {
      expect(
        records.map((r) => r['canonicalId']).toSet(),
        originalRecipeBatchA,
      );
      for (final record in records) {
        expectRecipeCalculation(record);
      }
    },
  );

  test(
    'all declared USDA refs and descriptions resolve in the shipped catalog',
    () {
      final database = sqlite3.open(
        'assets/catalogs/bil_food_core.sqlite',
        mode: OpenMode.readOnly,
      );
      addTearDown(database.close);
      for (final record in records) {
        for (final ingredient in (record['ingredients'] as List).cast<Map>()) {
          final id = ingredient['recordId'] as String;
          final rows = database.select('SELECT * FROM foods WHERE fdc_id = ?', [
            int.parse(id.split(':').last),
          ]);
          expect(rows, hasLength(1));
          expect(ingredient['sourceRefs'], [id]);
          expect(ingredient['sourceDescription'], rows.single['description']);
          for (final nutrient in recipeNutrientColumns.entries) {
            expect(
              (ingredient['nutrientsPer100g'] as Map)[nutrient.key],
              rows.single[nutrient.value],
            );
          }
        }
      }
    },
  );

  test('per-serving nutrition follows the complete weighed formulation', () {
    expect(records, hasLength(9));
    for (final record in records) {
      expectRecipeCalculation(record);
    }
  });
}
