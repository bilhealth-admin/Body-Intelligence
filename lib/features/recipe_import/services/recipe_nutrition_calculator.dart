import '../../../data/database/food_basis_evidence.dart';
import '../../intelligence_center/domain/food_v2/coach_food_v2.dart';
import '../domain/trusted_recipe.dart';
import 'trusted_recipe_ingredient_reconciler.dart';

abstract final class RecipeNutritionCalculator {
  /// Units are dimension-aware. No implied density, cup weight, cooked/raw
  /// conversion, or zero for missing evidence. Results are PER SERVING.
  static double? portionFactor(
    String inputUnit,
    double quantity,
    String basisUnit,
    double basisQuantity,
  ) {
    if (!quantity.isFinite ||
        quantity <= 0 ||
        !basisQuantity.isFinite ||
        basisQuantity <= 0) {
      return null;
    }
    final input = inputUnit.trim().toLowerCase(),
        basis = basisUnit.trim().toLowerCase();
    if (input == basis) return quantity / basisQuantity;
    const mass = {'g': 1.0, 'kg': 1000.0, 'mg': .001, 'oz': 28.349523125};
    const volume = {'ml': 1.0, 'l': 1000.0};
    for (final units in [mass, volume]) {
      if (units.containsKey(input) && units.containsKey(basis)) {
        return quantity * units[input]! / (basisQuantity * units[basis]!);
      }
    }
    return null;
  }

  static TrustedRecipeNutrition? calculate(
    TrustedRecipeDraft draft,
    List<TrustedIngredientMatch> matches, {
    String? ownerKey,
  }) {
    if (draft.servings <= 0 ||
        matches.length != draft.ingredients.length ||
        matches.isEmpty) {
      return null;
    }
    final totals = {for (final n in FoodNutrient.values) n: 0.0};
    final unknown = <FoodNutrient>{};
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i],
          ingredient = draft.ingredients[i],
          food = match.food;
      if (match.status != IngredientMatchStatus.exact ||
          food == null ||
          !identical(match.ingredient, ingredient)) {
        return null;
      }
      final factor = portionFactor(
        ingredient.unit,
        ingredient.quantity,
        food.servingUnit,
        food.servingSize,
      );
      if (factor == null) return null;
      final evidence = FoodBasisEvidence.read(food, ownerKey: ownerKey);
      if (!evidence.isValid) return null;
      for (final n in FoodNutrient.values) {
        final amount = evidence.value(n);
        if (amount == null) {
          unknown.add(n);
        } else {
          totals[n] = totals[n]! + amount * factor / draft.servings;
        }
      }
    }
    if (totals.values.any(
      (value) => !value.isFinite || value < 0 || value > 100000,
    )) {
      return null;
    }
    if (const [
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    ].any(unknown.contains)) {
      return null;
    }
    double? value(FoodNutrient n) => unknown.contains(n) ? null : totals[n];
    return TrustedRecipeNutrition(
      caloriesKcal: totals[FoodNutrient.calories]!,
      proteinG: totals[FoodNutrient.protein]!,
      carbohydrateG: totals[FoodNutrient.carbohydrates]!,
      fatG: totals[FoodNutrient.fat]!,
      fiberG: value(FoodNutrient.fiber),
      sugarG: value(FoodNutrient.sugar),
      sodiumMg: value(FoodNutrient.sodium),
      potassiumMg: value(FoodNutrient.potassium),
      calciumMg: value(FoodNutrient.calcium),
      magnesiumMg: value(FoodNutrient.magnesium),
      phosphorusMg: value(FoodNutrient.phosphorus),
      ironMg: value(FoodNutrient.iron),
      vitaminCMg: value(FoodNutrient.vitaminC),
      provenance: RecipeNutritionProvenance(
        source: 'BIL calculated from selected food records',
        recordId: draft.fingerprint,
        verifiedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
