import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dashboard presentation cannot bypass the trusted Body Twin status', () {
    final composer = File(
      'lib/features/dashboard/domain/dashboard_intelligence_composer.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final copy = File(
      'lib/features/dashboard/presentation/dashboard_body_twin_copy.dart',
    ).readAsStringSync();

    expect(composer, contains('_bodyTwinAdapter.build('));
    expect(composer, contains('trustedBodyTwin: trustedBodyTwin'));
    expect(grid, contains('dashboardSnapshot.trustedBodyTwin'));
    expect(grid, contains('trustedTwin.canExposeBodyTwin'));
    expect(copy, contains('DashboardBodyTwinTrustStatus.stale'));
    expect(copy, contains('DashboardBodyTwinTrustStatus.inconsistent'));
    expect(copy, contains('DashboardBodyTwinTrustStatus.unavailable'));
  });
}
