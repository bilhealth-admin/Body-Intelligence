import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../support/released_recipe_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;
  setUpAll(() async => records = await releasedRecipeRecords());
  test(
    'all 1500 released records have explicit portions, timing and ordered methods',
    () {
      expect(records, hasLength(1500));
      for (final record in records) {
        expect((record['serving'] as Map)['count'], isPositive);
        final timing = record['timing'] as Map;
        expect(
          timing['totalMinutes'],
          (timing['prepMinutes'] as int) + (timing['cookMinutes'] as int),
        );
        expect(timing['totalMinutes'], greaterThan(0));
        final method = (record['method'] as List).cast<Map>();
        expect(method, isNotEmpty);
        expect(
          method.map((step) => step['order']),
          orderedEquals(List.generate(method.length, (i) => i + 1)),
        );
      }
    },
  );
  test('every shipped ingredient has a resolvable local USDA reference', () {
    final db = sqlite3.open(
      'assets/catalogs/bil_food_core.sqlite',
      mode: OpenMode.readOnly,
    );
    addTearDown(db.close);
    final checked = <String>{};
    for (final record in records) {
      for (final ingredient in (record['ingredients'] as List).cast<Map>()) {
        final id = ingredient['recordId'] as String;
        expect(ingredient['sourceRefs'], [id]);
        if (!checked.add(id)) continue;
        expect(
          db.select('SELECT 1 FROM foods WHERE fdc_id=?', [
            int.parse(id.split(':').last),
          ]),
          hasLength(1),
        );
      }
    }
    expect(checked, hasLength(120));
  });
}
