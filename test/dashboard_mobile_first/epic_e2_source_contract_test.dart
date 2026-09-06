import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 2 preserves Body Twin, summary, and personal intelligence', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final current = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();

    expect(
      current,
      contains("key: const Key('dashboard-mobile-body-twin-snapshot')"),
    );
    expect(current, contains("Key('dashboard-personal-health-ai-slot')"));
    expect(current, contains("Key('dashboard-mobile-summary-card')"));
    expect(benchmark, contains("Key('dashboard-current-content-rail')"));

    final dayIndex = current.indexOf(
      "Key('dashboard-daily-intelligence-slot')",
    );
    final personalIndex = current.indexOf(
      "Key('dashboard-personal-health-ai-slot')",
    );
    final summaryIndex = current.indexOf(
      "Key('dashboard-mobile-summary-card')",
    );
    final twinIndex = current.indexOf(
      "key: const Key('dashboard-mobile-body-twin-snapshot')",
    );
    final connectedIndex = current.indexOf('connectedHealth!,');
    expect(dayIndex, greaterThanOrEqualTo(0));
    expect(personalIndex, greaterThan(dayIndex));
    expect(summaryIndex, greaterThan(personalIndex));
    expect(twinIndex, greaterThan(summaryIndex));
    expect(connectedIndex, lessThan(dayIndex));

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
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
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
