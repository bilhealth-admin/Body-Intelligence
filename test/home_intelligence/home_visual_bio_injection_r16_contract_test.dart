@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outer cards retain phone Bio Intelligence compact geometry', () {
    final primary = File(
      'lib/features/dashboard/widgets/dashboard_primary_carousel.dart',
    ).readAsStringSync();

    expect(primary, contains('child: DashboardTwinDeckShell('));
    expect(primary, contains('compact: true'));
    expect(primary, contains('twinBaseHeight(width)'));
    expect(primary, contains('maximumTwinHeight'));
  });

  test('nested cards retain Bio Intelligence compact width', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(summary, contains("Key('dashboard-summary-inner-carousel')"));
    expect(summary, contains('viewportFraction: .94'));
    expect(benchmark, contains("Key('dashboard-action-inner-carousel')"));
    expect(benchmark, contains("Key('dashboard-insights-inner-carousel')"));
  });

  test('summary layout uses current R19 typography and spacing', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(summary, contains('childAspectRatio: phone ? .94'));
    expect(summary, contains('mainAxisSpacing: phone ? 18'));
    expect(summary, contains('fontSize: phone ? 10 : 13'));
    expect(summary, contains('fontSize: phone ? 8.5 : 11'));
  });
}
