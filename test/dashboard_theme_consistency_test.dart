import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily summary uses the shared dashboard contrast component', () {
    final summaryFactory = File(
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
    ).readAsStringSync();
    final dailySummary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final heading = File(
      'lib/features/dashboard/widgets/dashboard_section_heading.dart',
    ).readAsStringSync();

    expect(dailySummary, contains('DashboardSectionHeading('));
    expect(
      summaryFactory,
      contains("title: tr('Daily Summary', 'ملخص اليوم')"),
    );
    expect(
      heading,
      contains("key: const Key('dashboard-today-summary-title')"),
    );
    expect(
      heading,
      contains("key: const Key('dashboard-today-summary-subtitle')"),
    );
  });

  test('dashboard section heading has explicit readable foreground colors', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_section_heading.dart',
    ).readAsStringSync();

    expect(source, contains('const Color(0xFFF4F8FB)'));
    expect(source, contains('const Color(0xFFCAE0E8)'));
    expect(source, contains('header: true'));
  });

  test(
    'dashboard production source contains no obvious dark hard-coded text',
    () {
      final source = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();

      const forbidden = <String>[
        'color: Colors.black',
        'color: Color(0xFF000000)',
        'foregroundColor: Colors.black',
      ];

      for (final value in forbidden) {
        expect(
          source,
          isNot(contains(value)),
          reason: 'Dark foreground found in dashboard source: $value',
        );
      }
    },
  );
}
