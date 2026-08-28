import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal editors write real profile and preference repositories', () {
    final goals = [
      'lib/features/settings/reference_goals_page.dart',
      'lib/features/settings/reference_goals_components.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(goals, contains('startingWeightEditor'));
    expect(goals, contains("Key('goals-starting-date')"));
    expect(goals, contains('repo.setMany('));
    expect(goals, contains("'goals.startingWeight':"));
    expect(goals, contains("'goals.startingDate':"));
    expect(goals, contains('userProfileRepositoryProvider'));
    expect(goals, contains("'goals.workoutsPerWeek' ? 14 : 300"));
    expect(goals, contains('if (_numberEditorOpen) return null'));
    expect(goals, contains('if (editorOpen) return'));
  });

  test('nutrition goals include complete persisted nutrient key set', () {
    final nutrition = [
      'lib/features/settings/reference_preferences_pages.dart',
      'lib/features/settings/reference_preferences_controls.dart',
      'lib/features/settings/reference_preferences_numeric.dart',
      'lib/features/settings/reference_preferences_macros.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
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
