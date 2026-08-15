import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard responsive surfaces remain delegated and bounded', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final summaryFactory = File(
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
    ).readAsStringSync();
    final daily = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
    ).readAsStringSync();

    expect(summaryFactory, contains('DashboardDailySummarySection('));
    expect(grid, isNot(contains('DashboardBodyProfileSnapshot(')));
    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
    expect(grid, contains("context.go('/analytics')"));
    expect(daily, contains('LayoutBuilder('));
    expect(profile, contains('LayoutBuilder('));
    expect(analytics, contains('LayoutBuilder('));
  });

  test('responsive package stays inside dashboard presentation', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('class TruthEngine')));
    expect(source, isNot(contains('class DecisionEngine')));
    expect(source, isNot(contains('SupabaseClient')));
  });
}
