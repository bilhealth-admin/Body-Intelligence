import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal names are stored atomically and consumed by diary rows', () {
    final settings = File(
      'lib/features/settings/reference_preferences_pages.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/daily_log/providers/daily_log_provider.dart',
    ).readAsStringSync();
    final meals = File(
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
    ).readAsStringSync();
    expect(settings, contains('.mutate(set: set'));
    expect(settings, contains('canPop: !saving'));
    expect(providers, contains('diaryMealNamesProvider'));
    expect(meals, contains('_resolvedMealName(context, mealNames'));
  });

  test('default search selection controls real nutrition landing tab', () {
    final source = File(
      'lib/features/nutrition/presentation/meals_recipes_foods_page.dart',
    ).readAsStringSync();
    expect(source, contains("get('diary.defaultSearchTab')"));
    expect(source, contains("'meals' => 0"));
    expect(source, contains("'recipes' => 1"));
    expect(source, contains("'my_foods' || _ => 2"));
    expect(source, contains('initialIndex: initialIndex'));
  });

  test('diary fallback copy used by defaults exists across 25 locales', () {
    for (final locale in RuntimeCopy.supported) {
      for (final key in const [
        'Breakfast',
        'Lunch',
        'Dinner',
        'Snack',
        'Unavailable',
      ]) {
        final value = RuntimeCopy.resolve(key, locale);
        expect(value, isNotNull, reason: '$locale: $key');
        expect(value!.trim(), isNotEmpty, reason: '$locale: $key');
      }
    }
  });

  test('macro grams derive only from a complete valid personal goal', () {
    final grams = deriveMacroGrams(const ['2000', '50', '25', '25']);
    expect(grams, isNotNull);
    expect(grams![0], 250);
    expect(grams[1], 125);
    expect(grams[2], closeTo(55.555, 0.001));
    expect(deriveMacroGrams(const [null, '50', '25', '25']), isNull);
    expect(deriveMacroGrams(const ['2000', '50', '25', '20']), isNull);
    expect(deriveMacroGrams(const ['NaN', '50', '25', '25']), isNull);
  });

  test('stored nutrition goals reject every corrupt domain', () {
    expect(validStoredNutritionGoal('goal.calories', '', '2000'), isTrue);
    expect(validStoredNutritionGoal('goal.calories', '', 'NaN'), isFalse);
    expect(validStoredNutritionGoal('goal.calories', '', '-5'), isFalse);
    expect(validStoredNutritionGoal('goal.carbsPercent', '%', '150'), isFalse);
    expect(validStoredNutritionGoal('goal.sodium', 'mg', '1000001'), isFalse);
    expect(validStoredNutritionGoal('goal.fiber', 'g', '10001'), isFalse);
  });
}
