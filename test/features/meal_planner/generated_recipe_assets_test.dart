import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

final _historicalCatalog = File(
  'test/fixtures/historical_recipe_audits/recipe_canonical_100_verified.json',
);

void main() {
  List<Map> records() {
    expect(_historicalCatalog.existsSync(), isTrue);
    final data = jsonDecode(_historicalCatalog.readAsStringSync()) as Map;
    final records = (data['records'] as List).cast<Map>();
    expect(records, hasLength(100));
    return records;
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
  );
  test('generated image hashes are unique', () {
    // Historical review labels are preserved, not granted by this test. Audit
    // all generated states instead of vacuously inspecting only unreviewed ones.
    final generated = records()
        .where(
          (r) =>
              (r['image'] as Map)['status'].toString().startsWith('generated-'),
        )
        .toList();
    expect(generated, hasLength(82));
    final hashes = generated.map((r) => (r['image'] as Map)['sha256']).toList();
    expect(hashes.toSet(), hasLength(hashes.length));
  });
}
