import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard motion uses centralized accessible tokens', () {
    final tokens = File(
      'lib/app/theme/premium_motion_tokens.dart',
    ).readAsStringSync();
    final reveal = File(
      'lib/features/dashboard/widgets/dashboard_motion_reveal.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(tokens, contains('dashboardEntranceDuration'));
    expect(tokens, contains('dashboardEntranceCurve'));
    expect(tokens, contains('dashboardEntranceOffset'));
    expect(reveal, contains('prefersReducedMotion(context)'));
    expect(reveal, contains('FadeTransition'));
    expect(reveal, contains('SlideTransition'));
    expect(grid, contains('DashboardMotionReveal('));
  });

  test('dashboard motion stays presentation only', () {
    final reveal = File(
      'lib/features/dashboard/widgets/dashboard_motion_reveal.dart',
    ).readAsStringSync();
    final tokens = File(
      'lib/app/theme/premium_motion_tokens.dart',
    ).readAsStringSync();

    // Match architecture terms as standalone identifiers. This deliberately
    // does not reject Flutter's SingleTickerProviderStateMixin.
    final forbidden = RegExp(
      r'\b(?:Provider|Repository|Database)\b|Engine\.calculate|ref\.(?:read|watch)\(',
    );

    expect(forbidden.hasMatch(reveal), isFalse);
    expect(forbidden.hasMatch(tokens), isFalse);
  });
}
