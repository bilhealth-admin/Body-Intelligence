import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'My Exercises supports persistent create, delete, and daily logging',
    () {
      final source =
          [
                'workout_library_page.dart',
                'workout_library_actions.dart',
                'workout_library_selection.dart',
              ]
              .map(
                (name) => File(
                  'lib/features/wellness/presentation/$name',
                ).readAsStringSync(),
              )
              .join('\n');

      expect(source, contains('wellness.custom_exercises.v1'));
      expect(source, contains("key: const Key('custom-exercise-name')"));
      expect(source, contains("key: const Key('save-custom-exercise')"));
      expect(source, contains('_persistCustomExercises'));
      expect(source, contains('_deleteCustomExercise'));
      expect(source, contains('_openCustomExercise'));
      expect(source, contains('_saveWorkout'));
    },
  );

  test('exercise editor and display options have direct extended copy', () {
    const keys = {
      'Display options',
      'Exercise sort order',
      'A to Z',
      'Z to A',
      'Create exercise',
      'Exercise name',
      'Category',
      'Could not save exercise. Review and retry.',
      'Delete exercise?',
      'This removes the custom exercise from My Exercises.',
      'Could not delete exercise.',
      'Could not save display options.',
    };
    for (final key in keys) {
      final values = ExtendedRuntimeCopy.values[key];
      expect(values, isNotNull, reason: key);
      for (final locale in ExtendedRuntimeCopy.supported) {
        expect(values!.containsKey(locale), isTrue, reason: '$key|$locale');
        expect(values[locale]!.trim(), isNotEmpty, reason: '$key|$locale');
        expect(values[locale]!.trim(), isNot(key), reason: '$key|$locale');
      }
    }
  });
}
