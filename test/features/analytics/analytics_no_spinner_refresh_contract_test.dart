import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics keeps cached data visible while providers refresh', () {
    final nutrition = File(
      'lib/features/analytics/nutrition_analytics_page.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/analytics/analytics_page.dart',
    ).readAsStringSync();
    final weekly = File(
      'lib/features/analytics/weekly_report_page.dart',
    ).readAsStringSync();

    expect(
      analytics,
      contains('weightsAsync.isLoading && !weightsAsync.hasValue'),
    );
    expect(analytics, contains('mealsAsync.isLoading && !mealsAsync.hasValue'));
    expect(analytics, contains('waterAsync.isLoading && !waterAsync.hasValue'));
    expect(
      analytics,
      contains('dailyLogsAsync.isLoading && !dailyLogsAsync.hasValue'),
    );
    expect(
      analytics,
      contains('contextsAsync.isLoading && !contextsAsync.hasValue'),
    );
    expect(
      nutrition,
      contains('profileState.isLoading && !profileState.hasValue'),
    );
    expect(nutrition, contains('goalState.isLoading && !goalState.hasValue'));
    expect(
      nutrition,
      contains('presetState.isLoading && !presetState.hasValue'),
    );
    expect(nutrition, contains('state.isLoading && !state.hasValue'));
    expect(nutrition, contains('planState.isLoading && !planState.hasValue'));
    expect(
      nutrition,
      contains('_NutritionAnalyticsLoadingShell(initialTab: initialTab)'),
    );
    expect(
      nutrition,
      isNot(
        contains(
          'return const Scaffold(body: Center(child: CircularProgressIndicator()));',
        ),
      ),
    );
    expect(
      RegExp('skipLoadingOnRefresh: true').allMatches(nutrition),
      hasLength(1),
    );
    expect(
      RegExp('skipLoadingOnReload: true').allMatches(nutrition),
      hasLength(1),
    );
    expect(weekly, contains('skipLoadingOnRefresh: true'));
    expect(weekly, contains('skipLoadingOnReload: true'));
  });
}
