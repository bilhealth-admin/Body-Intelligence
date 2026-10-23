import 'dart:convert';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bil_smart_plan_engine_test.dart' show buildRequest;

void main() {
  final now = DateTime(2026, 10, 22);
  BilSmartPlan draft() =>
      const BilSmartPlanEngine().generate(buildRequest(), now);
  test(
    'saved history reconstructs previous versions exactly after restart',
    () {
      final original = draft();
      final active = original.withStatus(BilPlanStatus.active, now);
      final deferred = active.rescheduleWorkout(
        date: now,
        target: now.add(const Duration(days: 1)),
        now: now,
        reason: BilPlanChangeReason.travel,
      );
      final reopened = BilSmartPlan.decode(deferred.encode());
      expect(reopened.changes.first.reason, BilPlanChangeReason.travel);
      expect(reopened.previousVersion()!.encode(), active.encode());
      expect(
        reopened.previousVersion()!.previousVersion()!.encode(),
        original.encode(),
      );
      expect(original.changes, isEmpty);
      expect(reopened.days.where((d) => d.workout?.completed == true), isEmpty);
    },
  );
  test('missed session can move to a future rest day without punishment', () {
    final active = draft().withStatus(BilPlanStatus.active, now);
    final tomorrow = now.add(const Duration(days: 1));
    final next = active.rescheduleWorkout(
      date: now,
      target: tomorrow,
      now: tomorrow,
      reason: BilPlanChangeReason.fatigue,
    );
    expect(
      next.days.where((d) => d.workout != null).length,
      active.days.where((d) => d.workout != null).length,
    );
    expect(
      next.onDate(tomorrow)!.workout!.toJson(),
      active.onDate(now)!.workout!.toJson(),
    );
    expect(
      next.days.map((d) => d.meals.map((m) => m.toJson()).toList()).toList(),
      active.days.map((d) => d.meals.map((m) => m.toJson()).toList()).toList(),
    );
    expect(
      () => next.rescheduleWorkout(date: tomorrow, target: now, now: tomorrow),
      throwsStateError,
    );
  });
  test('meal replacement is a revision and never a consumed diary record', () {
    final active = draft().withStatus(BilPlanStatus.active, now);
    final old = active.onDate(now)!.meals.first;
    final next = active.replaceMeal(
      date: now,
      slot: old.slot,
      recipeId: 'verified-recipe-replacement',
      now: now,
    );
    expect(
      next.onDate(now)!.meals.first.recipeId,
      'verified-recipe-replacement',
    );
    expect(next.changes.first.reason, BilPlanChangeReason.mealSwap);
    expect(next.previousVersion()!.encode(), active.encode());
    expect(
      () => next.replaceMeal(
        date: now,
        slot: old.slot,
        recipeId: 'invalid/injection',
        now: now,
      ),
      throwsFormatException,
    );
  });
  test('completed sessions and occupied days cannot be moved', () {
    final active = draft().withStatus(BilPlanStatus.active, now);
    final done = active.recordWorkout(date: now, now: now, completed: true);
    expect(
      () => done.rescheduleWorkout(
        date: now,
        target: now.add(const Duration(days: 1)),
        now: now,
      ),
      throwsStateError,
    );
    final occupied = active.days.firstWhere(
      (d) => d.date != BilPlanDate.iso(now) && d.workout != null,
    );
    expect(
      () => active.rescheduleWorkout(
        date: now,
        target: BilPlanDate.parse(occupied.date),
        now: now,
      ),
      throwsStateError,
    );
  });
  test(
    'meal date swap preserves all meals and workout records after restart',
    () {
      final active = draft()
          .withStatus(BilPlanStatus.active, now)
          .replaceMeal(
            date: now.add(const Duration(days: 1)),
            slot: BilPlanMealSlot.breakfast,
            recipeId: 'breakfast_b',
            now: now,
          );
      final source = active.days.first;
      final meal = source.meals.first;
      final target = active.days.firstWhere(
        (d) =>
            d.date != source.date &&
            d.meals.any(
              (m) => m.slot == meal.slot && m.recipeId != meal.recipeId,
            ),
      );
      final swapped = active.swapMealDates(
        date: now,
        target: BilPlanDate.parse(target.date),
        slot: meal.slot,
        now: now,
      );
      final reopened = BilSmartPlan.decode(swapped.encode());
      expect(
        reopened.onDate(BilPlanDate.parse(target.date))!.meals.first.recipeId,
        meal.recipeId,
      );
      expect(
        reopened.days.map((d) => d.workout?.toJson()),
        active.days.map((d) => d.workout?.toJson()),
      );
      expect(reopened.previousVersion()!.encode(), active.encode());
      expect(
        () => active.swapMealDates(
          date: now,
          target: BilPlanDate.parse(target.date),
          slot: meal.slot,
          now: now.add(const Duration(days: 1)),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'alternative session is a confirmed revision, never a performed workout',
    () {
      final active = draft().withStatus(BilPlanStatus.active, now);
      final replacement = BilPlanWorkout(
        templateId: 'source-alternative',
        exerciseIds: ['source-movement'],
        minutes: 20,
      );
      final next = active.replaceWorkout(
        date: now,
        replacement: replacement,
        now: now,
        reason: BilPlanChangeReason.equipment,
      );
      expect(next.onDate(now)!.workout!.completed, isFalse);
      expect(next.previousVersion()!.encode(), active.encode());
      expect(
        next.days.map((d) => d.meals.map((m) => m.toJson()).toList()),
        active.days.map((d) => d.meals.map((m) => m.toJson()).toList()),
      );
      expect(
        () => active.replaceWorkout(
          date: now,
          replacement: replacement.withCompletion(completed: true),
          now: now,
          reason: BilPlanChangeReason.equipment,
        ),
        throwsStateError,
      );
    },
  );
  test('malformed revision journal and out-of-period data are rejected', () {
    final active = draft().withStatus(BilPlanStatus.active, now);
    final data = active.toJson();
    for (final bad in [
      {...active.changes.first.toJson(), 'revision': 0},
      {...active.changes.first.toJson(), 'reason': 'ignore_safety'},
      {...active.changes.first.toJson(), 'ownerId': 'someone-else'},
      {
        ...active.changes.first.toJson(),
        'beforeDays': [active.days.first.toJson()..['date'] = '2027-01-01'],
      },
    ]) {
      expect(
        () => BilSmartPlan.decode(
          jsonEncode({
            ...data,
            'changes': [bad],
          }),
        ),
        throwsFormatException,
      );
    }
  });
  test('history retention is bounded with an explicit reversible window', () {
    var plan = draft().withStatus(BilPlanStatus.active, now);
    for (var i = 0; i < 40; i++) {
      plan = plan.withStatus(
        plan.status == BilPlanStatus.active
            ? BilPlanStatus.paused
            : BilPlanStatus.active,
        now,
      );
    }
    expect(BilSmartPlan.decode(plan.encode()).changes.length, 32);
    for (var i = 0; i < 32; i++) {
      plan = plan.previousVersion()!;
    }
    expect(plan.previousVersion(), isNull);
  });
}
