import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/repositories/food_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../domain/trusted_recipe.dart';

final class RecipeNutritionUnavailableException implements Exception {
  const RecipeNutritionUnavailableException();
}

/// Reuses only a reviewed recipe nutrition snapshot in the authoritative diary.
final class TrustedRecipeDiaryService {
  const TrustedRecipeDiaryService(FoodRepository _, this._meals);

  final MealRepository _meals;

  Future<void> addServing({
    required SavedTrustedRecipe saved,
    required DateTime date,
    required String mealType,
  }) async {
    final nutrition = saved.recipe.nutrition;
    if (nutrition == null) throw const RecipeNutritionUnavailableException();
    final digest = sha256.convert(
      utf8.encode(
        jsonEncode({
          'recipeFingerprint': saved.recipe.fingerprint,
          'caloriesKcal': nutrition.caloriesKcal,
          'proteinG': nutrition.proteinG,
          'carbohydrateG': nutrition.carbohydrateG,
          'fatG': nutrition.fatG,
          'source': nutrition.provenance.source,
          'recordId': nutrition.provenance.recordId,
        }),
      ),
    );
    await _meals.addCalculatedRecipeServingAtomically(
      date: date,
      mealType: mealType,
      foodUuid: 'calculated-recipe-$digest',
      recipeName: saved.recipe.name,
      source:
          'recipe-calculation:${nutrition.provenance.source}:'
          '${nutrition.provenance.recordId}:${saved.recipe.fingerprint}',
      calories: nutrition.caloriesKcal,
      protein: nutrition.proteinG,
      carbohydrates: nutrition.carbohydrateG,
      fat: nutrition.fatG,
    );
  }
}
