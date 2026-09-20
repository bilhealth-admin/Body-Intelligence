import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('DashboardGrid is an orchestration boundary, not an engine owner', () {
    final grid = source('lib/features/dashboard/widgets/dashboard_grid.dart');

    expect(grid, contains('DashboardIntelligenceInputAdapter().adapt('));
    expect(grid, contains('DashboardIntelligenceComposer().compose('));
    expect(grid, contains('DashboardIntelligenceLocalizer('));
    expect(grid, contains('.forLocale('));
    expect(grid, contains('DashboardHydrationCommand('));

    expect(grid, isNot(contains('OneBestActionEngine.choose(')));
    expect(grid, isNot(contains('NutrientEvidenceEngine.total(')));
    expect(grid, isNot(contains('BodyCompositionEngine.calculate(')));
    expect(grid, isNot(contains('mealRepositoryProvider')));
    expect(grid, isNot(contains('decisionMemoryRepositoryProvider')));
  });

  test('DashboardGrid delegates every extracted presentation boundary', () {
    final grid = source('lib/features/dashboard/widgets/dashboard_grid.dart');

    for (final boundary in const [
      'PremiumDashboardBenchmark(',
      'DashboardSummaryFactory.build(',
    ]) {
      expect(grid, contains(boundary), reason: 'Missing boundary: $boundary');
    }

    expect(grid, isNot(contains('DashboardBodyProfileSnapshot(')));
    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
    expect(grid, contains("context.go('/analytics')"));

    expect(grid, isNot(contains('Visibility(')));
    expect(grid, isNot(contains('DashboardWaterCard(')));
    expect(grid, isNot(contains('DashboardMealsTimeline(')));
    expect(grid, isNot(contains('DashboardDetailPanel(')));
  });

  test('all approved Dashboard boundary modules remain present', () {
    const paths = [
      'lib/features/dashboard/composition/dashboard_intelligence_input_adapter.dart',
      'lib/features/dashboard/composition/dashboard_command_coordinator.dart',
      'lib/features/dashboard/domain/dashboard_decision_authority.dart',
      'lib/features/dashboard/presentation/dashboard_intelligence_localizer.dart',
      'lib/features/dashboard/presentation/dashboard_body_twin_copy.dart',
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
      'lib/features/dashboard/widgets/dashboard_profile_required_card.dart',
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
      'lib/features/dashboard/widgets/dashboard_nutrition_details.dart',
      'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
      'docs/architecture/BIL_DASHBOARD_HIDDEN_SURFACE_RETIREMENT.md',
    ];

    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: 'Missing module: $path');
    }
  });

  test('DashboardGrid remains below the shared architecture ceiling', () {
    final lines = source(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).split('\n').length;

    expect(lines, lessThan(700));
  });
}
