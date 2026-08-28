import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Today and AI Coach share the authoritative exercise calorie policy',
    () {
      final dashboard = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();
      final coach = File(
        'lib/features/intelligence_center/services/coach_context_provider.dart',
      ).readAsStringSync();

      for (final contract in const [
        'authoritativeExerciseEnergyForDay',
        'ExerciseCaloriePolicy.calculate',
      ]) {
        expect(dashboard, contains(contract));
        expect(coach, contains(contract));
      }
      expect(coach, contains("'verifiedBurnedKcal'"));
      expect(coach, contains("'includedInRemaining'"));
      expect(coach, contains("'manualExerciseChangesAllowance': false"));
      expect(coach, contains("'remainingCaloriesKcal'"));
    },
  );

  test(
    'Coach today context has real meals water sleep and fasting sources',
    () {
      final coach = File(
        'lib/features/intelligence_center/services/coach_context_provider.dart',
      ).readAsStringSync();
      expect(coach, contains("'consumedCaloriesKcal'"));
      expect(coach, contains("'waterMl'"));
      expect(coach, contains("'source': 'connected_health'"));
      expect(coach, contains("'source': 'manual'"));
      expect(coach, contains("FastingSession.tryParse("));
      expect(coach, contains("'remainingMinutes'"));
      expect(coach, isNot(contains("'sleepSource': 'estimated'")));
    },
  );
}
