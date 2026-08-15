import 'dart:convert';

import '../domain/trusted_recipe.dart';

final class TrustedRecipeParseException implements Exception {
  const TrustedRecipeParseException(this.code);
  final String code;
  @override
  String toString() => code;
}

abstract final class TrustedRecipeParser {
  static const allowedUnits = <String>{
    'g',
    'kg',
    'mg',
    'ml',
    'l',
    'tsp',
    'tbsp',
    'cup',
    'piece',
    'slice',
    'oz',
  };

  static TrustedRecipeDraft parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) throw const TrustedRecipeParseException('empty');
    final uri = Uri.tryParse(trimmed);
    if (!trimmed.startsWith('{') &&
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http')) {
      throw const TrustedRecipeParseException('url_fetch_disabled');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const TrustedRecipeParseException('invalid_json');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const TrustedRecipeParseException('root_object_required');
    }
    const required = {
      'name',
      'servings',
      'prepMinutes',
      'cookMinutes',
      'ingredients',
      'steps',
    };
    const allowedRoot = {...required, 'sourceUrl', 'nutrition'};
    if (!decoded.keys.toSet().containsAll(required)) {
      throw const TrustedRecipeParseException('missing_required_field');
    }
    if (decoded.keys.any((key) => !allowedRoot.contains(key))) {
      throw const TrustedRecipeParseException('unknown_field');
    }
    final name = _text(decoded['name'], max: 120, code: 'invalid_name');
    final servings = _integer(
      decoded['servings'],
      min: 1,
      max: 100,
      code: 'invalid_servings',
    );
    final prep = _integer(
      decoded['prepMinutes'],
      min: 0,
      max: 1440,
      code: 'invalid_prep_time',
    );
    final cook = _integer(
      decoded['cookMinutes'],
      min: 0,
      max: 2880,
      code: 'invalid_cook_time',
    );
    final rawIngredients = decoded['ingredients'];
    if (rawIngredients is! List ||
        rawIngredients.isEmpty ||
        rawIngredients.length > 100) {
      throw const TrustedRecipeParseException('invalid_ingredients');
    }
    final ingredients = <TrustedRecipeIngredient>[];
    for (final raw in rawIngredients) {
      if (raw is! Map<String, dynamic>) {
        throw const TrustedRecipeParseException('invalid_ingredient');
      }
      if (raw.keys.toSet().difference(const {
            'name',
            'quantity',
            'unit',
            'sourceRecordId',
          }).isNotEmpty ||
          !raw.keys.toSet().containsAll(const {'name', 'quantity', 'unit'})) {
        throw const TrustedRecipeParseException('invalid_ingredient');
      }
      final ingredientName = _text(
        raw['name'],
        max: 120,
        code: 'invalid_ingredient_name',
      );
      final quantity = raw['quantity'];
      if (quantity is! num ||
          !quantity.toDouble().isFinite ||
          quantity <= 0 ||
          quantity > 100000) {
        throw const TrustedRecipeParseException('invalid_ingredient_quantity');
      }
      final unit = _text(
        raw['unit'],
        max: 12,
        code: 'invalid_ingredient_unit',
      ).toLowerCase();
      if (!allowedUnits.contains(unit)) {
        throw const TrustedRecipeParseException('unsupported_ingredient_unit');
      }
      ingredients.add(
        TrustedRecipeIngredient(
          name: ingredientName,
          quantity: quantity.toDouble(),
          unit: unit,
          sourceRecordId: raw['sourceRecordId'] == null
              ? null
              : _sourceRecordId(raw['sourceRecordId']),
        ),
      );
    }
    final rawSteps = decoded['steps'];
    if (rawSteps is! List || rawSteps.isEmpty || rawSteps.length > 100) {
      throw const TrustedRecipeParseException('invalid_steps');
    }
    final steps = [
      for (final step in rawSteps) _text(step, max: 1000, code: 'invalid_step'),
    ];
    Uri? sourceUrl;
    if (decoded['sourceUrl'] != null) {
      sourceUrl = Uri.tryParse(
        _text(decoded['sourceUrl'], max: 2048, code: 'invalid_source_url'),
      );
      if (sourceUrl == null ||
          (sourceUrl.scheme != 'https' && sourceUrl.scheme != 'http') ||
          sourceUrl.host.isEmpty) {
        throw const TrustedRecipeParseException('invalid_source_url');
      }
    }
    final nutrition = decoded['nutrition'] == null
        ? null
        : _nutrition(decoded['nutrition']);
    return TrustedRecipeDraft(
      name: name,
      servings: servings,
      prepMinutes: prep,
      cookMinutes: cook,
      ingredients: List.unmodifiable(ingredients),
      steps: List.unmodifiable(steps),
      sourceUrl: sourceUrl,
      nutrition: nutrition,
    );
  }

  static String _sourceRecordId(Object? value) {
    final result = _text(value, max: 40, code: 'invalid_ingredient');
    if (!RegExp(r'^usda:\d+$').hasMatch(result)) {
      throw const TrustedRecipeParseException('invalid_ingredient');
    }
    return result;
  }

  static TrustedRecipeNutrition _nutrition(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const TrustedRecipeParseException('invalid_nutrition');
    }
    final provenance = raw['provenance'];
    if (provenance is! Map<String, dynamic>) {
      throw const TrustedRecipeParseException('nutrition_provenance_required');
    }
    const nutritionKeys = {
      'caloriesKcal',
      'proteinG',
      'carbohydrateG',
      'fatG',
      'provenance',
    };
    if (raw.length != nutritionKeys.length ||
        raw.keys.any((key) => !nutritionKeys.contains(key))) {
      throw const TrustedRecipeParseException('invalid_nutrition');
    }
    const provenanceKeys = {'source', 'recordId', 'verifiedAt'};
    if (provenance.length != provenanceKeys.length ||
        provenance.keys.any((key) => !provenanceKeys.contains(key))) {
      throw const TrustedRecipeParseException('nutrition_provenance_required');
    }
    double nutrient(String key) {
      final value = raw[key];
      if (value is! num ||
          !value.toDouble().isFinite ||
          value < 0 ||
          value > 100000) {
        throw TrustedRecipeParseException('invalid_nutrition_$key');
      }
      return value.toDouble();
    }

    final source = _text(
      provenance['source'],
      max: 200,
      code: 'invalid_nutrition_source',
    );
    final recordId = _text(
      provenance['recordId'],
      max: 200,
      code: 'invalid_nutrition_record',
    );
    final verifiedAt = DateTime.tryParse(
      _text(provenance['verifiedAt'], max: 80, code: 'invalid_nutrition_date'),
    );
    if (verifiedAt == null ||
        verifiedAt.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        )) {
      throw const TrustedRecipeParseException('invalid_nutrition_date');
    }
    return TrustedRecipeNutrition(
      caloriesKcal: nutrient('caloriesKcal'),
      proteinG: nutrient('proteinG'),
      carbohydrateG: nutrient('carbohydrateG'),
      fatG: nutrient('fatG'),
      provenance: RecipeNutritionProvenance(
        source: source,
        recordId: recordId,
        verifiedAt: verifiedAt.toUtc(),
      ),
    );
  }

  static String _text(Object? value, {required int max, required String code}) {
    if (value is! String || value.trim().isEmpty || value.trim().length > max) {
      throw TrustedRecipeParseException(code);
    }
    return value.trim();
  }

  static int _integer(
    Object? value, {
    required int min,
    required int max,
    required String code,
  }) {
    if (value is! int || value < min || value > max) {
      throw TrustedRecipeParseException(code);
    }
    return value;
  }
}
