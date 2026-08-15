@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('root dashboard build has no unused theme locals', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    final rootBuildStart = benchmark.indexOf(
      'Widget build(BuildContext context) {',
    );
    final primaryInsightsStart = benchmark.indexOf(
      'final primaryInsightsPage =',
      rootBuildStart,
    );

    expect(rootBuildStart, greaterThanOrEqualTo(0));
    expect(primaryInsightsStart, greaterThan(rootBuildStart));

    final rootBuildPrefix = benchmark.substring(
      rootBuildStart,
      primaryInsightsStart,
    );

    expect(
      rootBuildPrefix,
      isNot(contains('final scheme = Theme.of(context).colorScheme;')),
    );
    expect(
      rootBuildPrefix,
      isNot(
        contains(
          'final dark = Theme.of(context).brightness == Brightness.dark;',
        ),
      ),
    );
  });

  test('duplicate sections remain removed and carousel content remains', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(
      benchmark,
      isNot(contains("key: const Key('dashboard-key-insights-deck')")),
    );
    expect(
      benchmark,
      isNot(contains("key: const Key('dashboard-mobile-insights-slot')")),
    );
    expect(
      benchmark,
      isNot(contains("key: const Key('dashboard-tablet-insights-slot')")),
    );

    expect(benchmark, contains('summary: progressSection!'));
    expect(benchmark, contains('insights: primaryInsightsPage'));
    expect(benchmark, contains('pages: insightCards'));
    expect(benchmark, contains('final dayAndProgress = daily;'));
  });
}
