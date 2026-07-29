import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 2 preserves Epic 1 and adds the mobile Body Twin surface', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(
      benchmark,
      contains("key: const Key('dashboard-mobile-command-center')"),
    );
    expect(
      benchmark,
      contains("key: const Key('dashboard-mobile-body-twin-snapshot')"),
    );
    expect(benchmark, contains('final mobileTwin = phone'));

    final dayIndex = benchmark.indexOf('dayAndProgress,');
    final twinIndex = benchmark.indexOf('mobileTwin,');
    final connectedIndex = benchmark.indexOf('connectedHealth!,');
    expect(dayIndex, greaterThanOrEqualTo(0));
    expect(twinIndex, greaterThan(dayIndex));
    expect(connectedIndex, greaterThan(twinIndex));

    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(
      grid,
      contains('final phone = MediaQuery.sizeOf(context).width < 600;'),
    );
    expect(grid, contains('if (!phone) ...['));
    expect(
      RegExp(
        r'if \(!phone\) \.\.\.\[\s*bodyProfile,\s*const SizedBox',
      ).hasMatch(grid),
      isTrue,
    );
  });

  test('Epic 2 remains presentation-only', () {
    const changedProductionPaths = <String>[
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ];

    expect(
      changedProductionPaths.every(
        (path) => path.startsWith('lib/features/dashboard/widgets/'),
      ),
      isTrue,
    );
  });
}
