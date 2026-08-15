import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog =
      jsonDecode(
            File(
              'artifacts/meal_catalog/existing_recipe_canonical_seeds.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final records = (catalog['records'] as List).cast<Map<String, Object?>>();

  test('18 existing recipes are canonical and remain 482 short of target', () {
    final target =
        jsonDecode(
              File(
                'artifacts/meal_catalog/recipe_catalog_target_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final releaseTarget = target['bilReleaseTarget'] as Map<String, Object?>;
    expect(records, hasLength(18));
    expect(releaseTarget['canonicalRecipeCount'], 500);
    expect(500 - records.length, 482);
    expect((catalog['claims'] as Map)['marketedRecipeCount'], 0);
  });

  test('content and image fingerprints reject all duplicate seeds', () {
    final content = <String>{};
    final images = <String>{};
    for (final record in records) {
      expect(content.add(record['contentFingerprint']! as String), isTrue);
      final image = record['image'] as Map<String, Object?>;
      final path = image['assetPath']! as String;
      final actual = sha256.convert(File(path).readAsBytesSync()).toString();
      expect(image['sha256'], actual);
      expect(images.add(actual), isTrue);
    }
  });

  test('unknown quantities and nutrition remain explicitly pending', () {
    for (final record in records) {
      final nutrition = record['nutrition'] as Map<String, Object?>;
      expect(nutrition['status'], 'pending');
      expect(nutrition['sourceRefs'], isEmpty);
      expect(nutrition['reviewedAt'], isNull);
      expect((nutrition['perServing'] as Map).values, everyElement(isNull));
      final timing = record['timing'] as Map<String, Object?>;
      expect(timing['totalMinutes'], greaterThan(0));
      final method = (record['method'] as List).cast<Map<String, Object?>>();
      expect(
        method.map((step) => step['order']),
        orderedEquals(List.generate(method.length, (index) => index + 1)),
      );
    }
  });
}
