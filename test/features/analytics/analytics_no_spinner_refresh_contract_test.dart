import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics keeps cached data visible while providers refresh', () {
    final nutrition = File(
      'lib/features/analytics/nutrition_analytics_page.dart',
    ).readAsStringSync();
    final weekly = File(
      'lib/features/analytics/weekly_report_page.dart',
    ).readAsStringSync();

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
