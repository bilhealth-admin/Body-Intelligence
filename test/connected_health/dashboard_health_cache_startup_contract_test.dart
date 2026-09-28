import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard starts the local health cache before post-frame work', () {
    final source = File(
      'lib/features/connected_health/widgets/dashboard_health_activity_refresh.dart',
    ).readAsStringSync();
    final initStart = source.indexOf('void initState()');
    final schedule = source.indexOf('_schedule();', initStart);
    final restore = source.indexOf('restoreCachedSnapshot()', initStart);

    expect(initStart, greaterThanOrEqualTo(0));
    expect(restore, greaterThan(initStart));
    expect(restore, lessThan(schedule));
  });
}
