import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard first usable frame is not hidden by an entrance animation',
    () {
      final reveal = File(
        'lib/features/dashboard/widgets/dashboard_motion_reveal.dart',
      ).readAsStringSync();
      final grid = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();

      expect(
        reveal,
        contains('class DashboardMotionReveal extends StatelessWidget'),
      );
      expect(reveal, isNot(contains('FadeTransition')));
      expect(reveal, isNot(contains('SlideTransition')));
      expect(reveal, isNot(contains('begin: 0')));
      expect(grid, contains('DashboardMotionReveal('));
    },
  );

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
