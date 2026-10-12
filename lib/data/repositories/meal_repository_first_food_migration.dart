part of 'meal_repository.dart';

extension FirstFoodLegacyDiary on MealRepository {
  /// An imported older diary is not a new first meal. Include soft-deleted
  /// history and never replace an existing ready/done milestone.
  Future<String?> prepareFirstFoodMilestone({
    required bool Function() isCurrent,
  }) => _database.transaction(() async {
    if (!isCurrent()) return null;
    final preferences = PreferencesRepository(_database);
    final marker = await preferences.get(firstMealCelebrationPreferenceKey);
    if (marker != null || !isCurrent()) return marker;
    final prior = await (_database.select(
      _database.mealItems,
    )..limit(1)).getSingleOrNull();
    if (prior == null || !isCurrent()) return null;
    final written = await preferences.mutateIfUnchanged(
      expected: const {firstMealCelebrationPreferenceKey: null},
      set: const {firstMealCelebrationPreferenceKey: 'done'},
      isCurrent: isCurrent,
    );
    return written
        ? 'done'
        : preferences.get(firstMealCelebrationPreferenceKey);
  });
}
