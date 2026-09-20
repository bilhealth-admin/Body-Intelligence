import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R16 responsive visual contract is present', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
    ).readAsStringSync();
    final daily = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
    ).readAsStringSync();
    final composition = File(
      'lib/features/dashboard/composition/dashboard_composition.dart',
    ).readAsStringSync();

    expect(grid, isNot(contains("'kcal/day'")));
    expect(summary, contains("'kcal'"));
    expect(summary, contains('DashboardDailySummarySection('));
    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
    expect(grid, contains("context.go('/analytics')"));
    expect(daily, contains('DashboardComposition.pagedSection('));
    expect(analytics, contains('DashboardComposition.analytics('));
    expect(analytics, contains('textDirection: TextDirection.ltr'));
    expect(composition, contains('class DashboardComposition'));
  });
}
