import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current dashboard avoids legacy nested deck geometry', () {
    final primary = File(
      'lib/features/dashboard/widgets/dashboard_primary_carousel.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(primary, contains('compact: true'));
    expect(summary, isNot(contains('viewportFraction: .94')));
    expect(
      benchmark,
      isNot(contains("Key('dashboard-action-inner-carousel')")),
    );
    expect(
      benchmark,
      isNot(contains("Key('dashboard-insights-inner-carousel')")),
    );
    expect(benchmark, isNot(contains('viewportFraction: .94')));
  });
}
