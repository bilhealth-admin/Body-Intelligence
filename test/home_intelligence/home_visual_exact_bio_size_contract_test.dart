@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'top carousel uses Bio Intelligence shell dimensions without clipping',
    () {
      final primary = File(
        'lib/features/dashboard/widgets/dashboard_primary_carousel.dart',
      ).readAsStringSync();

      expect(primary, contains('DashboardTwinDeckShell('));
      expect(primary, contains('twinBaseHeight(width)'));
      expect(primary, contains('maximumTwinHeight'));
      expect(primary, contains('return DashboardCarousel('));
      expect(primary, isNot(contains("return SizedBox(")));
      expect(primary, isNot(contains('height: 500')));
      expect(primary, isNot(contains('height: 470')));
    },
  );

  test('summary and insights expose real first-page content directly', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(
      summary,
      contains('pages.isEmpty ? const SizedBox.shrink() : pages.first'),
    );
    expect(
      benchmark,
      contains('pages.isEmpty ? const SizedBox.shrink() : pages.first'),
    );
    expect(benchmark, isNot(contains('class _PrimaryActionPage')));
    expect(benchmark, contains('DashboardCompactInsightCard('));
  });

  test('all original dashboard sections remain present', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(benchmark, contains('phonePrimaryCarousel'));
    expect(benchmark, contains('top,'));
    expect(benchmark, contains('dayAndProgress,'));
    expect(benchmark, contains('mobileTwin'));
    expect(benchmark, contains('connectedHealth'));
  });
}
