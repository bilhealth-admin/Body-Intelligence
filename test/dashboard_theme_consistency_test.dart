import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today progress uses the explicit dashboard contrast component', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, contains('_DashboardSectionHeading('));
    expect(source, contains("title: tr('Today progress', 'تقدم اليوم')"));
    expect(source, contains("key: const Key('dashboard-today-summary-title')"));
    expect(
      source,
      contains("key: const Key('dashboard-today-summary-subtitle')"),
    );
  });

  test('dashboard section heading has explicit readable foreground colors', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, contains('color: const Color(0xFFF4F8FB)'));
    expect(source, contains('color: const Color(0xFFCAE0E8)'));
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
