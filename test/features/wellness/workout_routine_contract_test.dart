import 'package:body_intelligence_log/features/wellness/domain/workout_routine_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps only unique movements accepted by the trusted pack', () {
    final result = validateWorkoutRoutineMapping(
      requestedMovementIds: const ['squat', 'missing', 'squat', ' ', 'row'],
      trustedMovementIds: const {'squat', 'row'},
    );

    expect(result.acceptedMovementIds, ['squat', 'row']);
    expect(result.unavailableMovementIds, ['missing']);
    expect(result.canComplete, isTrue);
    expect(result.isComplete, isFalse);
  });

  test('routine cannot complete when no trusted movement remains', () {
    final result = validateWorkoutRoutineMapping(
      requestedMovementIds: const ['retired-movement'],
      trustedMovementIds: const {},
    );
    expect(result.canComplete, isFalse);
  });

  test('completion and unavailable copy exists in all five locales', () {
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      expect(workoutRoutineCopy(locale, 'completeRoutine'), isNotEmpty);
      expect(workoutRoutineCopy(locale, 'movementsUnavailable'), isNotEmpty);
      expect(workoutRoutineCopy(locale, 'routineCompleted'), isNotEmpty);
    }
  });
}
