import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 2 preserves the Body Twin and paired summary rail', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final mobileTwin = File(
      'lib/features/dashboard/widgets/dashboard_mobile_body_twin_snapshot.dart',
    ).readAsStringSync();

    expect(
      mobileTwin,
      contains("key: const Key('dashboard-mobile-body-twin-snapshot')"),
    );
    expect(benchmark, contains('final mobileTwin = phone'));
    expect(benchmark, contains("Key('dashboard-summary-and-bio-rail')"));

    final dayIndex = benchmark.indexOf('dayAndProgress,');
    final twinIndex = benchmark.indexOf('mobileTwin,');
    final connectedIndex = benchmark.indexOf('connectedHealth!,');
    expect(dayIndex, greaterThanOrEqualTo(0));
    expect(twinIndex, greaterThan(dayIndex));
    expect(connectedIndex, greaterThan(dayIndex));
    expect(twinIndex, greaterThan(connectedIndex));

    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
    ).readAsStringSync();

    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
    expect(grid, contains("context.go('/analytics')"));
    expect(analytics, contains('final phone = layout.isPhone'));
    expect(analytics, contains('if (!phone) ...['));
    expect(
      RegExp(
        r'if \(!phone\) \.\.\.\[\s*bodyProfile,\s*const SizedBox',
      ).hasMatch(analytics),
      isTrue,
    );
  });

  test('Epic 2 remains presentation-only', () {
    const changedProductionPaths = <String>[
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/dashboard_mobile_body_twin_snapshot.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
      'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
    ];

    expect(
      changedProductionPaths.every(
        (path) => path.startsWith('lib/features/dashboard/widgets/'),
      ),
      isTrue,
    );
  });
}
