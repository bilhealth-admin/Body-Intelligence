@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unused standalone insights deck is removed after R20', () {
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
  });

  test('primary carousel summary and insights remain preserved', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(benchmark, contains('summary: progressSection!'));
    expect(benchmark, contains('insights: primaryInsightsPage'));
    expect(benchmark, contains('pages: insightCards'));
    expect(benchmark, contains('final dayAndProgress = daily;'));
  });
}
