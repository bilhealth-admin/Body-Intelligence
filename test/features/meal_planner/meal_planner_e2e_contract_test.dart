import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/meal_planner/presentation/meal_planner_page.dart',
  ).readAsStringSync();

  test('planner has one durable producer-storage-consumer path', () {
    expect(source, contains("'mealPlanner.preferences.v1'"));
    expect(source, contains("'mealPlanner.week.v1'"));
    expect(source, contains("'mealPlanner.groceryChecks.v1'"));
    expect(source, contains('MealPlanPreferences.fromJson'));
    expect(source, contains('WeeklyMealPlan.decode'));
    expect(source, contains('plan.encode()'));
    expect(source, contains('_engine.groceryList'));
    expect(source, contains('_prep(copy)'));
  });

  test('planner, prep and grocery copy is complete in five locales', () {
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale': {"), reason: locale);
    }
    for (final key in const [
      'week',
      'grocery',
      'prepMode',
      'preferences',
      'shareGrocery',
      'diet_balanced',
      'diet_vegetarian',
      'diet_highProtein',
      'estimateNotice',
    ]) {
      expect(RegExp("'$key':").allMatches(source).length, 5, reason: key);
    }
  });
}
