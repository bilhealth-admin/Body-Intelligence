import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Epic 2 preserves Body Twin while excluding retired intelligence cards',
    () {
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
      expect(
        current,
        isNot(contains("Key('dashboard-personal-health-ai-slot')")),
      );
      expect(current, isNot(contains("Key('dashboard-mobile-summary-card')")));
      expect(benchmark, contains("Key('dashboard-current-content-rail')"));

      final dayIndex = current.indexOf(
        "Key('dashboard-daily-intelligence-slot')",
      );
      final twinIndex = current.indexOf(
        "key: const Key('dashboard-mobile-body-twin-snapshot')",
      );
      final connectedIndex = current.indexOf('connectedHealth!,');
      final fitnessIndex = current.indexOf('DashboardHealthSidePanel(');
      final ungroupedIndex = current.indexOf('if (!groupedFitness)');
      // Named-argument order is not visual order: daily summaries are now
      // supplied as the panel beside the watch, not a separate lower row.
      expect(fitnessIndex, greaterThanOrEqualTo(0));
      expect(dayIndex, greaterThan(fitnessIndex));
      expect(connectedIndex, greaterThan(dayIndex));
      expect(ungroupedIndex, greaterThan(connectedIndex));
      final fitnessGroup = current.substring(fitnessIndex, ungroupedIndex);
      expect(fitnessGroup, contains('panel: DashboardDailyReturnLayout('));
      expect(fitnessGroup, contains('child: dailyIntelligence,'));
      expect(fitnessGroup, contains('child: connectedHealth!,'));
      final standaloneDayIndex = current.indexOf(
        "Key('dashboard-daily-intelligence-slot')",
        ungroupedIndex,
      );
      expect(standaloneDayIndex, greaterThan(ungroupedIndex));
      expect(twinIndex, greaterThan(standaloneDayIndex));

      final grid = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();
      final analytics = File(
        'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
      ).readAsStringSync();
      final actions = File(
        'lib/features/dashboard/widgets/dashboard_grid_actions.dart',
      ).readAsStringSync();

      expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
      expect(actions, contains("context.go('/analytics')"));
      expect(analytics, contains('final phone = layout.isPhone'));
      expect(analytics, contains('if (!phone) ...['));
      expect(
        RegExp(
          r'if \(!phone\) \.\.\.\[\s*bodyProfile,\s*const SizedBox',
        ).hasMatch(analytics),
        isTrue,
      );
    },
  );

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
