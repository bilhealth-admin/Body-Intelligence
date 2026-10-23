import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';

BilPlanCreationRequest buildRequest({
  BilPlanHorizon horizon = BilPlanHorizon.week,
  BilPlanFocus focus = BilPlanFocus.combined,
  int workouts = 3,
  bool confirmed = true,
  bool risky = false,
  int? age,
  int? calories,
  double? currentWeight,
  double? targetWeight,
  DateTime? targetBy,
  List<BilVerifiedRecipe>? recipes,
  List<BilVerifiedWorkout>? sessions,
}) => BilPlanCreationRequest(
  ownerId: 'owner-123',
  planId: 'plan-456',
  startOn: DateTime(2026, 10, 22),
  horizon: horizon,
  focus: focus,
  workoutsPerWeek: workouts,
  confirmedPreferences: confirmed,
  adultConfirmed: true,
  ageYears: age,
  highRiskSymptoms: risky,
  requestedDailyCalories: calories,
  currentWeightKg: currentWeight,
  targetWeightKg: targetWeight,
  targetBy: targetBy,
  workoutCatalog:
      sessions ??
      [
        BilVerifiedWorkout(
          id: 'push-a',
          exerciseIds: ['ex_1', 'ex_2'],
          minutes: 35,
        ),
        BilVerifiedWorkout(id: 'pull-a', exerciseIds: ['ex_3'], minutes: 35),
      ],
  recipeCatalog:
      recipes ??
      const [
        BilVerifiedRecipe(id: 'breakfast_a', slot: BilPlanMealSlot.breakfast),
        BilVerifiedRecipe(id: 'lunch_a', slot: BilPlanMealSlot.lunch),
        BilVerifiedRecipe(id: 'dinner_a', slot: BilPlanMealSlot.dinner),
      ],
);

