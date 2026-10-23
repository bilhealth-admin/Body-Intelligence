import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:body_intelligence_log/features/wellness/repositories/gym_six_month_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every prescription matches the complete pinned source in exact released movement order',
    () async {
      final bytes = File(
        'artifacts/workout_media/gym_training_plan_source_v1.json',
      ).readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        GymSixMonthPlanRepository.sourceSha256,
      );
      final source = jsonDecode(utf8.decode(bytes)) as Map;
      final workouts = await const BilSmartPlanCatalog().gymSessions(
        sessionMinutes: 35,
      );
      var count = 0;
      for (final workout in workouts) {
        final original = (source['sessions'] as List).cast<Map>().singleWhere(
          (row) =>
              (row['name'] as String).toLowerCase().replaceAll(' ', '-') ==
              workout.id,
        );
        final expected = original['exercises'] as List;
        final doses = await const BilSmartPlanPrescriptions().session(
          BilPlanWorkout(
            templateId: workout.id,
            exerciseIds: workout.exerciseIds,
            minutes: workout.minutes,
          ),
        );
        expect(doses.length, expected.length);
        for (var i = 0; i < doses.length; i++) {
          expect(doses[i].exerciseId, workout.exerciseIds[i]);
          expect(doses[i].sets, expected[i]['sets']);
          expect(doses[i].repetitions, expected[i]['reps']);
          expect(doses[i].restSeconds, expected[i]['rest_seconds']);
          count++;
        }
      }
      expect(count, 30);
    },
  );
  test(
    'six calendar phases use the real source rotation without increasing confirmed weekly frequency',
    () async {
      final workouts = await const BilSmartPlanCatalog().gymSessions(
        sessionMinutes: 35,
      );
      final phases = await const BilSmartPlanPrescriptions().phases();
      final start = DateTime(2026, 10, 23);
      final plan = const BilSmartPlanEngine().generate(
        BilPlanCreationRequest(
          ownerId: 'source-owner',
          planId: 'source-plan',
          startOn: start,
          horizon: BilPlanHorizon.sixMonths,
          focus: BilPlanFocus.training,
          workoutsPerWeek: 3,
          confirmedPreferences: true,
          adultConfirmed: true,
          workoutCatalog: workouts,
          recipeCatalog: const [],
          phases: phases,
        ),
        start,
      );
      expect(plan.days.map((d) => d.phase).toSet().length, 6);
      expect(
        plan.onDate(BilPlanDate.afterMonths(start, 1))!.phase,
        'gym-month-2',
      );
      expect(
        (await const BilSmartPlanPrescriptions().phase('gym-month-2'))!['name'],
        'Base volume',
      );
      for (final day in plan.days.where((d) => d.workout != null)) {
        final month = int.parse(day.phase.replaceFirst('gym-month-', ''));
        expect(
          phases.singleWhere((phase) => phase.month == month).sessionIds,
          contains(day.workout!.templateId),
        );
      }
      for (var first = 0; first < plan.days.length; first += 7) {
        expect(
          plan.days.skip(first).take(7).where((d) => d.workout != null).length,
          lessThanOrEqualTo(3),
        );
      }
    },
  );
  test('changed IDs or order cannot inherit a trusted source dose', () async {
    final workout = (await const BilSmartPlanCatalog().gymSessions(
      sessionMinutes: 35,
    )).first;
    await expectLater(
      const BilSmartPlanPrescriptions().session(
        BilPlanWorkout(
          templateId: workout.id,
          exerciseIds: workout.exerciseIds.reversed,
          minutes: 30,
        ),
      ),
      throwsStateError,
    );
    expect(
      await const BilSmartPlanPrescriptions().session(
        BilPlanWorkout(
          templateId: 'home-review-1',
          exerciseIds: ['source-home-movement'],
          minutes: 15,
        ),
      ),
      isEmpty,
    );
  });
  test(
    'member time budget cannot be shorter than source-prescribed rests alone',
    () async {
      const catalog = BilSmartPlanCatalog();
      expect(await catalog.gymSessions(sessionMinutes: 10), isEmpty);
      final limited = await catalog.gymSessions(sessionMinutes: 15);
      expect(limited, isNotEmpty);
      expect(limited.any((session) => session.id == 'legs-b'), isFalse);
      for (final session in limited) {
        final source = await const BilSmartPlanPrescriptions()
            .minimumRestSeconds(session.id);
        expect(source, lessThan(15 * 60));
        expect(session.minutes, 15);
      }
      expect((await catalog.gymSessions(sessionMinutes: 30)).length, 6);
    },
  );
}
