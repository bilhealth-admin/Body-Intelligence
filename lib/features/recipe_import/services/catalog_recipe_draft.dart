import '../../wellness/repositories/recipe_release_repository.dart';
import '../domain/recipe_ingredient_evidence.dart';
import '../domain/trusted_recipe.dart';

/// The reviewed snapshot is shared by discovery, Coach and saved recipes.
/// Changing quantities later invalidates nutrition in RecipeDraftForm.
abstract final class CatalogRecipeDraft {
  static TrustedRecipeDraft fromDetail(
    RecipeCatalogDetail detail,
    String locale,
  ) {
    final record = detail.record;
    final localization = detail.localization(locale);
    final nutrition = record['nutrition'] as Map<String, dynamic>;
    final perServing = nutrition['perServing'] as Map<String, dynamic>;
    final valid = !RecipeIngredientEvidence.recordNeedsReview(record);
    final timing = record['timing'] as Map<String, dynamic>;
    return TrustedRecipeDraft(
      name: localization['title'] as String,
      servings: (record['serving'] as Map)['count'] as int,
      prepMinutes: timing['prepMinutes'] as int,
      cookMinutes: timing['cookMinutes'] as int,
      ingredients: [
        for (final item
            in (record['ingredients'] as List).cast<Map<String, dynamic>>())
          TrustedRecipeIngredient(
            name: item['itemId'] as String,
            quantity: (item['grams'] as num).toDouble(),
            unit: 'g',
            sourceRecordId: item['recordId'] as String?,
          ),
      ],
      steps: (localization['steps'] as List).cast<String>(),
      sourceUrl: null,
      nutrition: !valid
          ? null
          : TrustedRecipeNutrition(
              caloriesKcal: (perServing['kcal'] as num).toDouble(),
              proteinG: (perServing['proteinG'] as num).toDouble(),
              carbohydrateG: (perServing['carbohydrateG'] as num).toDouble(),
              fatG: (perServing['fatG'] as num).toDouble(),
              provenance: RecipeNutritionProvenance(
                source: 'BIL calculated recipe / USDA FoodData Central',
                recordId:
                    '${record['canonicalId']}@${nutrition['calculationRevision']}',
                verifiedAt: DateTime.utc(2026, 9, 10),
              ),
            ),
    );
  }
}
