import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary pages contain no nested moving carousel', () {
    final summary = [
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      'lib/features/dashboard/widgets/dashboard_metric_grid.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final benchmark = [
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/premium_dashboard_command_center.dart',
      'lib/features/dashboard/widgets/premium_dashboard_evidence.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(
      summary,
      contains("Key('dashboard-summary-static-body-twin-content')"),
    );
    expect(
      benchmark,
      contains("Key('dashboard-action-static-body-twin-content')"),
    );
    expect(
      benchmark,
      contains("Key('dashboard-insights-static-body-twin-content')"),
    );

    expect(summary, isNot(contains("Key('dashboard-summary-inner-carousel')")));
    expect(
      benchmark,
      isNot(contains("Key('dashboard-action-inner-carousel')")),
    );
    expect(
      benchmark,
      isNot(contains("Key('dashboard-insights-inner-carousel')")),
    );
  });

  test('summary uses static Body Twin evidence-style rows', () {
    final summary = [
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      'lib/features/dashboard/widgets/dashboard_metric_grid.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(summary, contains("Key('dashboard-summary-static-metric-rows')"));
    expect(summary, contains('class _EmbeddedMetricRow'));
    expect(summary, contains('surfaceContainerHighest.withValues(alpha: .42)'));
    expect(summary, contains('PremiumDesignTokens.radiusMd'));
  });

  test('action and insights content has no nested card surface', () {
    final compactInsight = File(
      'lib/features/dashboard/widgets/dashboard_compact_insight_card.dart',
    ).readAsStringSync();

    expect(compactInsight, contains('return InkWell('));
    expect(compactInsight, contains('child: Padding('));
    expect(compactInsight, isNot(contains('return PremiumSurface(')));
  });
}
