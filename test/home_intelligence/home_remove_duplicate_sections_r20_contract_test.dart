@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standalone summary and insights are removed from dashboard flow', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(
      benchmark,
      isNot(contains("key: const Key('dashboard-mobile-insights-slot')")),
    );
    expect(
      benchmark,
      isNot(contains("key: const Key('dashboard-tablet-insights-slot')")),
    );
    expect(benchmark, contains('final dayAndProgress = daily;'));
    expect(
      benchmark,
      isNot(contains('progressSection!,\n                  ]')),
    );
  });

  test('summary and insights remain injected in primary carousel', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(benchmark, contains('final phonePrimaryCarousel ='));
    expect(benchmark, contains('summary: progressSection!'));
    expect(benchmark, contains('insights: primaryInsightsPage'));
    expect(benchmark, contains('pages: insightCards'));
  });

  test('personal health AI and daily intelligence remain visible', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(benchmark, contains("'dashboard-mobile-personal-ai-slot'"));
    expect(benchmark, contains("'dashboard-tablet-personal-ai-slot'"));
    expect(benchmark, contains('final dayAndProgress = daily;'));
    expect(benchmark, contains('child: dailyIntelligence'));
  });
}
