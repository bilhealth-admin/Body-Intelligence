import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _normalized(String source) =>
    source.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  test('dashboard spacing remains presentation-only and responsive', () {
    const productionFiles = <String>[
      'lib/features/dashboard/widgets/dashboard_layout_metrics.dart',
      'lib/features/dashboard/widgets/dashboard_experience_frame.dart',
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/daily_return_card.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ];

    final metrics = _normalized(File(productionFiles[0]).readAsStringSync());
    final frame = _normalized(File(productionFiles[1]).readAsStringSync());
    final benchmark = _normalized(File(productionFiles[2]).readAsStringSync());
    final daily = _normalized(File(productionFiles[3]).readAsStringSync());
    final grid = _normalized(File(productionFiles[4]).readAsStringSync());

    expect(metrics, contains('regionGap: 16'));
    expect(metrics, contains('regionGap: 18'));
    expect(metrics, contains('regionGap: 20'));
    expect(
      metrics,
      contains('regionGap: width >= ultraWideBreakpoint ? 22 : 20'),
    );
    expect(
      frame,
      contains(
        'final contentGap = compactVerticalRhythm ? 12.0 : PremiumDesignTokens.spaceMd',
      ),
    );
    expect(benchmark, contains('BilPremiumResponsiveLayout.sectionGap('));
    expect(benchmark, contains('SizedBox(height: sectionGap)'));
    expect(daily, contains('const SizedBox(height: 6)'));
    expect(grid, contains('PremiumDashboardBenchmark('));
    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));

    final spacingOnlySource = '$metrics\n$frame\n$daily';
    expect(spacingOnlySource, isNot(contains('Provider')));
    expect(spacingOnlySource, isNot(contains('Repository')));
    expect(spacingOnlySource, isNot(contains('Engine().')));
    expect(spacingOnlySource, isNot(contains('ref.watch(')));
    expect(spacingOnlySource, isNot(contains('ref.read(')));
  });
}
