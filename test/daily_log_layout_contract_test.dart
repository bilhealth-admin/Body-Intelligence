import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Log renders meal entry, water, then structured body context', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();

    final meal = page.indexOf('_buildMealEntry(');
    final meals = page.indexOf('DailyMealsList(', meal);
    final water = page.indexOf('DailyWaterSection(', meals);
    final exercise = page.indexOf('DailyExerciseSection(', water);
    final bodyContext = page.indexOf('DailyBodyContextSection(', exercise);

    expect(meal, greaterThan(0));
    expect(meals, greaterThan(meal));
    expect(water, greaterThan(meals));
    expect(exercise, greaterThan(water));
    expect(bodyContext, greaterThan(exercise));
    expect(mealEntry, contains('SearchAnchor('));
    expect(page, isNot(contains('Anything that may explain today')));
    expect(page, isNot(contains('lines: 4')));
  });
}
