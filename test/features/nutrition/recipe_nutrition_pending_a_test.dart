import 'dart:convert';
import 'package:body_intelligence_log/features/recipe_import/domain/recipe_ingredient_evidence.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/released_recipe_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;
  setUpAll(() async => records = await releasedRecipeRecords());

  test(
    'all shipped calculations replace the pending stage with source evidence',
    () {
      expect(records, hasLength(1500));
      for (final record in records) {
        expectRecipeCalculation(record);
        expect(
          RecipeIngredientEvidence.recordNeedsReview(record),
          isFalse,
          reason: record['canonicalId'] as String,
        );
      }
    },
  );
  test(
    'missing macro evidence remains blocked even when a zero total is supplied',
    () {
      for (final nutrient in const [
        'kcal',
        'proteinG',
        'carbohydrateG',
        'fatG',
      ]) {
        final record =
            jsonDecode(jsonEncode(records.first)) as Map<String, dynamic>;
        ((record['ingredients'] as List).first['nutrientsPer100g']
                as Map)[nutrient] =
            null;
        ((record['nutrition'] as Map)['perServing'] as Map)[nutrient] = 0;
        expect(
          RecipeIngredientEvidence.recordNeedsReview(record),
          isTrue,
          reason: nutrient,
        );
      }
    },
  );
  test(
    'unknown optional nutrients stay null and may not become partial totals',
    () {
      for (final nutrient in const [
        'fiberG',
        'sugarG',
        'sodiumMg',
        'potassiumMg',
      ]) {
        final record =
            jsonDecode(jsonEncode(records.first)) as Map<String, dynamic>;
        ((record['ingredients'] as List).first['nutrientsPer100g']
                as Map)[nutrient] =
            null;
        final nutrition = record['nutrition'] as Map;
        (nutrition['perServing'] as Map)[nutrient] = null;
        nutrition['missingNutrients'] = [nutrient];
        expect(
          RecipeIngredientEvidence.recordNeedsReview(record),
          isFalse,
          reason: nutrient,
        );
        (nutrition['perServing'] as Map)[nutrient] = 0;
        expect(
          RecipeIngredientEvidence.recordNeedsReview(record),
          isTrue,
          reason: nutrient,
        );
      }
    },
  );
}
