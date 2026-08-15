import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> records;
  late List<Map<String, dynamic>> original;

  setUpAll(() {
    final expanded =
        jsonDecode(
              File(
                'artifacts/meal_catalog/recipe_canonical_1500.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    records = (expanded['records'] as List)
        .cast<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    final source =
        jsonDecode(
              File(
                'artifacts/meal_catalog/recipe_canonical_100_verified.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    original = (source['records'] as List)
        .cast<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  });

  test('preserves 100 records and allocates exactly 300 per locale', () {
    expect(records, hasLength(1500));
    expect(records.take(100).toList(), original);
    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(
        records.where((record) => record['primaryLocale'] == locale),
        hasLength(300),
      );
    }
  });

  test('all ids and normalized content fingerprints are unique', () {
    expect(
      records.map((record) => record['canonicalId']).toSet(),
      hasLength(1500),
    );
    expect(
      records.map((record) => record['contentFingerprint']).toSet(),
      hasLength(1500),
    );
  });

  test('new records have complete local USDA and serving contracts', () {
    for (final record in records.skip(100)) {
      final timing = record['timing'] as Map;
      expect(
        timing['totalMinutes'],
        (timing['prepMinutes'] as int) + (timing['cookMinutes'] as int),
      );
      expect((record['method'] as List).map((step) => (step as Map)['order']), [
        1,
        2,
        3,
      ]);
      expect((record['nutrition'] as Map)['status'], 'calculated');
      expect((record['nutrition'] as Map)['sourceRefs'], isNotEmpty);
      expect((record['nutrition'] as Map)['perServing'], isA<Map>());
      for (final ingredient in (record['ingredients'] as List).cast<Map>()) {
        expect(ingredient['quantity'], greaterThan(0));
        expect(ingredient['unit'], 'g');
        expect(ingredient['recordId'], startsWith('usda:'));
        expect(ingredient['sourceRefs'], isNotEmpty);
      }
      expect((record['image'] as Map)['status'], 'planned');
      expect((record['image'] as Map)['assetPath'], isNull);
    }
  });
}
