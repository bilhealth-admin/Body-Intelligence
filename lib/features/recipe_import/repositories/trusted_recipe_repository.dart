import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/trusted_recipe.dart';
import '../services/trusted_recipe_parser.dart';

final class DuplicateRecipeException implements Exception {
  const DuplicateRecipeException();
}

final class TrustedRecipeRepository {
  TrustedRecipeRepository(this._preferences);
  final PreferencesRepository _preferences;

  static const storageKey = 'nutrition.trustedRecipes.v1';

  Future<List<SavedTrustedRecipe>> load() async {
    final encoded = await _preferences.get(storageKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      final recipes = <SavedTrustedRecipe>[];
      for (final row in decoded) {
        if (row is! Map<String, dynamic> || row['recipe'] is! Map) continue;
        final recipe = TrustedRecipeParser.parse(jsonEncode(row['recipe']));
        final savedAt = DateTime.tryParse(row['savedAt'] as String? ?? '');
        final id = row['id'];
        if (id is String && id.isNotEmpty && savedAt != null) {
          recipes.add(
            SavedTrustedRecipe(id: id, savedAt: savedAt, recipe: recipe),
          );
        }
      }
      return List.unmodifiable(recipes);
    } on Object {
      // Corrupt or legacy payloads are never partially trusted.
      return const [];
    }
  }

  Future<SavedTrustedRecipe> saveReviewed(TrustedRecipeDraft recipe) async {
    final existing = await load();
    if (existing.any((item) => item.recipe.fingerprint == recipe.fingerprint)) {
      throw const DuplicateRecipeException();
    }
    final now = DateTime.now().toUtc();
    final saved = SavedTrustedRecipe(
      id: 'recipe-${recipe.fingerprint}',
      savedAt: now,
      recipe: recipe,
    );
    await _preferences.set(
      storageKey,
      jsonEncode([saved.toJson(), ...existing.map((item) => item.toJson())]),
    );
    return saved;
  }

  Future<SavedTrustedRecipe> replaceReviewed(
    String id,
    TrustedRecipeDraft recipe,
  ) async {
    final existing = await load();
    final index = existing.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('Recipe does not exist');
    if (existing.any(
      (item) => item.id != id && item.recipe.fingerprint == recipe.fingerprint,
    )) {
      throw const DuplicateRecipeException();
    }
    final updated = SavedTrustedRecipe(
      id: id,
      savedAt: existing[index].savedAt,
      recipe: recipe,
    );
    final rows = [...existing]..[index] = updated;
    await _preferences.set(
      storageKey,
      jsonEncode(rows.map((item) => item.toJson()).toList()),
    );
    return updated;
  }

  Future<void> delete(String id) async {
    final existing = await load();
    final rows = existing.where((item) => item.id != id).toList();
    if (rows.length == existing.length) return;
    await _preferences.set(
      storageKey,
      jsonEncode(rows.map((item) => item.toJson()).toList()),
    );
  }
}
