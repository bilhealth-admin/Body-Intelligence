import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router exposes the typed decision explanation boundary', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final surface = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(router, contains("path: '/dashboard/decision-explanation'"));
    expect(router, contains('DashboardDecisionExplanationPage('));
    expect(router, contains('state.extra is DashboardDecisionExplanation'));
    expect(grid, contains('DashboardDecisionExplanation('));
    expect(
      grid,
      contains('DashboardTrustedTruthDecisionAdapter.engineVersion'),
    );
    expect(grid, contains("'/dashboard/decision-explanation'"));
    expect(surface, contains("Key('dashboard-explain-decision')"));
  });
}
