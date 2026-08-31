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

    final summary = page.indexOf("Key('daily-log-today-summary')");
    final copyAction = page.indexOf("Key('daily-log-copy-previous-day')");
    final adSlot = page.indexOf("Key('daily-log-free-ad-slot')", copyAction);
    final meals = page.indexOf('DailyMealsList(', summary);
    final water = page.indexOf('DailyWaterShortcut(', meals);
    final exercise = page.indexOf('DailyExerciseSection(', water);
    final bodyContext = page.indexOf(
      "Key('daily-log-body-context-link')",
      exercise,
    );

    expect(summary, greaterThan(0));
    expect(copyAction, greaterThan(summary));
    expect(adSlot, greaterThan(copyAction));
    expect(meals, greaterThan(adSlot));
    expect(meals, greaterThan(copyAction));
    expect(water, greaterThan(meals));
    expect(exercise, greaterThan(water));
    expect(bodyContext, greaterThan(exercise));
    expect(page, isNot(contains('DailyBodyContextSection(')));
    expect(bodyContextPage, contains('DailyBodyContextSection('));
    expect(bodyContextPage, contains('saveBodyContext('));
    expect(page, isNot(contains('DailyWaterSection(')));
    expect(page, contains('surface: SafeFreeAdSurface.dailyLog'));
    expect(page, isNot(contains('AdPlacement.dailyLog')));
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

  test('meal slots match the reference cards and always cover four meals', () {
    final meals = <String>[
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
      'lib/features/daily_log/presentation/daily_log_meal_detail_items.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    for (final type in const ['breakfast', 'lunch', 'dinner', 'snack']) {
      expect(meals, contains("'$type':"));
    }
    expect(meals, contains("Key('daily-meal-card-\${slot.type}')"));
    expect(meals, contains("Key('daily-meal-log-\$type')"));
    expect(meals, contains("'logFood': 'Plan meal'"));
    expect(meals, contains("'logMore': 'Open meal'"));
    expect(meals, isNot(contains("'logFood': 'Log food'")));
    expect(meals, isNot(contains("'logMore': 'Log more'")));
    expect(meals, contains('BorderRadius.circular(24)'));
    expect(meals, contains('FilledButton.tonal'));
    expect(meals, isNot(contains('Colors.orange')));
    expect(meals, isNot(contains('Colors.purple')));
    expect(meals, isNot(contains('Colors.green')));
  });

  test('food search and selected-food detail match reference states', () {
    final entry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();
    final search = File(
      'lib/features/daily_log/daily_log_meal_search.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();

    expect(
      search,
      isNot(contains('_mealBrowseCollections(')),
      reason: 'Food search stays empty until the user types a query.',
    );
    expect(entry, contains("Key('daily-log-selected-food-details')"));
    expect(page, contains("Key('daily-log-focused-food-detail')"));
    expect(entry, contains("Key('daily-log-food-premium-group')"));
    expect(entry, isNot(contains("Key('daily-log-food-macros-glass')")));
    expect(entry, isNot(contains("Key('daily-log-nutrition-facts-glass')")));
    expect(
      entry.indexOf('DailyLogCalorieMacroRing('),
      lessThan(entry.indexOf("Key('daily-log-food-premium-group')")),
      reason:
          'Calories stay visible while macros and detailed nutrients share one Premium group.',
    );
    expect(page, contains('if (selectedFood != null)'));
    expect(
      page,
      contains('if (mealSearchActive || widget.focusMealEntry)'),
      reason:
          'Android back must close the focused meal flow before leaving Diary.',
    );
    expect(page, contains('_leaveMealDetail();'));
    expect(entry, contains("Key('daily-log-nutrition-facts')"));
    expect(entry, contains('DailyLogCalorieMacroRing('));
    expect(entry, contains("Key('daily-log-meal-type-field')"));
    expect(entry, contains("_mealCopy('servingSize')"));
    expect(entry, isNot(contains("_mealCopy('servings')")));
    expect(entry, isNot(contains("_mealCopy('time')")));
    expect(entry, contains("Key('daily-log-serving-amount-field')"));
    expect(entry, contains("Key('daily-log-serving-unit-field')"));
    expect(
      entry,
      isNot(contains("_mealCopy('barcodeScan')")),
      reason: 'The focused meal page must not repeat global capture tools.',
    );
    expect(entry, isNot(contains("_mealCopy('voiceLog')")));
    expect(entry, isNot(contains("_mealCopy('mealScan')")));
    expect(entry, isNot(contains("_mealCopy('quickAdd')")));
    expect(search, isNot(contains('_foodMacroSummary')));
    expect(search, isNot(contains('verifiedSource :')));
  });

  test('diary hierarchy keeps nutrition detail out of meal rows', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final meals = <String>[
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
      'lib/features/daily_log/presentation/daily_log_meal_detail_items.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final search = File(
      'lib/features/daily_log/daily_log_meal_search.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();

    final rowStart = meals.indexOf('class _DiaryFoodRow');
    final rowEnd = meals.indexOf('class _DiaryEmptyMeals', rowStart);
    expect(rowStart, greaterThanOrEqualTo(0));
    expect(rowEnd, greaterThan(rowStart));
    final row = meals.substring(rowStart, rowEnd);

    expect(search, isNot(contains('TabBar(')));
    expect(search, isNot(contains('TabBarView(')));
    expect(search, isNot(contains('_searchTab(')));
    expect('$search\n$detail', isNot(contains("'myMeals'")));
    expect('$search\n$detail', isNot(contains("'myRecipes'")));
    expect('$search\n$detail', isNot(contains("'myFoods'")));
    expect('$search\n$detail', isNot(contains("'all'")));

    expect(meals, contains("Key('daily-meal-macros-\$type')"));
    expect(meals, contains("Key('daily-food-row-\${item.id}')"));
    expect(row, contains('item.calories.round().toString()'));
    expect(row, contains('FoodPresentationLocalizer.servingText('));
    expect(row, isNot(contains('item.protein')));
    expect(row, isNot(contains('item.carbs')));
    expect(row, isNot(contains('item.fats')));
    expect(row, isNot(contains('NutrientMetric(')));

    expect(detail, contains("Key('daily-log-nutrition-facts')"));
    expect(page, isNot(contains("Key('daily-log-nutrition-facts')")));
    expect(meals, isNot(contains("Key('daily-log-nutrition-facts')")));
    expect(search, isNot(contains("Key('daily-log-nutrition-facts')")));
  });

  test('water editor is isolated behind the dedicated diary route', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final water = File(
      'lib/features/daily_log/daily_water_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(page, contains('DailyWaterShortcut('));
    expect(page, isNot(contains('DailyWaterSection(')));
    expect(page, contains("'/daily-log/water?from="));
    expect(water, contains("Key('daily-water-page')"));
    expect(water, contains('DailyWaterSection('));
    expect(router, contains("path: '/daily-log/water'"));
    expect(router, contains('DailyWaterPage('));
  });
}
