import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R9 live Health Hub and paired deck contracts are present', () {
    final health = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(health, contains("Key('health-hub-fixed-square-watch')"));
    expect(health, contains('SizedBox.square'));
    expect(health, contains("Key('bil-live-health-watch')"));
    expect(health, contains('Timer.periodic(const Duration(seconds: 1)'));
    expect(health, contains('StackFit.expand'));
    expect(health, contains("Text(tr('Connect now', 'ربط الآن'))"));

    expect(shell, contains("Key('dashboard-twin-header-slot')"));
    expect(shell, contains("Key('dashboard-twin-deck-carousel')"));
    expect(shell, contains('viewportFraction: compact ? .94 : .96'));

    expect(grid, contains('DashboardAnalyticsCenter('));
    expect(grid, contains('bodyTwinSummary: trustedTwinSummary'));
    expect(benchmark, contains("Key('dashboard-mobile-body-twin-snapshot')"));
    expect(shell, contains('final headerBaseHeight = compact ? 68.0 : 72.0'));
  });
}
