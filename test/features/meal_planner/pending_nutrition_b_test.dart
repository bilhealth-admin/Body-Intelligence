import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final artifact =
      jsonDecode(
            File(
              'artifacts/meal_catalog/recipe_nutrition_pending_b.json',
            ).readAsStringSync(),
          )
          as Map;
  final records = (artifact['records'] as List).cast<Map>();
  test('pending B has exactly 17 traceable records', () {
    expect(records, hasLength(17));
    for (final r in records) {
      expect(r['servings'], isPositive);
      expect(r['timing'], isNotNull);
      expect(r['method'], isNotEmpty);
    }
  });
  test('every USDA reference exists locally', () {
    final db = sqlite3.open(
      'assets/catalogs/bil_food_core.sqlite',
      mode: OpenMode.readOnly,
    );
    addTearDown(db.close);
    for (final r in records) {
      for (final i in r['formulation'] as List) {
        final m = i as Map;
        expect(
          db.select('SELECT 1 FROM foods WHERE fdc_id=?', [
            int.parse((m['recordId'] as String).split(':').last),
          ]),
          hasLength(1),
        );
      }
    }
  });
}
