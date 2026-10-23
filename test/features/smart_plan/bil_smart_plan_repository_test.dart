import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bil_smart_plan_engine_test.dart' show buildRequest;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late PreferencesRepository prefs;
  late BilSmartPlanRepository plans;
  String? owner;
  final now = DateTime(2026, 10, 22, 12);
  BilSmartPlan draft() =>
      const BilSmartPlanEngine().generate(buildRequest(), now);
  setUp(() {
    owner = 'owner-123';
    db = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: owner);
    prefs = PreferencesRepository(db);
    plans = BilSmartPlanRepository(
      preferences: prefs,
      currentOwnerId: () => owner,
    );
  });
  tearDown(() => db.close());

  test(
    'owner-bound save is durable and verified after repository recreation',
    () async {
      final result = await plans.save(draft(), expectedRevision: 0);
      final reopened = BilSmartPlanRepository(
        preferences: prefs,
        currentOwnerId: () => owner,
      );
      expect((await reopened.readFor(owner!))!.encode(), result.encode());
    },
  );
  test('concurrent CAS writers accept exactly one revision', () async {
    final first = await plans.save(draft(), expectedRevision: 0);
    final next = first.withStatus(BilPlanStatus.active, now);
    Future<bool> save() async {
      try {
        await plans.save(next, expectedRevision: 1);
        return true;
      } on StateError {
        return false;
      }
    }

    expect((await Future.wait([save(), save()])).where((v) => v).length, 1);
    expect((await plans.readFor(owner!))!.revision, 2);
  });
  test('foreign owner snapshot and signed-out access fail closed', () async {
    final data = draft().toJson()..['ownerId'] = 'another-owner';
    await prefs.set(plans.storageKey(owner!), jsonEncode(data));
    await expectLater(plans.readFor(owner!), throwsStateError);
    owner = null;
    await expectLater(plans.readFor('owner-123'), throwsStateError);
  });
  test('malformed storage and non-integral revisions are rejected', () async {
    for (final raw in ['{', jsonEncode(draft().toJson()..['revision'] = 1.8)]) {
      await prefs.set(plans.storageKey(owner!), raw);
      await expectLater(plans.readFor(owner!), throwsFormatException);
    }
  });
  test('stale cloud restore cannot overwrite a newer local edit', () async {
    final first = await plans.save(draft(), expectedRevision: 0);
    final next = await plans.save(
      first.withStatus(BilPlanStatus.active, now),
      expectedRevision: 1,
    );
    await expectLater(
      plans.restoreSnapshot(
        owner: owner!,
        expected: first.encode(),
        next: null,
      ),
      throwsStateError,
    );
    expect((await plans.readFor(owner!))!.encode(), next.encode());
  });
  test(
    'actual workout, plan completion and receipt commit once and undo preserves other fields',
    () async {
      final first = await plans.save(draft(), expectedRevision: 0);
      final active = await plans.save(
        first.withStatus(BilPlanStatus.active, now),
        expectedRevision: 1,
      );
      final daily = DailyLogRepository(db);
      await daily.save(date: now, steps: 3456, notes: 'private existing note');
      final service = BilSmartPlanWorkoutService(db, plans, () {
        if (owner != 'owner-123') throw StateError('owner_changed');
      });
      final saved = await service.record(
        expected: active,
        date: '2026-10-22',
        now: now,
        actualMinutes: 24,
        completed: true,
      );
      final log = (await daily.getForDay(now))!;
      expect((jsonDecode(log.exerciseNotes!) as Map)['minutes'], 24);
      expect(log.steps, 3456);
      expect(log.notes, 'private existing note');
      expect(saved.days.first.workout!.completed, isTrue);
      await expectLater(
        service.record(
          expected: active,
          date: '2026-10-22',
          now: now,
          actualMinutes: 24,
          completed: true,
        ),
        throwsStateError,
      );
      expect((await daily.getForDay(now))!.exerciseNotes, log.exerciseNotes);
      await service.record(
        expected: saved,
        date: '2026-10-22',
        now: now,
        actualMinutes: 5,
        completed: false,
      );
      final undone = (await daily.getForDay(now))!;
      expect(undone.exerciseNotes, isNull);
      expect(undone.steps, 3456);
      expect(
        (await plans.readFor(owner!))!.days.first.workout!.completed,
        isFalse,
      );
    },
  );
  test(
    'invalid actual duration cannot create a workout or plan change',
    () async {
      final first = await plans.save(draft(), expectedRevision: 0);
      final active = await plans.save(
        first.withStatus(BilPlanStatus.active, now),
        expectedRevision: 1,
      );
      await expectLater(
        BilSmartPlanWorkoutService(db, plans, () {}).record(
          expected: active,
          date: '2026-10-22',
          now: now,
          actualMinutes: 0,
          completed: true,
        ),
        throwsArgumentError,
      );
      expect((await plans.readFor(owner!))!.revision, 2);
      expect(await DailyLogRepository(db).getForDay(now), isNull);
    },
  );
}
