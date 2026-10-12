part of 'cloud_nutrition_snapshot_codec.dart';

bool _goalKey(String key) =>
    NutritionGoalSnapshot.storageKeys.contains(key) ||
    key == nutritionGoalSchedulePreferenceKey ||
    key.startsWith('goal.backup.v1.');

extension _CloudNutritionCollections on CloudNutritionSnapshotCodec {
  Future<void> _applyRecipe(CloudNutritionSnapshot snapshot) async {
    final preferences = PreferencesRepository(database);
    final repository = TrustedRecipeRepository(preferences);
    final current = (await repository.load()).toList();
    if (snapshot.deleted) {
      current.removeWhere((recipe) => recipe.id == snapshot.id);
    } else {
      final incoming = _objectMap(snapshot.data['recipe']);
      if (incoming.keys.toSet().difference(const {
            'id',
            'savedAt',
            'recipe',
          }).isNotEmpty ||
          incoming['id'] != snapshot.id) {
        throw const FormatException('Invalid cloud recipe identity.');
      }
      final savedAt = _date(incoming['savedAt']);
      final recipe = TrustedRecipeParser.parse(jsonEncode(incoming['recipe']));
      final dependencies = await _putDependencies(snapshot.data['foods']);
      for (final ingredient in recipe.ingredients) {
        final source = ingredient.sourceRecordId;
        if (source != null &&
            source.startsWith('local:') &&
            !dependencies.containsKey(source.substring(6))) {
          throw const FormatException(
            'Cloud recipe omitted a linked ingredient.',
          );
        }
      }
      final index = current.indexWhere((row) => row.id == snapshot.id);
      final saved = SavedTrustedRecipe(
        id: snapshot.id,
        savedAt: savedAt,
        recipe: recipe,
      );
      if (index < 0) {
        current.add(saved);
      } else {
        current[index] = saved;
      }
    }
    current.sort((a, b) {
      final date = b.savedAt.compareTo(a.savedAt);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    await preferences.set(
      TrustedRecipeRepository.storageKey,
      jsonEncode(current.map((recipe) => recipe.toJson()).toList()),
    );
  }

  Future<void> _applyGoals(CloudNutritionSnapshot snapshot) async {
    final current = await database.select(database.preferences).get();
    final priorKeys = current
        .where((row) => _goalKey(row.key))
        .map((row) => row.key)
        .toSet();
    final values = <String, String>{};
    if (!snapshot.deleted) {
      if (snapshot.data['referenceVersion'] !=
          CloudNutritionSnapshotCodec.referenceVersion) {
        throw const FormatException('Unsupported nutrition reference version.');
      }
      final incoming = _objectMap(snapshot.data['values']);
      for (final entry in incoming.entries) {
        if (!_goalKey(entry.key) ||
            entry.value is! String ||
            (entry.value! as String).length > 1048576) {
          throw const FormatException(
            'Unsupported cloud nutrition preference.',
          );
        }
        // Raw invalid/legacy values are evidence, not an absent customization.
        // The shared goal resolver retains the same state after restoration.
        values[entry.key] = entry.value! as String;
      }
      values[CloudNutritionSnapshotCodec.referencePreference] =
          CloudNutritionSnapshotCodec.referenceVersion;
    } else {
      priorKeys.add(CloudNutritionSnapshotCodec.referencePreference);
    }
    final preferences = PreferencesRepository(database);
    await preferences.setManyInCurrentTransaction(values);
    await preferences.removeManyInCurrentTransaction(
      priorKeys.difference(values.keys.toSet()),
    );
  }
}
