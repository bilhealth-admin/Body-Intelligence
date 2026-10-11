import 'dart:convert';

import '../../features/intelligence_center/domain/food_v2/coach_food_v2.dart';

/// Immutable per-serving evidence. A serving is NOT assigned an invented gram
/// weight. This extends the existing nullable JSON column without a migration.
final class RecipeServingEvidence {
  RecipeServingEvidence({
    required this.identity,
    required this.name,
    required this.source,
    required this.ownerKey,
    required this.perServing,
    required this.servings,
  }) {
    if (identity.trim().isEmpty ||
        identity.length > 240 ||
        name.trim().isEmpty ||
        name.length > 500 ||
        source.trim().isEmpty ||
        source.length > 4096 ||
        ownerKey.trim().isEmpty ||
        ownerKey.length > 200 ||
        !servings.isFinite ||
        servings <= 0 ||
        servings > 100) {
      throw const FormatException('Invalid recipe serving evidence.');
    }
    for (final nutrient in FoodNutrient.values) {
      final amount = perServing[nutrient];
      if (amount != null && !(amount * servings).isFinite) {
        throw const FormatException('Invalid recipe nutrient total.');
      }
    }
  }

  static const schema = 'bil.recipe.serving.v1';
  static const sourcePrefix = 'recipe_serving_v1:';
  final String identity, name, source, ownerKey;
  final CoachFoodNutrients perServing;
  final double servings;

  String get sourceLabel => '$sourcePrefix$source';
  double? value(FoodNutrient nutrient) =>
      perServing[nutrient] == null ? null : perServing[nutrient]! * servings;

  RecipeServingEvidence withServings(double amount) => RecipeServingEvidence(
    identity: identity,
    name: name,
    source: source,
    ownerKey: ownerKey,
    perServing: perServing,
    servings: amount,
  );

  Map<String, Object?> toJson() => {
    'schema': schema,
    'identity': identity,
    'name': name,
    'source': source,
    'ownerKey': ownerKey,
    'servings': servings,
    'nutrients': perServing.toJson(),
  };

  String encodeForStorage() => jsonEncode(toJson());

  factory RecipeServingEvidence.decode(String raw) {
    if (utf8.encode(raw).length > 65536) {
      throw const FormatException('Recipe evidence exceeds the storage bound.');
    }
    final data = jsonDecode(raw);
    const keys = {
      'schema',
      'identity',
      'name',
      'source',
      'ownerKey',
      'servings',
      'nutrients',
    };
    if (data is! Map<String, dynamic> ||
        data.length != keys.length ||
        !keys.every(data.containsKey) ||
        data['schema'] != schema ||
        data['identity'] is! String ||
        data['name'] is! String ||
        data['source'] is! String ||
        data['ownerKey'] is! String ||
        data['servings'] is! num) {
      throw const FormatException('Unsupported recipe serving evidence.');
    }
    return RecipeServingEvidence(
      identity: data['identity'] as String,
      name: data['name'] as String,
      source: data['source'] as String,
      ownerKey: data['ownerKey'] as String,
      servings: (data['servings'] as num).toDouble(),
      perServing: CoachFoodNutrients.fromJson(data['nutrients']),
    );
  }
}
