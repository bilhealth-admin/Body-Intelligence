import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 3 keeps one authoritative visible decision surface', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(grid, isNot(contains('Visibility(')));
    expect(grid, isNot(contains('DashboardDetailPanel(')));
    expect(grid, isNot(contains('DashboardWaterCard(')));
    expect(grid, isNot(contains('DashboardMealsTimeline(')));
    expect(grid, isNot(contains('decisionMemoryRepositoryProvider')));
    expect(benchmark, contains('dashboard-truth-explanation-surface'));
    expect(benchmark, contains('dashboard-decision-feedback'));
    expect(benchmark, contains('dashboard-mobile-command-center'));

    expect(grid, isNot(contains('class DecisionMemoryRepository')));
    expect(benchmark, isNot(contains('decisionMemoryRepositoryProvider')));
  });
}