void main() {
  final now = DateTime(2026, 10, 22, 12);
  test(
    'all horizons preserve unique civil days through Cairo DST boundaries',
    () {
      for (final start in [
        DateTime(2026, 4, 23, 23, 30),
        DateTime(2026, 10, 29, 23, 30),
      ]) {
        for (final horizon in BilPlanHorizon.values) {
          for (final focus in BilPlanFocus.values) {
            final fixture = buildRequest(horizon: horizon, focus: focus);
            final request = BilPlanCreationRequest(
              ownerId: fixture.ownerId,
              planId: fixture.planId,
              startOn: start,
              horizon: horizon,
              focus: focus,
              workoutsPerWeek: 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              workoutCatalog: fixture.workoutCatalog,
              recipeCatalog: fixture.recipeCatalog,
            );
            final plan = const BilSmartPlanEngine().generate(request, start);
            expect(
              plan.days.map((day) => day.date).toSet().length,
              plan.days.length,
            );
            for (var index = 0; index < plan.days.length; index++) {
              expect(
                plan.days[index].date,
                BilPlanDate.iso(
                  DateTime.utc(start.year, start.month, start.day + index),
                ),
              );
            }
            expect(BilSmartPlan.decode(plan.encode()).encode(), plan.encode());
          }
        }
      }
    },
  );

  test('saved minor age overrides an adult checkbox', () {
    expect(
      BilPlanSafety.assess(buildRequest(age: 17)).result,
      BilPlanSafetyResult.invalid,
    );
    expect(
      () => const BilSmartPlanEngine().generate(buildRequest(age: 17), now),
      throwsStateError,
    );
  });
  test('completion flags must be booleans rather than coercible input', () {
    final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
    for (final value in ['true', 1, null]) {
      final json = jsonDecode(plan.encode()) as Map;
      json['days'][0]['workout']['completed'] = value;
      expect(
        () => BilSmartPlan.decode(jsonEncode(json)),
        throwsFormatException,
      );
    }
  });
  test('week gets 7 exact civil days, 3 workouts, 3 meals/day', () {
    final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
    expect(plan.days.length, 7);
    expect(plan.days.first.date, '2026-10-22');
    expect(plan.days.last.date, '2026-10-28');
    expect(plan.days.where((d) => d.workout != null).length, 3);
    expect(plan.days.every((d) => d.meals.length == 3), true);
    expect(plan.status, BilPlanStatus.draft);
    expect(plan.workoutCompletion, 0);
  });

  test('month boundaries are civil calendar months, not 30-day guesses', () {
    expect(
      BilPlanDate.durationDays(BilPlanHorizon.month, DateTime(2026, 1, 31)),
      28,
    );
    expect(
      BilPlanDate.durationDays(BilPlanHorizon.month, DateTime(2028, 1, 31)),
      29,
    );
    expect(
      BilPlanDate.durationDays(
        BilPlanHorizon.sixMonths,
        DateTime(2026, 10, 22),
      ),
      greaterThan(180),
    );
  });

  test('all four durations serialize and round trip', () {
    for (final horizon in BilPlanHorizon.values) {
      final plan = const BilSmartPlanEngine().generate(
        buildRequest(horizon: horizon),
        now,
      );
      final restored = BilSmartPlan.decode(plan.encode());
      expect(restored.horizon, horizon);
      expect(restored.days.length, plan.days.length);
      expect(restored.ownerId, 'owner-123');
      expect(restored.revision, 1);
    }
  });

  test('cannot claim workout completion without activation', () {
    final draft = const BilSmartPlanEngine().generate(buildRequest(), now);
    expect(
      () => draft.recordWorkout(date: now, now: now, completed: true),
      throwsStateError,
    );
    final active = draft.withStatus(BilPlanStatus.active, now);
    expect(active.workoutCompletion, 0);
    final finished = active.recordWorkout(date: now, now: now, completed: true);
    expect(finished.workoutCompletion, greaterThan(0));
    expect(finished.revision, active.revision + 1);
    expect(finished.days.first.meals.length, 3);
    expect(finished.days.first.workout!.completed, true);
  });

  test('future workouts cannot be marked completed', () {
    final active = const BilSmartPlanEngine()
        .generate(buildRequest(), now)
        .withStatus(BilPlanStatus.active, now);
    expect(
      () => active.recordWorkout(
        date: now.add(const Duration(days: 2)),
        now: now,
        completed: true,
      ),
      throwsStateError,
    );
  });

  test('no allergy-compatible meal catalog fails closed', () {
    final request = buildRequest(recipes: const []);
    expect(BilPlanSafety.assess(request).result, BilPlanSafetyResult.invalid);
    expect(
      () => const BilSmartPlanEngine().generate(request, now),
      throwsStateError,
    );
  });

  test('missing breakfast slot fails closed', () {
    final request = buildRequest(
      recipes: const [
        BilVerifiedRecipe(id: 'lunch_a', slot: BilPlanMealSlot.lunch),
        BilVerifiedRecipe(id: 'dinner_a', slot: BilPlanMealSlot.dinner),
      ],
    );
    expect(
      BilPlanSafety.assess(request).reasons,
      contains('incomplete_meal_catalog_breakfast'),
    );
  });

  test('no unverified workout may enter a training plan', () {
    final request = buildRequest(sessions: []);
    expect(BilPlanSafety.assess(request).result, BilPlanSafetyResult.invalid);
  });

  test('very low calorie request requires clinical review', () {
    final request = buildRequest(calories: 950);
    expect(
      BilPlanSafety.assess(request).result,
      BilPlanSafetyResult.needsClinicianReview,
    );
  });

  test('rapid loss or red-flag symptoms requires review', () {
    final deadline = DateTime(2026, 10, 29);
    final request = buildRequest(
      currentWeight: 70,
      targetWeight: 65,
      targetBy: deadline,
    );
    expect(
      BilPlanSafety.assess(request).result,
      BilPlanSafetyResult.needsClinicianReview,
    );
    expect(
      BilPlanSafety.assess(buildRequest(risky: true)).result,
      BilPlanSafetyResult.needsClinicianReview,
    );
  });

  test('training-only does not generate meals', () {
    final plan = const BilSmartPlanEngine().generate(
      buildRequest(focus: BilPlanFocus.training),
      now,
    );
    expect(plan.days.every((d) => d.meals.isEmpty), true);
  });

  test('nutrition-only does not create workout completion claims', () {
    final plan = const BilSmartPlanEngine().generate(
      buildRequest(focus: BilPlanFocus.nutrition, workouts: 0),
      now,
    );
    expect(plan.days.every((d) => d.workout == null), true);
  });

  test('tampered dates and foreign schema are rejected', () {
    final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
    var raw = plan.encode().replaceFirst(
      '"date":"2026-10-22"',
      '"date":"2026-10-24"',
    );
    expect(() => BilSmartPlan.decode(raw), throwsFormatException);
    raw = plan.encode().replaceFirst('"schema":1', '"schema":99');
    expect(() => BilSmartPlan.decode(raw), throwsFormatException);
  });

  test('approved proposal is still not a consumed meal', () {
    final plan = const BilSmartPlanEngine()
        .generate(buildRequest(), now)
        .withStatus(BilPlanStatus.active, now);
    expect(plan.days.first.meals.first.recipeId, 'breakfast_a');
    // PlannedMeal carries no consumed/logged flag by design.
    expect(plan.toJson()['days'], isA<List>());
  });
}
