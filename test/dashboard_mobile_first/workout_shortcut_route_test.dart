import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard does not duplicate the existing workout routines entry', () {
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final wellnessLibrary = File(
      'lib/features/wellness/presentation/wellness_library_page.dart',
    ).readAsStringSync();

    expect(
      dashboard,
      isNot(contains("Key('dashboard-mobile-workout-library-card')")),
    );
    expect(wellnessLibrary, contains("route: '/wellness/workouts/routines'"));
  });
}
