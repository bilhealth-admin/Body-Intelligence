import 'package:flutter_test/flutter_test.dart';
import '../../support/released_recipe_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;

  setUpAll(() async => records = await releasedRecipeRecords());

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
    // The frozen pre-reconciliation JSON was intentionally retired. Validate
    // every released record, not equality to its obsolete nutrition values.
    for (final record in records) {
      final translations = record['localizations'] as Map;
      expect(translations.keys.toSet(), supportedLocales);
      for (final locale in supportedLocales) {
        final copy = translations[locale] as Map;
        expect(copy['title'], isNotEmpty);
        expect(copy['ingredients'], isNotEmpty);
        expect(copy['steps'], isNotEmpty);
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

  test(
    'non-English ingredient and step arrays are not exact English copies',
    () {
      // A future whole-array exception is allowed only for an explicitly
      // reviewed proper-name-only record. There are no approved exceptions.
      const exactCopyAllowlist = <String>{};
      for (final record in records) {
        final recipeId = record['canonicalId'] as String;
        final localizations = record['localizations'] as Map;
        final english = localizations['en'] as Map;
        for (final entry in localizations.entries) {
          final locale = entry.key as String;
          if (locale == 'en') continue;
          final localization = entry.value as Map;
          for (final field in const ['ingredients', 'steps']) {
            final key = '$recipeId/$locale/$field';
            if (exactCopyAllowlist.contains(key)) continue;
            expect(
              localization[field],
              isNot(equals(english[field])),
              reason: '$key must contain locale-specific copy',
            );
          }
        }
      }
    },
  );

  test(
    'all released records have complete local USDA and serving contracts',
    () {
      for (final record in records) {
        final timing = record['timing'] as Map;
        expect(
          timing['totalMinutes'],
          (timing['prepMinutes'] as int) + (timing['cookMinutes'] as int),
        );
        final method = (record['method'] as List).cast<Map>();
        expect(method, isNotEmpty);
        expect(
          method.map((step) => step['order']),
          orderedEquals(List.generate(method.length, (i) => i + 1)),
        );
        expectRecipeCalculation(record);
        expect((record['nutrition'] as Map)['status'], 'calculated');
        expect((record['nutrition'] as Map)['sourceRefs'], isNotEmpty);
        expect((record['nutrition'] as Map)['perServing'], isA<Map>());
        for (final ingredient in (record['ingredients'] as List).cast<Map>()) {
          expect(ingredient['quantity'], greaterThan(0));
          expect(ingredient['unit'], 'g');
          expect(ingredient['recordId'], startsWith('usda:'));
          expect(ingredient['sourceRefs'], isNotEmpty);
        }
      }
    },
  );
}
