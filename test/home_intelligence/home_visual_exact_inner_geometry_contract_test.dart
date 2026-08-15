@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current nested decks use compact Bio Intelligence geometry', () {
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
    expect(summary, contains('viewportFraction: .94'));
    expect(benchmark, contains("Key('dashboard-action-inner-carousel')"));
    expect(benchmark, contains("Key('dashboard-insights-inner-carousel')"));
    expect(benchmark, contains('viewportFraction: .94'));
  });
}
