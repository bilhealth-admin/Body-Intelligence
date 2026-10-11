import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/trusted_recipe.dart';
import '../services/trusted_recipe_parser.dart';

final class DuplicateRecipeException implements Exception {
  const DuplicateRecipeException();
}

final class RecipeCollectionUnavailable implements Exception {
  const RecipeCollectionUnavailable();
}

/// Account-scoped durable collection. A corrupt payload is an error, never an
/// empty collection that a subsequent save is allowed to overwrite. Concurrent
/// writers compare-and-swap the exact encoded preimage in one SQLite transaction.
final class TrustedRecipeRepository {
  TrustedRecipeRepository(this._preferences);
  final PreferencesRepository _preferences;
  static const storageKey = 'nutrition.trustedRecipes.v1';

  static List<SavedTrustedRecipe> _decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) throw const RecipeCollectionUnavailable();
      final recipes = <SavedTrustedRecipe>[];
      final ids = <String>{};
      for (final row in decoded) {
        if (row is! Map<String, dynamic> || row['recipe'] is! Map) {
          throw const RecipeCollectionUnavailable();
        }
        final recipe = TrustedRecipeParser.parse(jsonEncode(row['recipe']));
        final savedAt = row['savedAt'] is String
            ? DateTime.tryParse(row['savedAt'] as String)
            : null;
        final id = row['id'];
        if (id is! String || id.isEmpty || savedAt == null || !ids.add(id)) {
          throw const RecipeCollectionUnavailable();
        }
        recipes.add(
          SavedTrustedRecipe(id: id, savedAt: savedAt, recipe: recipe),
        );
      }
      return List.unmodifiable(recipes);
    } on Object {
      throw const RecipeCollectionUnavailable();
    }
  }

  Future<List<SavedTrustedRecipe>> load() async =>
      _decode(await _preferences.get(storageKey));
  Stream<List<SavedTrustedRecipe>> watch() =>
      _preferences.watch(storageKey).map(_decode);

  Future<T> _change<T>(T Function(List<SavedTrustedRecipe>) change) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final before = await _preferences.get(storageKey);
      final rows = _decode(before).toList();
      final result = change(rows);
      final after = jsonEncode(rows.map((item) => item.toJson()).toList());
      if (await _preferences.mutateIfUnchanged(
        expected: {storageKey: before},
        set: {storageKey: after},
      )) {
        return result;
      }
    }
    throw StateError(
      'Recipe collection changed. Retry without losing the draft.',
    );
  }

  Future<SavedTrustedRecipe> saveReviewed(TrustedRecipeDraft recipe) {
    final checked = TrustedRecipeParser.parse(jsonEncode(recipe.toJson()));
    return _change((rows) {
      if (rows.any((item) => item.recipe.fingerprint == checked.fingerprint)) {
        throw const DuplicateRecipeException();
      }
      final saved = SavedTrustedRecipe(
        id: 'recipe-${checked.fingerprint}',
        savedAt: DateTime.now().toUtc(),
        recipe: checked,
      );
      rows.insert(0, saved);
      return saved;
    });
  }

  Future<SavedTrustedRecipe> replaceReviewed(
    String id,
    TrustedRecipeDraft recipe,
  ) {
    final checked = TrustedRecipeParser.parse(jsonEncode(recipe.toJson()));
    return _change((rows) {
      final index = rows.indexWhere((item) => item.id == id);
      if (index < 0) throw StateError('Recipe does not exist');
      if (rows.any(
        (item) =>
            item.id != id && item.recipe.fingerprint == checked.fingerprint,
      )) {
        throw const DuplicateRecipeException();
      }
      final saved = SavedTrustedRecipe(
        id: id,
        savedAt: rows[index].savedAt,
        recipe: checked,
      );
      rows[index] = saved;
      return saved;
    });
  }

  Future<void> delete(String id) => _change<void>((rows) {
    rows.removeWhere((item) => item.id == id);
  });
}
