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

  test('preserves reviewed records and ships 25 direct localizations', () {
    expect(records, hasLength(1500));
    const supportedLocales = {
      'ar',
      'en',
      'fr',
      'es',
      'tr',
      'de',
      'it',
      'pt-BR',
      'pt-PT',
      'ur',
      'fa',
      'hi',
      'id',
      'ms',
      'ja',
      'ko',
      'zh-Hans',
      'zh-Hant',
      'ru',
      'bn',
      'vi',
      'th',
      'pl',
      'nl',
      'uk',
    };
    for (var index = 0; index < original.length; index++) {
      final expanded = Map<String, dynamic>.from(records[index])
        ..remove('localizations');
      final reviewed = Map<String, dynamic>.from(original[index])
        ..remove('localizations');
      expect(expanded, reviewed, reason: 'reviewed record $index changed');

      final expandedCopy = records[index]['localizations'] as Map;
      final reviewedCopy = original[index]['localizations'] as Map;
      expect(expandedCopy.keys.toSet(), supportedLocales);
      for (final locale in reviewedCopy.keys) {
        expect(expandedCopy[locale], reviewedCopy[locale]);
      }
    }
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
