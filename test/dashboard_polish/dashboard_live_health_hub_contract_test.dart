import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9 live Health Hub and layout contracts are present', () {
    final health = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/analytics/analytics_page.dart',
    ).readAsStringSync();
    final chart = File(
      'lib/shared/widgets/premium_chart_card.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(health, contains("Timer.periodic(const Duration(seconds: 1)"));
    expect(health, contains("DateTime.now()"));
    expect(health, contains("key: const Key('bil-live-health-watch')"));
    expect(health, contains("_value('heartRate')"));
    expect(health, contains("_value('steps')"));
    expect(health, contains("_value('activeEnergy')"));
    expect(health, contains("_value('sleep', decimals: 1)"));
    expect(health, contains("tr('Connect now', 'ربط الآن')"));
    expect(health, isNot(contains('bil_health_hub_watch.webp')));
    expect(pubspec, isNot(contains('bil_health_hub_watch.webp')));

    expect(benchmark, contains('IntrinsicHeight('));
    expect(
      benchmark,
      contains('crossAxisAlignment: CrossAxisAlignment.stretch'),
    );
    expect(grid, contains('? 126.0'));
    expect(grid, contains('maxLines: 2'));
    expect(grid, contains('overflow: TextOverflow.visible'));
    expect(analytics, contains('textAlign: rtl ? TextAlign.right'));
    expect(chart, contains('textAlign: rtl ? TextAlign.right'));
  });
}
