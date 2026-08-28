import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String analyticsSource() => [
    'lib/features/analytics/nutrition_analytics_page.dart',
    'lib/features/analytics/nutrition_analytics_food.dart',
    'lib/features/analytics/nutrition_analytics_totals.dart',
    'lib/features/analytics/nutrition_analytics_calories.dart',
    'lib/features/analytics/nutrition_analytics_nutrients.dart',
    'lib/features/analytics/nutrition_analytics_macros.dart',
    'lib/features/analytics/nutrition_analytics_components.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');

  test('nutrition analytics is routed without replacing food search', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final analytics = File(
      'lib/features/analytics/analytics_page.dart',
    ).readAsStringSync();
    expect(router, contains("path: '/analytics/nutrition'"));
    expect(router, contains('NutritionAnalyticsPage('));
    expect(router, contains("'nutrients' => 1"));
    expect(router, contains('const FoodPage()'));
    expect(analytics, contains("Key('open-nutrition-analytics')"));
  });

  test('nutrition analytics uses live meal and stored plan providers', () {
    final source = analyticsSource();
    for (final contract in const [
      'dailyMealsProvider',
      'userProfileProvider',
      'activeGoalProvider',
      'planSettingProvider',
      'NutritionAnalyticsTotals.fromMeals',
      "Key('nutrition-calories-tab')",
      "Key('nutrition-nutrients-tab')",
      "Key('nutrition-macros-tab')",
      'NutrientEvidenceMask.contains',
      'selectedLogDateProvider',
      'Directionality.of(context) == TextDirection.rtl',
      "context.push('/settings/local-export?from=\$iso&to=\$iso')",
      "_t(context, 'No foods logged for this day.')",
    ]) {
      expect(source, contains(contract));
    }
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale':"));
    }
  });

  test('general references never become personal goal or left values', () {
    final source = analyticsSource();
    expect(source, contains("TrackedNutrient.sodium, null, 'mg'"));
    expect(source, contains("TrackedNutrient.potassium, null, 'mg'"));
    expect(source, contains("TrackedNutrient.calcium, null, 'mg'"));
    expect(source, contains("TrackedNutrient.magnesium, null, 'mg'"));
    expect(source, contains("TrackedNutrient.phosphorus, null, 'mg'"));
    expect(source, isNot(contains('targets.sodium')));
    expect(source, isNot(contains('targets.potassium')));
    expect(source, isNot(contains('targets.calcium')));
    expect(source, isNot(contains("storedGoal('goal.carbsPercent') ?? 0")));
    expect(source, contains('carbsPercent == null'));
    expect(source, contains('const _NutritionTargets({'));
    expect(source, isNot(contains('this.calories = 0')));
  });

  test('selected-day export is wired through route into range page', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final page = File(
      'lib/features/settings/local_export_range_page.dart',
    ).readAsStringSync();
    expect(router, contains("initialFrom: parse('from')"));
    expect(router, contains("initialTo: parse('to')"));
    expect(page, contains('exportCsvFiles(from: from, to: to)'));
    expect(page, contains('DateUtils.dateOnly(widget.initialFrom!)'));
    expect(page, contains('DateUtils.dateOnly(widget.initialTo!)'));
  });
}
