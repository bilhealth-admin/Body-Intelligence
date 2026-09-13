import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

final _generatedCatalog = File(
  'artifacts/meal_catalog/recipe_canonical_100_verified.json',
);

void main() {
  final skipGeneratedAssetAudit = _generatedCatalog.existsSync()
      ? false
      : 'Requires the host-only generated meal-catalog audit artifacts.';

  List<Map> records() {
    final data = jsonDecode(_generatedCatalog.readAsStringSync()) as Map;
    return (data['records'] as List).cast<Map>();
  }

  test(
    'every catalog image is fail-closed or points to a present exact asset',
    () {
      for (final r in records()) {
        final image = r['image'] as Map;
        final path = image['assetPath'];
        if (path == null) {
          expect(['planned', 'missing', 'pending'], contains(image['status']));
          continue;
        }
        final f = File(path as String);
        expect(f.existsSync(), isTrue, reason: r['canonicalId'] as String);
        expect(sha256.convert(f.readAsBytesSync()).toString(), image['sha256']);
      }
    },
    skip: skipGeneratedAssetAudit,
  );
  test('generated image hashes are unique', () {
    final hashes = records()
        .where((r) => (r['image'] as Map)['status'] == 'generated-unreviewed')
        .map((r) => (r['image'] as Map)['sha256'])
        .toList();
    expect(hashes.toSet(), hasLength(hashes.length));
  }, skip: skipGeneratedAssetAudit);
}
