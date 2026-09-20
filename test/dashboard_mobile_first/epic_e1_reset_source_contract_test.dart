import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Epic 1 exposes the approved mobile dashboard sequence', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();

    expect(source, contains("Key('dashboard-ai-coach-slot')"));
    expect(source, contains("Key('dashboard-daily-intelligence-slot')"));
    expect(source, contains("Key('dashboard-personal-health-ai-slot')"));
    expect(source, contains("Key('dashboard-mobile-summary-card')"));
    expect(
      source.indexOf("Key('dashboard-ai-coach-slot')"),
      lessThan(source.indexOf("Key('dashboard-daily-intelligence-slot')")),
    );
    expect(
      source.indexOf("Key('dashboard-daily-intelligence-slot')"),
      lessThan(source.indexOf("Key('dashboard-personal-health-ai-slot')")),
    );
    expect(
      source.indexOf("Key('dashboard-personal-health-ai-slot')"),
      lessThan(source.indexOf("Key('dashboard-mobile-summary-card')")),
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
