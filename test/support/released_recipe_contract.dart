import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the shipped, hash-checked source, never an ignored generation-stage
// artifact. This helper does not load or decode recipe images.
Future<List<Map<String, dynamic>>> releasedRecipeRecords() async {
  final repository = RecipeReleaseRepository();
  final index = await repository.loadIndex();
  expect(index, hasLength(1500));
  return [
    for (final summary in index) (await repository.loadDetail(summary)).record,
  ];
}

const recipeNutrientColumns = {
  'kcal': 'energy_kcal',
  'proteinG': 'protein_g',
  'carbohydrateG': 'carbs_g',
  'fatG': 'fat_g',
  'fiberG': 'fiber_g',
  'sugarG': 'sugars_g',
  'sodiumMg': 'sodium_mg',
  'potassiumMg': 'potassium_mg',
};

const originalRecipeBatchA = {
  'lentil-soup',
  'yogurt-oats',
  'chickpea-salad',
  'shakshuka',
  'grilled-fish-vegetables',
  'chicken-shawarma-bowl',
  'vegetable-lentil-stew',
  'hummus-falafel-plate',
  'quinoa-tabbouleh',
};
const originalRecipeBatchB = {
  'overnight-oats-figs',
  'spinach-omelet',
  'shrimp-rice-bowl',
  'tofu-stir-fry',
  'bean-corn-salad',
  'chicken-sweet-potato',
  'mediterranean-chicken-bowl',
  'roasted-quinoa-bowl',
  'salmon-avocado-bowl',
};

void expectRecipeCalculation(Map<String, dynamic> record) {
  final nutrition = record['nutrition'] as Map;
  final servings = (record['serving'] as Map)['count'] as num;
  expect(servings.isFinite && servings > 0, isTrue);
  expect(nutrition['servings'], servings);
  expect(nutrition['status'], 'calculated');
  final actual = nutrition['perServing'] as Map;
  final ingredients = (record['ingredients'] as List).cast<Map>();
  expect(ingredients, isNotEmpty);
  expect(actual.keys.toSet(), recipeNutrientColumns.keys.toSet());
  for (final key in recipeNutrientColumns.keys) {
    var sum = 0.0;
    var unknown = false;
    for (final ingredient in ingredients) {
      final grams = ingredient['grams'] as num;
      expect(grams.isFinite && grams > 0, isTrue);
      expect(ingredient['quantity'], grams);
      expect(ingredient['unit'], 'g');
      final source = ingredient['nutrientsPer100g'] as Map;
      expect(source.containsKey(key), isTrue);
      final value = source[key] as num?;
      if (value == null) {
        unknown = true;
      } else {
        expect(value.isFinite && value >= 0, isTrue);
        sum += value * grams / 100;
      }
    }
    final reason = '${record['canonicalId']}:$key';
    if (unknown) {
      expect(actual[key], isNull, reason: reason);
      expect(nutrition['missingNutrients'], contains(key), reason: reason);
    } else {
      expect(actual[key], closeTo(sum / servings, .00001), reason: reason);
    }
  }
}
