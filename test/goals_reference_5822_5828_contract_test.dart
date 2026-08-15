import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal editors write real profile and preference repositories', () {
    final goals = File(
      'lib/features/settings/reference_goals_page.dart',
    ).readAsStringSync();
    expect(goals, contains('startingWeightEditor'));
    expect(goals, contains("Key('goals-starting-date')"));
    expect(goals, contains("repo.set('goals.startingWeight'"));
    expect(goals, contains("repo.set('goals.startingDate'"));
    expect(goals, contains('userProfileRepositoryProvider'));
    expect(goals, contains("'goals.workoutsPerWeek' ? 14 : 300"));
    expect(goals, contains('if (_numberEditorOpen) return null'));
    expect(goals, contains('if (editorOpen) return'));
  });

  test('nutrition goals include complete persisted nutrient key set', () {
    final nutrition = File(
      'lib/features/settings/reference_preferences_pages.dart',
    ).readAsStringSync();
    for (final key in [
      'goal.calories',
      'goal.carbsPercent',
      'goal.proteinPercent',
      'goal.fatPercent',
      'goal.saturatedFat',
      'goal.polyunsaturatedFat',
      'goal.monounsaturatedFat',
      'goal.transFat',
      'goal.cholesterol',
      'goal.sodium',
      'goal.potassium',
      'goal.fiber',
      'goal.sugar',
      'goal.vitaminA',
      'goal.vitaminC',
      'goal.calcium',
      'goal.iron',
    ]) {
      expect(nutrition, contains("'$key'"), reason: key);
    }
    expect(nutrition, contains('if (editorOpen) return'));
    expect(nutrition, contains('preferencesRepositoryProvider'));
  });
}
