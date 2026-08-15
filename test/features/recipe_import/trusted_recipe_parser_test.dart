import 'dart:convert';

import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> validRecipe() => {
    'name': 'Lentil bowl',
    'servings': 2,
    'prepMinutes': 10,
    'cookMinutes': 25,
    'sourceUrl': 'https://example.test/recipes/lentil-bowl',
    'ingredients': [
      {'name': 'Lentils', 'quantity': 200, 'unit': 'g'},
      {'name': 'Water', 'quantity': 2, 'unit': 'cup'},
    ],
    'steps': ['Rinse the lentils.', 'Cook until tender.'],
  };

  test('parses strict quantities units servings steps and times', () {
    final recipe = TrustedRecipeParser.parse(jsonEncode(validRecipe()));
    expect(recipe.name, 'Lentil bowl');
    expect(recipe.servings, 2);
    expect(recipe.totalMinutes, 35);
    expect(recipe.ingredients, hasLength(2));
    expect(recipe.steps, hasLength(2));
    expect(recipe.nutrition, isNull);
  });

  test('does not fetch a URL in local mode', () {
    expect(
      () => TrustedRecipeParser.parse('https://example.test/recipe'),
      throwsA(
        isA<TrustedRecipeParseException>().having(
          (error) => error.code,
          'code',
          'url_fetch_disabled',
        ),
      ),
    );
  });

  test('rejects unsupported or missing ingredient units', () {
    final raw = validRecipe();
    raw['ingredients'] = [
      {'name': 'Lentils', 'quantity': 1, 'unit': 'handful'},
    ];
    expect(
      () => TrustedRecipeParser.parse(jsonEncode(raw)),
      throwsA(
        isA<TrustedRecipeParseException>().having(
          (error) => error.code,
          'code',
          'unsupported_ingredient_unit',
        ),
      ),
    );
  });

  test('rejects nutrition without complete provenance', () {
    final raw = validRecipe();
    raw['nutrition'] = {
      'caloriesKcal': 400,
      'proteinG': 20,
      'carbohydrateG': 60,
      'fatG': 10,
    };
    expect(
      () => TrustedRecipeParser.parse(jsonEncode(raw)),
      throwsA(
        isA<TrustedRecipeParseException>().having(
          (error) => error.code,
          'code',
          'nutrition_provenance_required',
        ),
      ),
    );
  });

  test('accepts nutrition with source record and verification time', () {
    final raw = validRecipe();
    raw['nutrition'] = {
      'caloriesKcal': 400,
      'proteinG': 20,
      'carbohydrateG': 60,
      'fatG': 10,
      'provenance': {
        'source': 'USDA FoodData Central',
        'recordId': 'fdc-123',
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      },
    };
    final recipe = TrustedRecipeParser.parse(jsonEncode(raw));
    expect(recipe.nutrition?.provenance.recordId, 'fdc-123');
  });
}
