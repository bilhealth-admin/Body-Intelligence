import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/recipe_ingredient_evidence.dart';
import '../../support/released_recipe_contract.dart';
import '../../../tool/recipe_catalog/extract_existing_recipe_seeds.dart'
    as seed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> released;
  setUpAll(() async => released = await releasedRecipeRecords());

  test('18 existing recipes remain explicit seeds for the release target', () {
    final originalIds = {...originalRecipeBatchA, ...originalRecipeBatchB};
    expect(originalIds, hasLength(18));
    expect(released, hasLength(1500));
    final ids = released.map((r) => r['canonicalId']).toSet();
    expect(ids, containsAll(originalIds));
    expect(ids.difference(originalIds), hasLength(1482));
  });

  test('content and image fingerprints reject all duplicate seeds', () {
    // Historical image-generation check remains separate from the host-only
    // release contract. Never restore these old artifacts into runtime assets.
    final catalog =
        jsonDecode(
              File(
                'artifacts/meal_catalog/existing_recipe_canonical_seeds.json',
              ).readAsStringSync(),
            )
            as Map;
    final records = (catalog['records'] as List).cast<Map<String, Object?>>();
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
    final unknown = seed.ingredient('red lentils', 0);
    expect(unknown['quantity'], isNull);
    expect(unknown['unit'], isNull);
    expect(unknown.containsKey('grams'), isFalse);
    expect(seed.ingredient('200 g red lentils', 0)['quantity'], 200);
    final record =
        jsonDecode(jsonEncode(released.first)) as Map<String, dynamic>;
    (record['ingredients'] as List).first['grams'] = null;
    expect(RecipeIngredientEvidence.recordNeedsReview(record), isTrue);
    // A pending record cannot acquire calculated nutrition by a status label.
    final nutrition = record['nutrition'] as Map;
    nutrition['status'] = 'pending';
    nutrition['sourceRefs'] = [];
    nutrition['perServing'] = {
      for (final k in recipeNutrientColumns.keys) k: null,
    };
    expect(RecipeIngredientEvidence.recordNeedsReview(record), isTrue);
    nutrition['status'] = 'calculated';
    expect(RecipeIngredientEvidence.recordNeedsReview(record), isTrue);
  });
}
