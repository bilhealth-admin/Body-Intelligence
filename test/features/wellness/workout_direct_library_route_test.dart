import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'workout shortcut opens video routines and keeps logging in-library',
    () {
      final router = File('lib/app/router/app_router.dart').readAsStringSync();
      final routeStart = router.indexOf("path: '/wellness/workouts',");
      final nextRoute = router.indexOf(
        "path: '/wellness/workouts/routines',",
        routeStart,
      );
      final route = router.substring(routeStart, nextRoute);
      expect(route, contains('BilWorkoutRoutinesPage('));
      expect(route, isNot(contains('WorkoutEntryChooserPage')));

      final library = File(
        'lib/features/wellness/presentation/bil_workout_routines_page.dart',
      ).readAsStringSync();
      expect(library, contains("ValueKey('workout-programs-action')"));
      expect(library, contains("context.push('/wellness/workouts/log')"));
      expect(library, isNot(contains("ValueKey('manual-workout-entry')")));
    },
  );
}
