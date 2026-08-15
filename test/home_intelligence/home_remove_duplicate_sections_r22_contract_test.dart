@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R21 cleanup leaves no unused import or root content color', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(
      benchmark,
      isNot(contains("import 'dashboard_twin_deck_shell.dart';")),
    );
    expect(
      benchmark,
      isNot(
        contains(
          'final contentColor = dark ? scheme.onSurface : const Color(0xFF061A2B);',
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
