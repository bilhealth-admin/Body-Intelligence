import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary outer cards retain Body Twin surface configuration', () {
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('level: PremiumSurfaceLevel.detail'));
    expect(shell, contains('dashboardGlass: true'));
  });

  test('summary outer surface retains Body Twin configuration', () {
    final summary = [
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      'lib/features/dashboard/widgets/dashboard_metric_grid.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(summary, contains('child: PremiumSurface('));
    expect(summary, contains('level: PremiumSurfaceLevel.detail'));
    expect(summary, contains('dashboardGlass: true'));
    expect(
      summary,
      isNot(
        contains('colorScheme.surfaceContainerHighest.withValues(alpha: .26)'),
      ),
    );
  });

  test(
    'action and insights are static content inside Body Twin outer surface',
    () {
      final benchmark = [
        'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
        'lib/features/dashboard/widgets/premium_dashboard_command_center.dart',
        'lib/features/dashboard/widgets/premium_dashboard_evidence.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final compactInsight = File(
        'lib/features/dashboard/widgets/dashboard_compact_insight_card.dart',
      ).readAsStringSync();

      expect(
        benchmark,
        contains("Key('dashboard-action-static-body-twin-content')"),
      );
      expect(
        benchmark,
        contains("Key('dashboard-insights-static-body-twin-content')"),
      );

      expect(compactInsight, contains('return InkWell('));
      expect(compactInsight, contains('child: Padding('));
      expect(compactInsight, isNot(contains('return PremiumSurface(')));
      expect(compactInsight, isNot(contains('LinearGradient(')));
      expect(compactInsight, isNot(contains('BoxShadow(')));
    },
  );
}
