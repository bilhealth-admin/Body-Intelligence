import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R9 dashboard runtime layout uses bounded responsive surfaces', () {
    final health = <String>[
      'lib/features/connected_health/widgets/connected_health_card.dart',
      'lib/features/connected_health/widgets/health_hub_empty_state.dart',
      'lib/features/connected_health/widgets/live_health_watch.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final current = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
    ).readAsStringSync();

    expect(health, contains("Key('health-hub-fixed-square-watch')"));
    expect(health, contains('SizedBox.square'));
    expect(health, contains("Key('bil-live-health-watch')"));
    expect(benchmark, isNot(contains('IntrinsicHeight(')));
    expect(current, contains('height: height'));
    expect(current, contains("Key('dashboard-personal-health-ai-slot')"));
    expect(current, contains("Key('dashboard-mobile-summary-card')"));
    expect(current, contains('BilPremiumResponsiveLayout.twinBaseHeight('));
    expect(benchmark, contains('BoxConstraints(maxWidth: 840)'));
    expect(shell, contains('.clamp(0.0, constraints.maxHeight)'));
    expect(shell, contains('height: deckHeight'));
    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
    expect(grid, contains("context.go('/analytics')"));
    expect(summary, contains('DashboardDailySummarySection('));
  });
}
