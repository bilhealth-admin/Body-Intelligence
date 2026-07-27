import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dashboard and Insights share analytics production cards', () {
    final analytics = File(
      'lib/features/analytics/analytics_page.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(
      'class AnalyticsWeightJourneyCard'.allMatches(analytics),
      hasLength(1),
    );
    expect(
      'class AnalyticsWeeklyProgressCard'.allMatches(analytics),
      hasLength(1),
    );
    expect('AnalyticsWeightJourneyCard('.allMatches(analytics), hasLength(2));
    expect('AnalyticsWeeklyProgressCard('.allMatches(analytics), hasLength(2));
    expect(dashboard, contains('AnalyticsWeightJourneyCard('));
    expect(dashboard, contains('AnalyticsWeeklyProgressCard('));
    expect(dashboard, isNot(contains('WeightTrendChart(')));
    expect(
      RegExp(
        r'^\s*WeeklyProgressCard\(',
        multiLine: true,
      ).hasMatch(dashboard),
      isFalse,
    );
    expect(dashboard, isNot(contains('_AnalyticsCarouselSection')));
  });
}
