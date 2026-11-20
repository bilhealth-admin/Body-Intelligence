import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const catalog = BilSmartPlanCatalog();
  const engine = BilSmartPlanEngine();
  final now = DateTime.utc(2026, 11, 17);
  late List<BilVerifiedRecipe> recipes;
  late List<BilVerifiedPlanPhase> phases;

  setUpAll(() async {
    recipes = await catalog.sourcedRecipes(dietary: const DietaryPreferences());
    phases = await const BilSmartPlanPrescriptions().phases();
  });

  BilPlanCreationRequest request({
    required List<BilVerifiedWorkout> workouts,
    required int minutes,
    required BilPlanHorizon horizon,
    BilPlanFocus focus = BilPlanFocus.combined,
    List<BilVerifiedPlanPhase>? selectedPhases,
    DateTime? start,
  }) => BilPlanCreationRequest(
    ownerId: 'synthetic-time-boundary-owner',
    planId: 'synthetic-time-boundary-plan',
    startOn: start ?? now,
    horizon: horizon,
    focus: focus,
    workoutsPerWeek: focus == BilPlanFocus.nutrition ? 0 : 3,
    confirmedPreferences: true,
    adultConfirmed: true,
    ageYears: 30,
    workoutCatalog: focus == BilPlanFocus.nutrition ? const [] : workouts,
    recipeCatalog: focus == BilPlanFocus.training ? const [] : recipes,
    setup: focus == BilPlanFocus.nutrition
        ? null
        : BilPlanSetup(
            environment: BilPlanEnvironment.gym,
            experience: BilPlanExperience.beginner,
            sessionMinutes: minutes,
            equipment: const ['gym'],
            preferredTime: '18:00',
          ),
    phases: focus == BilPlanFocus.nutrition
        ? const []
        : selectedPhases ?? phases,
  );

  void expectOnlyQualifiedWorkouts(
    BilSmartPlan plan,
    List<BilVerifiedWorkout> qualified,
    int minutes,
  ) {
    final byId = {for (final workout in qualified) workout.id: workout};
    for (final day in plan.days) {
      final workout = day.workout;
      if (workout == null) continue;
      final source = byId[workout.templateId];
      expect(source, isNotNull, reason: workout.templateId);
      expect(workout.exerciseIds, source!.exerciseIds);
      expect(workout.minutes, minutes);
    }
  }

  test('real Gym15 leaves month one intact and never invents legs-b', () async {
    final workouts = await catalog.gymSessions(sessionMinutes: 15);
    expect(workouts.map((row) => row.id).toSet(), {
      'push-a',
      'push-b',
      'pull-a',
      'pull-b',
      'legs-a',
    });
    for (final horizon in [BilPlanHorizon.week, BilPlanHorizon.month]) {
      for (final focus in [BilPlanFocus.training, BilPlanFocus.combined]) {
        final input = request(
          workouts: workouts,
          minutes: 15,
          horizon: horizon,
          focus: focus,
        );
        expect(BilPlanSafety.assess(input).result, BilPlanSafetyResult.ready);
        final plan = engine.generate(input, now);
        expectOnlyQualifiedWorkouts(plan, workouts, 15);
        expect(
          plan.days
              .where((day) => day.workout != null)
              .map((day) => day.workout!.templateId)
              .toSet(),
          {'push-a', 'pull-a', 'legs-a'},
        );
      }
    }
  });

  test(
    'real Gym15 long horizons fail safety before absent phase lookup',
    () async {
      final workouts = await catalog.gymSessions(sessionMinutes: 15);
      for (final horizon in [
        BilPlanHorizon.threeMonths,
        BilPlanHorizon.sixMonths,
      ]) {
        for (final focus in [BilPlanFocus.training, BilPlanFocus.combined]) {
          final input = request(
            workouts: workouts,
            minutes: 15,
            horizon: horizon,
            focus: focus,
          );
          final safety = BilPlanSafety.assess(input);
          expect(safety.result, BilPlanSafetyResult.invalid);
          expect(safety.reasons, ['no_verified_workout']);
        }
      }
    },
  );

  test(
    'real Gym15 controlled error cannot leak No element or substitute a leg session',
    () async {
      final workouts = await catalog.gymSessions(sessionMinutes: 15);
      expect(
        () => engine.generate(
          request(
            workouts: workouts,
            minutes: 15,
            horizon: BilPlanHorizon.threeMonths,
          ),
          now,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'actionable source catalog failure',
            'smart_plan_requires_review:no_verified_workout',
          ),
        ),
      );
    },
  );

  test(
    'all204 slider time horizon focus combinations retain source and safety boundaries',
    () async {
      var combinations = 0;
      for (var minutes = 10; minutes <= 90; minutes += 5) {
        final workouts = await catalog.gymSessions(sessionMinutes: minutes);
        for (final horizon in BilPlanHorizon.values) {
          for (final focus in BilPlanFocus.values) {
            combinations++;
            final input = request(
              workouts: workouts,
              minutes: minutes,
              horizon: horizon,
              focus: focus,
            );
            final unsupported =
                focus != BilPlanFocus.nutrition &&
                (minutes == 10 ||
                    (minutes == 15 &&
                        (horizon == BilPlanHorizon.threeMonths ||
                            horizon == BilPlanHorizon.sixMonths)));
            final safety = BilPlanSafety.assess(input);
            if (unsupported) {
              expect(safety.result, BilPlanSafetyResult.invalid);
              expect(safety.reasons, ['no_verified_workout']);
            } else {
              expect(safety.result, BilPlanSafetyResult.ready);
              final plan = engine.generate(input, now);
              expectOnlyQualifiedWorkouts(plan, workouts, minutes);
              expect(
                BilSmartPlan.decode(plan.encode()).encode(),
                plan.encode(),
              );
            }
          }
        }
      }
      expect(combinations, 204);
    },
  );

  test(
    'Gym75 week generates all recipe styles on seven local start weekdays',
    () async {
      final workouts = await catalog.gymSessions(sessionMinutes: 75);
      final byStyle = {
        for (final style in MealPlanDiet.values)
          style: await catalog.checkRecipeStyle(
            style,
            const DietaryPreferences(),
          ),
      };
      for (final choices in byStyle.values) {
        expect(choices.missing, isEmpty);
      }
      var cases = 0;
      for (var weekday = 0; weekday < 7; weekday++) {
        final anchor = DateTime(2026, 11, 20 + weekday, 23, 45);
        for (final style in <MealPlanDiet?>[null, ...MealPlanDiet.values]) {
          for (final experience in BilPlanExperience.values) {
            for (var sessions = 1; sessions <= 6; sessions++) {
              // No active goal, maintenance, gain, and a gradual loss.
              for (final targetKg in <double?>[null, 70, 72, 68]) {
                final input = BilPlanCreationRequest(
                  ownerId: 'synthetic-week-owner',
                  planId: 'synthetic-week-plan',
                  startOn: anchor,
                  horizon: BilPlanHorizon.week,
                  focus: style == null
                      ? BilPlanFocus.training
                      : BilPlanFocus.combined,
                  workoutsPerWeek: sessions,
                  confirmedPreferences: true,
                  adultConfirmed: true,
                  ageYears: 30,
                  currentWeightKg: 70,
                  targetWeightKg: targetKg,
                  targetBy: targetKg == null
                      ? null
                      : anchor.add(const Duration(days: 56)),
                  setup: BilPlanSetup(
                    environment: BilPlanEnvironment.gym,
                    experience: experience,
                    sessionMinutes: 75,
                    equipment: const ['gym'],
                    preferredTime: style == null ? null : '18:00',
                    goalId: targetKg == null ? null : 'synthetic-active-goal',
                  ),
                  workoutCatalog: workouts,
                  recipeCatalog: byStyle[style]?.recipes ?? const [],
                  phases: phases,
                );
                final reason =
                    'style=$style experience=$experience sessions=$sessions target=$targetKg';
                expect(
                  BilPlanSafety.assess(input).reasons,
                  isEmpty,
                  reason: reason,
                );
                final plan = engine.generate(input, anchor);
                final saved = BilSmartPlan.decode(plan.encode());
                expect(saved.days.map((day) => day.date), [
                  for (var day = 0; day < 7; day++)
                    BilPlanDate.iso(
                      DateTime(anchor.year, anchor.month, anchor.day + day),
                    ),
                ], reason: reason);
                expect(
                  saved.days.where((day) => day.workout != null),
                  hasLength(sessions),
                  reason: reason,
                );
                expectOnlyQualifiedWorkouts(saved, workouts, 75);
                expect(
                  saved.days.expand((day) => day.meals),
                  hasLength(style == null ? 0 : 21),
                  reason: reason,
                );
                cases++;
              }
            }
          }
        }
      }
      expect(cases, 2016);
    },
  );

  test(
    'actual reported Gym75 one month has all source phases and IDs',
    () async {
      final workouts = await catalog.gymSessions(sessionMinutes: 75);
      expect(workouts.length, 6);
      final input = request(
        workouts: workouts,
        minutes: 75,
        horizon: BilPlanHorizon.month,
      );
      expect(BilPlanSafety.assess(input).result, BilPlanSafetyResult.ready);
      final plan = engine.generate(input, now);
      expectOnlyQualifiedWorkouts(plan, workouts, 75);
      await catalog.validate(plan, const DietaryPreferences());
    },
  );

  test(
    'required phase IDs must resolve exactly once, not first or guessed',
    () async {
      final workouts = await catalog.gymSessions(sessionMinutes: 75);
      for (final malformed in [
        workouts.where((row) => row.id != 'push-a').toList(),
        [...workouts, workouts.singleWhere((row) => row.id == 'push-a')],
      ]) {
        final safety = BilPlanSafety.assess(
          request(
            workouts: malformed,
            minutes: 75,
            horizon: BilPlanHorizon.month,
          ),
        );
        expect(safety.result, BilPlanSafetyResult.invalid);
        expect(safety.reasons, ['no_verified_workout']);
      }
    },
  );

  test(
    'an empty declared required phase blocks before generation; optional phases stay optional',
    () async {
      final workouts = await catalog.gymSessions(sessionMinutes: 75);
      final emptyPhase = request(
        workouts: workouts,
        minutes: 75,
        horizon: BilPlanHorizon.month,
        selectedPhases: const [BilVerifiedPlanPhase(month: 1, sessionIds: [])],
      );
      expect(BilPlanSafety.assess(emptyPhase).reasons, ['no_verified_workout']);
      final noPhases = request(
        workouts: workouts,
        minutes: 75,
        horizon: BilPlanHorizon.month,
        selectedPhases: const [],
      );
      expect(BilPlanSafety.assess(noPhases).result, BilPlanSafetyResult.ready);
      expectOnlyQualifiedWorkouts(engine.generate(noPhases, now), workouts, 75);
    },
  );

  test('calendar month clamp does not reject an unused future phase', () async {
    final workouts = await catalog.gymSessions(sessionMinutes: 15);
    final input = request(
      workouts: workouts,
      minutes: 15,
      horizon: BilPlanHorizon.month,
      start: DateTime.utc(2026, 1, 31),
    );
    expect(BilPlanSafety.assess(input).result, BilPlanSafetyResult.ready);
    final plan = engine.generate(input, now);
    expectOnlyQualifiedWorkouts(plan, workouts, 15);
    expect(plan.days.length, 28);
  });
}
