import 'dart:convert';

import 'package:body_intelligence_log/features/wellness/presentation/recipe_artwork_registry.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every displayed recipe photo matches its canonical manifest hash',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/catalogs/recipes/v1/recipe-images.json',
                ),
              )
              as Map<String, dynamic>;
      final entries = (manifest['entries'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final byId = {
        for (final entry in entries) entry['canonical_id'] as String: entry,
      };

      expect(bundledRecipeImageAssets, hasLength(15));
      for (final MapEntry(key: id, value: path)
          in bundledRecipeImageAssets.entries) {
        final manifestEntry = byId[id];
        expect(manifestEntry, isNotNull, reason: id);
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        expect(
          bytes,
          hasLength(manifestEntry!['size_bytes'] as int),
          reason: id,
        );
        expect(
          sha256.convert(bytes).toString(),
          manifestEntry['sha256'],
          reason: '$id must never display merely similar recipe art',
        );
      }
    },
  );
}
