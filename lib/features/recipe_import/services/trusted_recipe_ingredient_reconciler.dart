import '../../nutrition/services/food_runtime_search_authority.dart';
import '../../nutrition/services/food_search_normalizer.dart';
import '../domain/trusted_recipe.dart';

enum IngredientMatchStatus { exact, ambiguous, missing }

final class TrustedIngredientMatch {
  const TrustedIngredientMatch({
    required this.ingredient,
    required this.status,
    this.foodId,
    this.foodName,
  });
  final TrustedRecipeIngredient ingredient;
  final IngredientMatchStatus status;
  final int? foodId;
  final String? foodName;
}

final class TrustedRecipeIngredientReconciler {
  const TrustedRecipeIngredientReconciler(this._search);
  final FoodRuntimeSearchAuthority _search;

  Future<List<TrustedIngredientMatch>> reconcile(
    TrustedRecipeDraft recipe,
  ) async {
    final output = <TrustedIngredientMatch>[];
    for (final ingredient in recipe.ingredients) {
      final sourceRecordId = ingredient.sourceRecordId;
      if (sourceRecordId != null) {
        final exactFood = await _search.findExact(sourceRecordId);
        if (exactFood != null) {
          output.add(
            TrustedIngredientMatch(
              ingredient: ingredient,
              status: IngredientMatchStatus.exact,
              foodId: exactFood.id,
              foodName: exactFood.name,
            ),
          );
          continue;
        }
      }
      final normalized = FoodSearchNormalizer.normalize(ingredient.name);
      final candidates = await _search.search(ingredient.name, limit: 8);
      final exact = candidates
          .where(
            (food) => FoodSearchNormalizer.normalize(food.name) == normalized,
          )
          .toList(growable: false);
      if (exact.length == 1) {
        output.add(
          TrustedIngredientMatch(
            ingredient: ingredient,
            status: IngredientMatchStatus.exact,
            foodId: exact.single.id,
            foodName: exact.single.name,
          ),
        );
      } else {
        output.add(
          TrustedIngredientMatch(
            ingredient: ingredient,
            status: candidates.isEmpty
                ? IngredientMatchStatus.missing
                : IngredientMatchStatus.ambiguous,
          ),
        );
      }
    }
    return List.unmodifiable(output);
  }
}
