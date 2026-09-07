import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 1 keeps owner-retired dashboard cards out of the sequence', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();

    expect(source, contains("Key('dashboard-ai-coach-slot')"));
    expect(source, contains("Key('dashboard-daily-intelligence-slot')"));
    expect(source, isNot(contains("Key('dashboard-personal-health-ai-slot')")));
    expect(source, isNot(contains("Key('dashboard-mobile-summary-card')")));
    expect(
      source.indexOf("Key('dashboard-ai-coach-slot')"),
      lessThan(source.indexOf("Key('dashboard-daily-intelligence-slot')")),
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
