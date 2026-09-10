/// A conservative rejection check, not nutritional verification. A source ID
/// that exists can still refer to a different food/preparation.
abstract final class RecipeIngredientEvidence {
  static bool hasKnownMismatch(String ingredient, String sourceDescription) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp('[^a-z]+'), ' ').trim();
    final name = ' ${normalize(ingredient)} ';
    final description = ' ${normalize(sourceDescription)} ';
    if (description.trim().isEmpty) return false;
    for (final preparation in const [
      'bologna',
      'powder',
      'crackers',
      'cracker',
      'flour',
      'candy',
      'sausage',
      'juice',
      'sauce',
      'oil',
      'bread',
      'roll',
      'butter',
      'soup',
      'formula',
      'gravy',
      'jam',
      'jelly',
      'drink',
      'eggnog',
      'cornstarch',
      'mayonnaise',
      'candies',
      'babyfood',
    ]) {
      // USDA describes tahini as sesame butter; these are the same food, not
      // a different preparation of a generic sesame ingredient.
      if (preparation == 'butter' &&
          name.contains(' tahini ') &&
          description.contains(' tahini ')) {
        continue;
      }
      if (preparation == 'bread' && name.contains(' flatbread ')) continue;
      if (description.contains(' $preparation ') &&
          !name.contains(' $preparation ')) {
        return true;
      }
    }
    if (name.contains(' yogurt ') &&
        !name.contains(' tofu ') &&
        description.contains(' tofu ')) {
      return true;
    }
    if (name.contains(' artichoke ') &&
        !name.contains(' jerusalem ') &&
        description.contains(' jerusalem ')) {
      return true;
    }
    if (name.contains(' whole wheat ') &&
        !description.contains(' whole wheat ')) {
      return true;
    }
    if (name.contains(' beans ') &&
        !name.contains(' rice ') &&
        (description.contains(' restaurant ') ||
            description.contains(' liquid '))) {
      return true;
    }
    if (name.contains(' pie crust ') &&
        !name.contains(' chocolate ') &&
        description.contains(' chocolate ')) {
      return true;
    }
    if (name.contains(' raw ') && description.contains(' cooked ')) return true;
    if (name.contains(' cooked ') && description.contains(' raw ')) return true;
    return false;
  }

  static bool ingredientNeedsReview(Map value) {
    final id = value['recordId'];
    final refs = value['sourceRefs'];
    final name = value['itemId'];
    final description = value['sourceDescription'];
    final grams = value['grams'];
    return id is! String ||
        id.isEmpty ||
        refs is! List ||
        !refs.contains(id) ||
        name is! String ||
        description is! String ||
        description.trim().isEmpty ||
        !_finite(grams) ||
        (grams as num) <= 0 ||
        hasKnownMismatch(name, description);
  }

  /// A numeric source identifier alone is not evidence. Check the exact source
  /// set, weighed quantities, divisor and all supplied per-100g calculations.
  /// Unknown optional nutrients stay null; a partial sum is never a total.
  static bool recordNeedsReview(Map<String, dynamic> record) {
    final ingredients = record['ingredients'];
    final nutrition = record['nutrition'];
    final serving = record['serving'];
    if (ingredients is! List ||
        ingredients.isEmpty ||
        ingredients.any(
          (value) => value is! Map || ingredientNeedsReview(value),
        ) ||
        nutrition is! Map ||
        serving is! Map ||
        !_finite(serving['count']) ||
        (serving['count'] as num) <= 0 ||
        nutrition['servings'] != serving['count'] ||
        nutrition['status'] != 'calculated') {
      return true;
    }
    final refs = nutrition['sourceRefs'];
    final expectedRefs = ingredients.map((i) => (i as Map)['recordId']).toSet();
    if (refs is! List ||
        refs.length != expectedRefs.length ||
        !refs.toSet().containsAll(expectedRefs)) {
      return true;
    }
    final perServing = nutrition['perServing'];
    if (perServing is! Map) return true;
    for (final nutrient in const [
      'kcal',
      'proteinG',
      'carbohydrateG',
      'fatG',
      'fiberG',
      'sugarG',
      'sodiumMg',
      'potassiumMg',
    ]) {
      var sum = 0.0;
      var unknown = false;
      for (final raw in ingredients) {
        final item = raw as Map;
        final source = item['nutrientsPer100g'];
        if (source is! Map || !source.containsKey(nutrient)) return true;
        final value = source[nutrient];
        if (value == null) {
          unknown = true;
        } else if (!_finite(value)) {
          return true;
        } else {
          sum += (value as num) * (item['grams'] as num) / 100;
        }
      }
      final stored = perServing[nutrient];
      if (unknown) {
        if (const {
              'kcal',
              'proteinG',
              'carbohydrateG',
              'fatG',
            }.contains(nutrient) ||
            stored != null ||
            nutrition['missingNutrients'] is! List ||
            !(nutrition['missingNutrients'] as List).contains(nutrient)) {
          return true;
        }
      } else if (!_finite(stored) ||
          ((stored as num) - sum / (serving['count'] as num)).abs() > 0.00001) {
        return true;
      }
    }
    return false;
  }

  static bool _finite(Object? value) =>
      value is num && value.isFinite && value >= 0;
}
