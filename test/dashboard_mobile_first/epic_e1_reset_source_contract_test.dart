import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Epic 1 exposes the mobile command center before the legacy dashboard',
    () {
      final source = File(
        'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      ).readAsStringSync();

      expect(source, contains("Key('dashboard-mobile-command-center')"));
      expect(source, contains("Key('dashboard-mobile-command-title')"));
      expect(source, contains("Key('dashboard-mobile-command-action')"));
      expect(source, contains('final mobileCommandCenter = phone'));
      expect(
        source.indexOf('mobileCommandCenter,'),
        lessThan(source.indexOf('top,')),
      );
      expect(source, contains('_EvidenceSequence('));
      expect(
        source,
        contains('loggingItems.where((item) => item.recorded).length'),
      );
    },
  );

  test('Epic 1 remains presentation-only', () {
    final source = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'Provider',
      'Repository',
      'Database',
      'SharedPreferences',
      'Drift',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });
}
