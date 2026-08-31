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

      final library = [
        'lib/features/wellness/presentation/bil_workout_routines_page.dart',
        'lib/features/wellness/presentation/bil_workout_routines_library.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      expect(library, contains("ValueKey('workout-programs-action')"));
      expect(library, contains("ValueKey('workout-programs-inline-action')"));
      expect(library, contains("ValueKey('workout-video-library-header')"));
      expect(library, contains('wellnessVerifiedWorkoutVideoCount('));
      expect(
        library,
        isNot(contains("'\$verifiedVideoCount verified workout videos'")),
      );
      expect(library, contains("'Verified workout video library'"));
      expect(library, isNot(contains("'300+ home workout videos'")));
      expect(library, contains("context.push('/wellness/workouts/log')"));
      expect(library, isNot(contains("ValueKey('manual-workout-entry')")));
    },
  );
}
