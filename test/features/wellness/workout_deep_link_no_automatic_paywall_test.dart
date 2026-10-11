import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial workout deep link opens details without Plans navigation', () {
    final source = File(
      'lib/features/wellness/presentation/bil_workout_routines_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('  void _scheduleInitialItem(');
    final end = source.indexOf('  bool _isLocked(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final initial = source.substring(start, end);
    expect(initial, contains('_openDetails(item)'));
    expect(initial, contains('EntitlementAuthority.verifiedServer'));
    expect(initial, isNot(contains("'/plans")));
    expect(initial, isNot(contains('context.push(')));
    // Existing paid-content enforcement remains independent from navigation.
    expect(source.substring(end), contains('workoutItemAccessGranted'));
  });
}
