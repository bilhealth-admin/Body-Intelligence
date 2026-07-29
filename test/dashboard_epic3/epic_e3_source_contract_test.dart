import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 3 uses the existing decision-memory response path', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(grid, contains("respondToAction('accepted')"));
    expect(grid, contains("respondToAction('done')"));
    expect(grid, contains("respondToAction('notSuitable')"));
    expect(grid, contains('decisionMemoryRepositoryProvider'));
    expect(benchmark, contains('dashboard-truth-explanation-surface'));
    expect(benchmark, contains('dashboard-decision-feedback'));

    expect(grid, isNot(contains('class DecisionMemoryRepository')));
    expect(benchmark, isNot(contains('decisionMemoryRepositoryProvider')));
  });
}
