import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition empty state opens canonical food log and fixed arrows', () {
    final page = File(
      'lib/features/analytics/nutrition_analytics_page.dart',
    ).readAsStringSync();
    final components = File(
      'lib/features/analytics/nutrition_analytics_components.dart',
    ).readAsStringSync();

    expect(page, contains("Key('nutrition-empty-log-food')"));
    expect(page, contains('Navigator.of(context).push<void>('));
    expect(page, contains('FoodLogPage(preferNavigatorPop: true)'));
    expect(
      page,
      contains("name: '/daily-log?foodLog=1&from=/analytics/nutrition'"),
    );
    expect(components, contains('Icons.chevron_left_rounded'));
    expect(components, contains('Icons.chevron_right_rounded'));
    expect(components, contains('textDirection: TextDirection.ltr'));
    expect(
      components,
      contains('Directionality.of(context) == TextDirection.rtl'),
    );
  });

  test('recipe library route does not expose dashboard during transition', () {
    final routes = File(
      'lib/app/router/app_wellness_routes.dart',
    ).readAsStringSync();

    expect(routes, contains("path: '/wellness/recipes'"));
    expect(routes, contains('pageBuilder: (_, state) => NoTransitionPage('));
  });

  test('AI Coach entry owns a timed welcome surface', () {
    final page = [
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
      'lib/features/intelligence_center/presentation/intelligence_center_widgets.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(page, contains('Duration(milliseconds: 2200)'));
    expect(page, contains("'Welcome to AI Coach'"));
    expect(page, contains('strokeCap: StrokeCap.round'));
  });
}
