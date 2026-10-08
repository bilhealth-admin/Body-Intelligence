import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/repositories/food_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../intelligence_center/domain/food_v2/coach_food_v2.dart';
import '../domain/trusted_recipe.dart';

final class RecipeNutritionUnavailableException implements Exception {
  const RecipeNutritionUnavailableException();
}

/// Reuses only a reviewed recipe nutrition snapshot in the authoritative diary.
final class TrustedRecipeDiaryService {
  const TrustedRecipeDiaryService(FoodRepository _, this._meals);

  final MealRepository _meals;

  /// Freezes one already-reviewed recipe serving into the same Food V2
  /// contract used by Coach diary transactions. No nutrition is recalculated:
  /// the reviewed per-serving snapshot is reused exactly, while an explicitly
  /// approved serving mass supplies the gram basis required by Food V2.
  CoachFoodPortion freezeServingPortion({
    required SavedTrustedRecipe saved,
    required double servingGrams,
    required String ruleId,
    required int ruleRevision,
    required CoachFoodOwnerScope scope,
  }) {
    scope.check();
    final nutrition = saved.recipe.nutrition;
    if (nutrition == null) throw const RecipeNutritionUnavailableException();
    if (!servingGrams.isFinite || servingGrams <= 0 || servingGrams > 100000) {
      throw ArgumentError.value(servingGrams, 'servingGrams');
    }
    final food = CoachFoodSnapshot(
      identity: 'trusted-recipe:${saved.recipe.fingerprint}',
      name: saved.recipe.name,
      preparedState: 'reviewed-recipe-serving',
      basisGrams: servingGrams,
      nutrients: CoachFoodNutrients({
        FoodNutrient.calories: nutrition.caloriesKcal,
        FoodNutrient.protein: nutrition.proteinG,
        FoodNutrient.carbohydrates: nutrition.carbohydrateG,
        FoodNutrient.fat: nutrition.fatG,
        FoodNutrient.fiber: null,
        FoodNutrient.sugar: null,
        FoodNutrient.sodium: null,
        FoodNutrient.potassium: null,
        FoodNutrient.calcium: null,
        FoodNutrient.magnesium: null,
        FoodNutrient.phosphorus: null,
        FoodNutrient.iron: null,
        FoodNutrient.vitaminC: null,
      }),
      source: CoachFoodSourceEvidence(
        kind: CoachFoodSourceKind.calculatedRecipe,
        ref:
            'recipe-calculation:${nutrition.provenance.source}:${nutrition.provenance.recordId}',
        revision: saved.recipe.fingerprint,
        confidence: CoachFoodConfidence(
          score: 1,
          basis: 'Reviewed trusted recipe nutrition snapshot',
        ),
      ),
    );
    final ruleSource = CoachFoodSourceEvidence(
      kind: CoachFoodSourceKind.userFixed,
      ref: 'personal-recipe:$ruleId',
      revision: 'r$ruleRevision',
      ownerKey: scope.captured.ownerKey,
      confidence: CoachFoodConfidence(
        score: 1,
        basis: 'Explicit user-approved recipe serving mass',
      ),
    );
    final quantity = CoachFoodQuantities.fromUnit(
      food: food,
      amount: 1,
      inputUnit: 'item',
      rule: CoachFoodUnitRule(
        identity: food.identity,
        preparedState: food.preparedState,
        inputUnit: 'item',
        gramsPerUnit: servingGrams,
        source: ruleSource,
      ),
      scope: scope,
      description: 'One explicitly approved trusted-recipe serving.',
    );
    scope.check();
    return CoachFoodPortion(
      food: food,
      quantity: quantity,
      identityConfidence: CoachFoodConfidence(
        score: 1,
        basis: 'Exact reviewed recipe fingerprint',
      ),
    );
  }

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
