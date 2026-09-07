import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/presentation/exercise_calorie_settings_page.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'exercise controls stay editable without verified energy and apply no calories',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exerciseCaloriePreferencesProvider.overrideWithValue(
              const AsyncData(
                ExerciseCaloriePreferences(
                  includeInRemainingGoal: true,
                  adjustMacroGoals: true,
                ),
              ),
            ),
            todayAuthoritativeExerciseEnergyProvider.overrideWithValue(
              const AsyncData(null),
            ),
          ],
          child: const MaterialApp(home: ExerciseCalorieSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final include = tester.widget<SwitchListTile>(
        find.byKey(const Key('exercise-calories-include-switch')),
      );
      final macros = tester.widget<SwitchListTile>(
        find.byKey(const Key('exercise-calories-macros-switch')),
      );
      expect(include.value, isTrue);
      expect(include.onChanged, isNotNull);
      expect(macros.value, isTrue);
      expect(macros.onChanged, isNotNull);
      expect(
        find.byKey(const Key('exercise-energy-evidence-state')),
        findsOneWidget,
      );
    },
  );

  testWidgets('exercise controls become available with current evidence', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseCaloriePreferencesProvider.overrideWithValue(
            const AsyncData(
              ExerciseCaloriePreferences(
                includeInRemainingGoal: true,
                adjustMacroGoals: true,
              ),
            ),
          ),
          todayAuthoritativeExerciseEnergyProvider.overrideWithValue(
            AsyncData(
              AuthoritativeExerciseEnergy(
                kcal: 320,
                observedAt: now,
                source: 'Apple Health',
                confidence: 1,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ExerciseCalorieSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final include = tester.widget<SwitchListTile>(
      find.byKey(const Key('exercise-calories-include-switch')),
    );
    final macros = tester.widget<SwitchListTile>(
      find.byKey(const Key('exercise-calories-macros-switch')),
    );
    expect(include.value, isTrue);
    expect(include.onChanged, isNotNull);
    expect(macros.value, isTrue);
    expect(macros.onChanged, isNotNull);
  });
}
