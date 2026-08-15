import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';

/// Durable local authority for the recipe-discovery saved collection.
final class RecipeFavoritesRepository {
  RecipeFavoritesRepository(this._preferences);

  final PreferencesRepository _preferences;

  static const storageKey = 'wellness.recipe_favorites.v1';

  Future<Set<String>> load() async {
    return _decode(await _preferences.get(storageKey));
  }

  Future<Set<String>> toggle(String recipeId) async {
    final id = recipeId.trim();
    if (id.isEmpty) throw ArgumentError.value(recipeId, 'recipeId');
    late Set<String> favorites;
    await _preferences.update(storageKey, (raw) {
      favorites = _decode(raw);
      favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
      return jsonEncode(favorites.toList(growable: false)..sort());
    });
    return Set.unmodifiable(favorites);
  }

  Set<String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    } on Object {
      return <String>{};
    }
  }
}
