import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserved dashboard stays primary and AI Coach remains visible', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final more = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    expect(benchmark, contains('DashboardSectionIds.aiCoach'));
    expect(grid, contains('_UnprofiledReferenceDashboard'));
    expect(grid, contains('PremiumDashboardBenchmark('));
    expect(more, contains("'AI Coach',\n            '/intelligence-center'"));
  });
}
