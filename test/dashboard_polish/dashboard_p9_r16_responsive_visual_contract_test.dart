import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R16 responsive visual contract is present', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final watch = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_shell.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/analytics/analytics_page.dart',
    ).readAsStringSync();

    expect(grid, isNot(contains("'kcal/day'")));
    expect(grid, contains("'kcal'"));
    expect(grid, contains('final columns = wideScreen && constraints.maxWidth >= 760'));
    expect(grid, contains('if (constraints.maxWidth < 760)'));
    expect(grid, contains('constraints.maxWidth >= 1040 ? 3 : 2'));
    expect(grid, contains('FittedBox('));
    expect(watch, contains('top: 38'));
    expect(shell, contains('constraints.maxWidth < 600 ? 176 : 132'));
    expect(analytics, contains('textDirection: TextDirection.ltr'));
  });
}
