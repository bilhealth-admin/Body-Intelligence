import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Log links to a focused body context page after exercise', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();
    final bodyContextPage = File(
      'lib/features/daily_log/daily_body_context_page.dart',
    ).readAsStringSync();

    final meal = page.indexOf('_buildMealEntry(');
    final meals = page.indexOf('DailyMealsList(', meal);
    final water = page.indexOf('DailyWaterSection(', meals);
    final exercise = page.indexOf('DailyExerciseSection(', water);
    final bodyContext = page.indexOf(
      "Key('daily-log-body-context-link')",
      exercise,
    );

    expect(meal, greaterThan(0));
    expect(meals, greaterThan(meal));
    expect(water, greaterThan(meals));
    expect(exercise, greaterThan(water));
    expect(bodyContext, greaterThan(exercise));
    expect(page, isNot(contains('DailyBodyContextSection(')));
    expect(bodyContextPage, contains('DailyBodyContextSection('));
    expect(bodyContextPage, contains('saveBodyContext('));
    expect(mealEntry, contains('SearchAnchor('));
    expect(page, isNot(contains('Anything that may explain today')));
    expect(page, isNot(contains('lines: 4')));
  });

  test('every body context option has a bundled visual asset', () {
    final inputSections = File(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
    ).readAsStringSync();
    for (final asset in const [
      'poor_sleep_v1.png',
      'great_sleep_v1.png',
      'travel_v1.png',
      'fasting_v1.png',
      'high_sodium_meal_v1.png',
      'hard_workout_v1.png',
      'psychological_stress_v1.png',
      'illness_symptoms_v1.png',
      'medication_v1.png',
      'less_water_v1.png',
      'more_water_v1.png',
      'constipation_v1.png',
      'nothing_notable_v1.png',
      'other_v1.png',
    ]) {
      expect(inputSections, contains('assets/images/daily_context/$asset'));
      expect(File('assets/images/daily_context/$asset').existsSync(), isTrue);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/images/daily_context/'));
  });
}
