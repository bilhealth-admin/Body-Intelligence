import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final plannerSource = [
    'meal_planner_page.dart',
    'meal_planner_persistence.dart',
  ]
      .map(
        (name) => File(
          'lib/features/meal_planner/presentation/$name',
        ).readAsStringSync(),
      )
      .join('\n');
  final copySource = File(
    'lib/features/meal_planner/presentation/meal_planner_copy.dart',
  ).readAsStringSync();
  final navigationSource = File(
    'lib/features/daily_log/daily_log_navigation_actions.dart',
  ).readAsStringSync();

  test('Review and log dispatches to a focused search, never auto-saves', () {
    final recipeFlowStart = plannerSource.indexOf('void _showRecipe');
    final recipeFlowEnd = plannerSource.indexOf('String _amount');
    expect(recipeFlowStart, greaterThanOrEqualTo(0));
    expect(recipeFlowEnd, greaterThan(recipeFlowStart));
    final recipeFlow = plannerSource.substring(recipeFlowStart, recipeFlowEnd);

    expect(recipeFlow, contains("'action': 'food'"));
    expect(recipeFlow, contains("'focus': 'meal'"));
    expect(recipeFlow, contains("'meal': recipe.meal.toLowerCase()"));
    expect(recipeFlow, contains("'query': recipe.title"));
    expect(recipeFlow, isNot(contains('mealRepositoryProvider')));
    expect(recipeFlow, isNot(contains('addMeal')));
    expect(navigationSource, contains("case 'food':"));
    expect(navigationSource, contains('_openFoodSearchAfterBuild()'));
    expect(navigationSource, contains('foodSearch.text = initialQuery'));
    expect(navigationSource, contains("widget.initialAction == 'food'"));
    expect(navigationSource, contains("context.go('/meal-planner')"));
  });

  test(
    'load and generation failures expose recovery without partial plan writes',
    () {
      expect(plannerSource, contains("_loadError = 'loadFailed'"));
      expect(plannerSource, contains("_saveError = 'generateFailed'"));
      expect(plannerSource, contains("if (_loadError != null)"));
      expect(plannerSource, contains("if (_saveError != null)"));
      expect(plannerSource, contains('repository.mutateIfUnchanged('));
      expect(plannerSource, contains('isCurrent: () => _isCurrent'));
      expect(plannerSource, contains('_readSnapshot == null'));
      expect(plannerSource, contains('remove: [_groceryChecksKey]'));
      expect(
        plannerSource,
        contains('A failed write leaves the previous saved week intact.'),
      );
    },
  );

  test(
    'planner tabs scroll and plan provenance is explicit in five locales',
    () {
      expect(plannerSource, contains('isScrollable: true'));
      expect(plannerSource, contains('tabAlignment: TabAlignment.start'));
      for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
        expect(copySource, contains("'$locale': {"), reason: locale);
      }
      for (final key in const [
        'sourceLabel',
        'sourceBody',
        'retry',
        'loadFailed',
        'generateFailed',
        'planChanged',
        'missingRecipe',
      ]) {
        expect(RegExp("'$key':").allMatches(copySource).length, 5, reason: key);
      }
      expect(copySource, contains('neither plan is automatically merged'));
      expect(copySource, contains('لا تُدمج الخطتان تلقائيًا'));
    },
  );
}
