import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_library_source.dart';

void main() {
  test('Insights owns analytics cards without duplicating them on Today', () {
    final analytics = readDartLibrarySource(
      'lib/features/analytics/analytics_page.dart',
    );
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
    expect(dashboard, isNot(contains('AnalyticsWeightJourneyCard(')));
    expect(dashboard, isNot(contains('AnalyticsWeeklyProgressCard(')));
    expect(dashboard, contains("context.go('/analytics')"));
    expect(dashboard, isNot(contains('WeightTrendChart(')));
    expect(
      RegExp(r'^\s*WeeklyProgressCard\(', multiLine: true).hasMatch(dashboard),
      isFalse,
    );
    expect(dashboard, isNot(contains('_AnalyticsCarouselSection')));
  });
}
