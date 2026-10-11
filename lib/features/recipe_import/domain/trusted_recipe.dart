import 'dart:convert';

import 'package:crypto/crypto.dart';

final class TrustedRecipeIngredient {
  const TrustedRecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.sourceRecordId,
  });

  final String name;
  final double quantity;
  final String unit;
  final String? sourceRecordId;

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    if (sourceRecordId != null) 'sourceRecordId': sourceRecordId,
  };
}

final class RecipeNutritionProvenance {
  const RecipeNutritionProvenance({
    required this.source,
    required this.recordId,
    required this.verifiedAt,
  });

  final String source;
  final String recordId;
  final DateTime verifiedAt;

  Map<String, Object?> toJson() => {
    'source': source,
    'recordId': recordId,
    'verifiedAt': verifiedAt.toUtc().toIso8601String(),
  };
}

final class TrustedRecipeNutrition {
  const TrustedRecipeNutrition({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
    required this.provenance,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.potassiumMg,
    this.calciumMg,
    this.magnesiumMg,
    this.phosphorusMg,
    this.ironMg,
    this.vitaminCMg,
  });

  final double caloriesKcal;
  final double proteinG;
  final double carbohydrateG;
  final double fatG;
  final RecipeNutritionProvenance provenance;
  final double? fiberG,
      sugarG,
      sodiumMg,
      potassiumMg,
      calciumMg,
      magnesiumMg,
      phosphorusMg,
      ironMg,
      vitaminCMg;

  Map<String, Object?> toJson() => {
    'caloriesKcal': caloriesKcal,
    'proteinG': proteinG,
    'carbohydrateG': carbohydrateG,
    'fatG': fatG,
    'provenance': provenance.toJson(),
    if (fiberG != null) 'fiberG': fiberG,
    if (sugarG != null) 'sugarG': sugarG,
    if (sodiumMg != null) 'sodiumMg': sodiumMg,
    if (potassiumMg != null) 'potassiumMg': potassiumMg,
    if (calciumMg != null) 'calciumMg': calciumMg,
    if (magnesiumMg != null) 'magnesiumMg': magnesiumMg,
    if (phosphorusMg != null) 'phosphorusMg': phosphorusMg,
    if (ironMg != null) 'ironMg': ironMg,
    if (vitaminCMg != null) 'vitaminCMg': vitaminCMg,
  };
}

final class TrustedRecipeDraft {
  const TrustedRecipeDraft({
    required this.name,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    required this.sourceUrl,
    this.nutrition,
  });

  final String name;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<TrustedRecipeIngredient> ingredients;
  final List<String> steps;
  final Uri? sourceUrl;
  final TrustedRecipeNutrition? nutrition;

  int get totalMinutes => prepMinutes + cookMinutes;

  Map<String, Object?> toJson() => {
    'name': name,
    'servings': servings,
    'prepMinutes': prepMinutes,
    'cookMinutes': cookMinutes,
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'steps': steps,
    if (sourceUrl != null) 'sourceUrl': sourceUrl.toString(),
    if (nutrition != null) 'nutrition': nutrition!.toJson(),
  };

  String get fingerprint {
    final canonical = jsonEncode({
      'name': name.trim().toLowerCase(),
      'servings': servings,
      'ingredients': [
        for (final item in ingredients)
          [
            item.name.trim().toLowerCase(),
            item.quantity,
            item.unit,
            item.sourceRecordId,
          ],
      ],
      'steps': steps.map((step) => step.trim().toLowerCase()).toList(),
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

final class SavedTrustedRecipe {
  const SavedTrustedRecipe({
    required this.id,
    required this.savedAt,
    required this.recipe,
  });

  final String id;
  final DateTime savedAt;
  final TrustedRecipeDraft recipe;

  Map<String, Object?> toJson() => {
    'id': id,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'recipe': recipe.toJson(),
  };
}
