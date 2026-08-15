import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 1 exposes the approved mobile dashboard sequence', () {
    final source = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final mobileTwin = File(
      'lib/features/dashboard/widgets/dashboard_mobile_body_twin_snapshot.dart',
    ).readAsStringSync();

    expect(mobileTwin, contains("Key('dashboard-mobile-body-twin-snapshot')"));
    expect(source, contains("Key('dashboard-summary-and-bio-rail')"));
    expect(source, contains("Key('dashboard-mobile-summary-card')"));
    expect(
      source.indexOf('dayAndProgress,'),
      lessThan(source.indexOf('aiCoach!]')),
    );
    expect(
      source.indexOf('aiCoach!]'),
      lessThan(source.indexOf('connectedHealth!,')),
    );
    expect(
      source.indexOf('connectedHealth!,'),
      lessThan(source.indexOf('mobileTwin,')),
    );
  });

  test('Epic 1 remains presentation-only', () {
    final source = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'Repository',
      'Database',
      'SharedPreferences',
      'Drift',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });
}
