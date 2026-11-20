part of 'recipe_release_repository.dart';

enum _FoodClass {
  plant,
  milk,
  egg,
  fish,
  shellfish,
  treeNut,
  peanut,
  soy,
  sesame,
  wheat,
  meat,
  unresolved,
}

typedef _SourceIngredient = (String, String, String);

/// BIL's selection metadata for the release formulation. The authored index
/// tags and raw source remain separately available.
final class RecipeDietaryEvidence {
  const RecipeDietaryEvidence._(
    this.complete,
    this.dietTags,
    this.allergens,
    this.ingredientNames,
    this.highProtein,
  );
  static const unknown = RecipeDietaryEvidence._(false, {}, {}, [], false);
  final bool complete, highProtein;
  final Set<String> dietTags, allergens;
  final List<String> ingredientNames;

  factory RecipeDietaryEvidence._fromRecord(Map<String, dynamic> record) {
    final rows = record['ingredients'];
    if (rows is! List || rows.isEmpty) return unknown;
    final nutrition = record['nutrition'];
    final serving = nutrition is Map ? nutrition['perServing'] : null;
    return RecipeDietaryEvidence._fromIngredients(
      [
        for (final row in rows)
          if (row is Map &&
              !RecipeIngredientEvidence.ingredientNeedsReview(row))
            (
              row['recordId'] as String,
              row['itemId'] as String,
              row['sourceDescription'] as String,
            )
          else
            null,
      ],
      (record['dietTags'] as List).whereType<String>(),
      (record['allergens'] as List).whereType<String>(),
      verifiedProtein:
          serving is Map &&
          !RecipeIngredientEvidence.recordNeedsReview(record) &&
          meetsProteinEnergyShare(serving['proteinG'], serving['kcal']),
    );
  }

  factory RecipeDietaryEvidence._fromIngredients(
    List<_SourceIngredient?> ingredients,
    Iterable<String> authoredTags,
    Iterable<String> authoredAllergens, {
    bool verifiedProtein = false,
  }) {
    if (ingredients.isEmpty) return unknown;
    final classes = <_FoodClass>{};
    final allergens = <String>{...authoredAllergens};
    final names = <String>[];
    var complete = true;
    var identitiesMatch = true;
    for (final ingredient in ingredients) {
      final food = _sourceFoods[ingredient?.$1];
      if (ingredient == null ||
          food == null ||
          food.$1 != ingredient.$3 ||
          !food.$3.contains(ingredient.$2) ||
          RecipeIngredientEvidence.hasKnownMismatch(
            ingredient.$2,
            ingredient.$3,
          )) {
        complete = false;
        identitiesMatch = false;
        continue;
      }
      final kind = food.$2;
      classes.add(kind);
      names.addAll([ingredient.$2, ingredient.$3]);
      if (kind == _FoodClass.unresolved ||
          const {
            'optional-nuts-or-seeds',
            'water-or-unsalted-stock',
            'cooked-grain',
            'herbs',
            'fresh-fruit',
            'fish-fillet',
          }.contains(ingredient.$2)) {
        complete = false;
      }
      if (const {
        _FoodClass.milk,
        _FoodClass.egg,
        _FoodClass.fish,
        _FoodClass.shellfish,
        _FoodClass.treeNut,
        _FoodClass.peanut,
        _FoodClass.soy,
        _FoodClass.sesame,
        _FoodClass.wheat,
      }.contains(kind)) {
        allergens.add(kind.name);
      }
    }
    final tags = <String>{...authoredTags}
      ..removeAll(const {
        'vegetarian',
        'vegan',
        'pescatarian',
        'high-protein',
        'high_protein',
      });
    if (complete && !classes.contains(_FoodClass.meat)) {
      tags.add('pescatarian');
      if (!classes.contains(_FoodClass.fish) &&
          !classes.contains(_FoodClass.shellfish)) {
        tags.add('vegetarian');
        if (!classes.contains(_FoodClass.milk) &&
            !classes.contains(_FoodClass.egg)) {
          tags.add('vegan');
        }
      }
    }
    return RecipeDietaryEvidence._(
      complete,
      Set.unmodifiable(tags),
      Set.unmodifiable(allergens),
      List.unmodifiable(names),
      identitiesMatch && verifiedProtein,
    );
  }

  /// Internal recipe-style criterion from Regulation (EC) 1924/2006, Annex
  /// HIGH PROTEIN and Regulation (EU) 1169/2011, Annex XIV. Evaluated on the
  /// verified nutrients for one serving.
  static bool meetsProteinEnergyShare(Object? grams, Object? kcal) {
    if (grams is! num ||
        kcal is! num ||
        !grams.isFinite ||
        !kcal.isFinite ||
        grams <= 0 ||
        kcal <= 0) {
      return false;
    }
    final energy = grams * 4;
    return energy <= kcal && energy >= kcal * .20;
  }

  bool allows(DietaryPreferences preferences) {
    if (!complete && preferences.hasFoodSelectionConstraints) return false;
    if (preferences.allergens.any(
      (allergen) => allergens.contains(allergen.name),
    )) {
      return false;
    }
    return DietaryCompatibility.allows(
      preferences: preferences,
      dietTags: dietTags,
      allergens: allergens,
      ingredients: ingredientNames,
    );
  }
}
