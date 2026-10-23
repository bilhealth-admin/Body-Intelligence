import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const catalog = BilSmartPlanCatalog();
  const prescriptions = BilSmartPlanPrescriptions();
  final now = DateTime(2026, 10, 23);
  BilPlanSetup setup(
    BilPlanExperience level, {
    int minutes = 40,
    Set<String> equipment = const {'none'},
  }) => BilPlanSetup(
    environment: BilPlanEnvironment.home,
    experience: level,
    sessionMinutes: minutes,
    equipment: equipment,
  );
  BilPlanWorkout workout(BilVerifiedWorkout session) => BilPlanWorkout(
    templateId: session.id,
    exerciseIds: session.exerciseIds,
    minutes: session.minutes,
  );

  test(
    'published ranges and exact released Home identities back every actual prescription',
    () async {
      final bytes = File(
        BilSmartPlanPrescriptions.homeAssetPath,
      ).readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        BilSmartPlanPrescriptions.homeArtifactSha256,
      );
      final document = jsonDecode(utf8.decode(bytes)) as Map;
      expect(document['reviewedOn'], '2026-10-23');
      final sources = (document['sources'] as List).cast<Map>();
      expect(sources.singleWhere((row) => row['publisher'] == 'NHS')['facts'], {
        'repetitions': [8, 12],
        'sets': [2, 3],
      });
      final discovery = const WorkoutDiscoveryCatalogRepository().parse(
        await rootBundle.loadString(
          WorkoutDiscoveryCatalogRepository.assetPath,
        ),
        await const WorkoutReleaseCatalogRepository().load(),
      );
      var doseCount = 0;
      for (final level in BilPlanExperience.values) {
        final choices = await catalog.homeSessions(
          setup(
            level,
            equipment: {'none', 'dumbbell pair', 'kettlebell single'},
          ),
        );
        expect(choices.length, level == BilPlanExperience.beginner ? 2 : 4);
        for (final session in choices) {
          final doses = await prescriptions.session(workout(session));
          expect(doses.length, 6);
          expect(doses.map((row) => row.exerciseId), session.exerciseIds);
          for (final dose in doses) {
            expect(dose.homeGuidance, isTrue);
            expect(dose.sets, level == BilPlanExperience.experienced ? 3 : 2);
            expect(dose.repetitions, anyOf('8-12', '8-12 each side'));
            expect(dose.restSeconds, 120);
            expect(
              discovery.where(
                (item) =>
                    item.id == dose.exerciseId &&
                    item.releaseBundleId == 'home-training',
              ),
              hasLength(1),
            );
            doseCount++;
          }
        }
      }
      expect(doseCount, 60);
    },
  );

  test(
    'equipment filtering selects real alternatives without fabricating media or substituting an unavailable weight',
    () async {
      for (final level in BilPlanExperience.values) {
        final basic = await catalog.homeSessions(setup(level));
        expect(basic.length, 2);
        expect(
          basic
              .expand((row) => row.exerciseIds)
              .any(
                (id) => id.contains('dumbbell') || id.contains('kettlebell'),
              ),
          isFalse,
        );
      }
      final dumbbells = await catalog.homeSessions(
        setup(BilPlanExperience.regular, equipment: {'none', 'dumbbell pair'}),
      );
      expect(dumbbells.length, 3);
      expect(
        dumbbells.expand((row) => row.exerciseIds),
        contains('resistance-full-body-dumbbell-deadlift-to-row-technique'),
      );
      expect(
        dumbbells
            .expand((row) => row.exerciseIds)
            .any((id) => id.contains('kettlebell')),
        isFalse,
      );
    },
  );

  test(
    'warm-up and real prescribed rests cannot be squeezed into a smaller member budget',
    () async {
      expect(
        await catalog.homeSessions(
          setup(BilPlanExperience.beginner, minutes: 10),
        ),
        isEmpty,
      );
      expect(
        await catalog.homeSessions(
          setup(BilPlanExperience.experienced, minutes: 25),
        ),
        isEmpty,
      );
      final choices = await catalog.homeSessions(
        setup(BilPlanExperience.beginner, minutes: 25),
      );
      expect(choices, hasLength(2));
      for (final choice in choices) {
        final minimum =
            await prescriptions.minimumRestSeconds(choice.id) +
            await prescriptions.minimumWarmupSeconds(choice.id);
        expect(minimum, 1080);
        expect(minimum, lessThan(choice.minutes * 60));
        expect(choice.minutes, 25);
      }
    },
  );

  for (final horizon in BilPlanHorizon.values) {
    for (final focus in BilPlanFocus.values) {
      test(
        'Home ${horizon.name} ${focus.name}: reopen exact choices, preserve recovery and never auto-increase dose',
        () async {
          final savedSetup = setup(BilPlanExperience.beginner);
          final choices = await catalog.homeSessions(savedSetup);
          final recipes = focus == BilPlanFocus.training
              ? <BilVerifiedRecipe>[]
              : await catalog.sourcedRecipes(
                  dietary: const DietaryPreferences(),
                );
          final plan = const BilSmartPlanEngine().generate(
            BilPlanCreationRequest(
              ownerId: 'home-owner',
              planId: 'home-plan',
              startOn: now,
              horizon: horizon,
              focus: focus,
              workoutsPerWeek: focus == BilPlanFocus.nutrition ? 0 : 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              workoutCatalog: choices,
              recipeCatalog: recipes,
              setup: savedSetup,
            ),
            now,
          );
          final reopened = BilSmartPlan.decode(plan.encode());
          expect(reopened.encode(), plan.encode());
          expect(reopened.ownerId, 'home-owner');
          expect(reopened.status, BilPlanStatus.draft);
          expect(reopened.days.length, BilPlanDate.durationDays(horizon, now));
          for (var index = 0; index < reopened.days.length; index++) {
            final day = reopened.days[index];
            expect(
              day.meals.length,
              focus == BilPlanFocus.training
                  ? 0
                  : BilPlanMealSlot.values.length,
            );
            if (day.workout == null) continue;
            expect(focus, isNot(BilPlanFocus.nutrition));
            expect(day.workout!.completed, isFalse);
            if (index > 0) expect(reopened.days[index - 1].workout, isNull);
            final doses = await prescriptions.session(day.workout!);
            expect(doses, hasLength(6));
            expect(doses.map((dose) => dose.sets), everyElement(2));
          }
          if (focus == BilPlanFocus.nutrition) {
            expect(reopened.days.every((day) => day.workout == null), isTrue);
          }
        },
      );
    }
  }

  test('Home cannot bypass adult, medical or recovery gates', () async {
    final savedSetup = setup(BilPlanExperience.beginner);
    final choices = await catalog.homeSessions(savedSetup);
    BilPlanCreationRequest request({
      int frequency = 3,
      bool adult = true,
      bool medical = false,
    }) => BilPlanCreationRequest(
      ownerId: 'home-owner',
      planId: 'home-plan',
      startOn: now,
      horizon: BilPlanHorizon.month,
      focus: BilPlanFocus.training,
      workoutsPerWeek: frequency,
      confirmedPreferences: true,
      adultConfirmed: adult,
      underMedicalReview: medical,
      workoutCatalog: choices,
      recipeCatalog: const [],
      setup: savedSetup,
    );
    expect(
      () => const BilSmartPlanEngine().generate(request(frequency: 4), now),
      throwsStateError,
    );
    expect(
      () => const BilSmartPlanEngine().generate(request(adult: false), now),
      throwsStateError,
    );
    expect(
      () => const BilSmartPlanEngine().generate(request(medical: true), now),
      throwsStateError,
    );
    for (var frequency = 1; frequency <= 3; frequency++) {
      final plan = const BilSmartPlanEngine().generate(
        request(frequency: frequency),
        now,
      );
      expect(
        plan.days.take(7).where((day) => day.workout != null),
        hasLength(frequency),
      );
    }
  });

  test(
    'edited template, movement order or missing release identity cannot inherit trusted Home doses',
    () async {
      final original = (await catalog.homeSessions(
        setup(BilPlanExperience.beginner),
      )).first;
      for (final forged in [
        BilPlanWorkout(
          templateId: original.id,
          exerciseIds: original.exerciseIds.reversed,
          minutes: 40,
        ),
        BilPlanWorkout(
          templateId: '${original.id}-forged',
          exerciseIds: original.exerciseIds,
          minutes: 40,
        ),
        BilPlanWorkout(
          templateId: original.id,
          exerciseIds: ['foreign-exercise'],
          minutes: 40,
        ),
      ]) {
        await expectLater(prescriptions.session(forged), throwsStateError);
        await expectLater(prescriptions.warmup(forged), throwsStateError);
      }
      await expectLater(
        prescriptions.homeWorkouts(
          setup: setup(BilPlanExperience.beginner),
          equipmentByExercise: const {},
        ),
        throwsStateError,
      );
      expect(
        await prescriptions.session(
          BilPlanWorkout(
            templateId: 'home-recovery-beginner-0',
            exerciseIds: ['recovery-beginner-ankle-circles-gentle'],
            minutes: 25,
          ),
        ),
        isEmpty,
      );
    },
  );

  test(
    'Home warm-up has NHS doses and only exact matched video IDs; no diary completion',
    () async {
      final session = (await catalog.homeSessions(
        setup(BilPlanExperience.beginner),
      )).first;
      final saved = workout(session);
      final preparation = await prescriptions.warmup(saved);
      expect(preparation, hasLength(5));
      expect(
        preparation.where((step) => step.exerciseId != null),
        hasLength(3),
      );
      expect(
        preparation.first.exerciseId,
        'cardio-low-impact-march-in-place-steady',
      );
      expect(preparation.first.dose, startsWith('3 minutes;'));
      expect(
        preparation[1].dose,
        startsWith('60 alternating heel digs over 60 seconds;'),
      );
      expect(
        preparation[2].dose,
        startsWith('30 alternating lifts over 30 seconds,'),
      );
      expect(preparation[3].exerciseId, isNull);
      expect(preparation[4].exerciseId, isNull);
      expect(
        preparation.every(
          (step) => step.doseAr != null && step.titleAr != null,
        ),
        isTrue,
      );
      expect(saved.completed, isFalse);
      expect(saved.exerciseIds, session.exerciseIds);
    },
  );

  test(
    'all six Gym sessions preserve the original source warm-up group and dose verbatim',
    () async {
      final source =
          jsonDecode(
                File(
                  'artifacts/workout_media/gym_training_plan_source_v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final choices = await catalog.gymSessions(sessionMinutes: 40);
      expect(choices, hasLength(6));
      for (final choice in choices) {
        final group = choice.id.split('-').first;
        final expected = (source['warmups'][group] as List).cast<Map>();
        final actual = await prescriptions.warmup(workout(choice));
        expect(
          actual.map((row) => row.title),
          expected.map((row) => row['movement']),
        );
        expect(
          actual.map((row) => row.dose),
          expected.map((row) => row['dose']),
        );
        expect(actual.every((row) => row.exerciseId != null), isTrue);
      }
    },
  );

  test(
    'travel revisions retain civil recovery days, plan-week frequency, approval history and the original plan',
    () async {
      final savedSetup = setup(BilPlanExperience.beginner);
      final original = const BilSmartPlanEngine()
          .generate(
            BilPlanCreationRequest(
              ownerId: 'home-owner',
              planId: 'home-recovery',
              startOn: now,
              horizon: BilPlanHorizon.month,
              focus: BilPlanFocus.training,
              workoutsPerWeek: 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              workoutCatalog: await catalog.homeSessions(savedSetup),
              recipeCatalog: const [],
              setup: savedSetup,
            ),
            now,
          )
          .withStatus(BilPlanStatus.active, now);
      final before = original.encode();
      final from = now.add(const Duration(days: 4));
      final safe = now.add(const Duration(days: 5));
      expect(original.recoveryAllowsMove(date: from, target: safe), isTrue);
      final preview = original.rescheduleWorkout(
        date: from,
        target: safe,
        now: now,
        reason: BilPlanChangeReason.travel,
      );
      expect(preview.hasSafeHomeRecovery, isTrue);
      expect(preview.revision, original.revision + 1);
      expect(preview.changes.first.reason, BilPlanChangeReason.travel);
      expect(original.encode(), before);
      for (final pair in [(4, 6), (0, 1), (0, 27)]) {
        final source = now.add(Duration(days: pair.$1));
        final target = now.add(Duration(days: pair.$2));
        expect(
          original.recoveryAllowsMove(date: source, target: target),
          isFalse,
        );
        expect(
          () => original.rescheduleWorkout(
            date: source,
            target: target,
            now: now,
            reason: BilPlanChangeReason.travel,
          ),
          throwsStateError,
        );
      }
      await catalog.validate(preview, const DietaryPreferences());
      final wire = original.toJson();
      final days = (wire['days'] as List).cast<Map<String, Object?>>();
      days[1]['workout'] = days[0]['workout'];
      days[0]['workout'] = null;
      final unsafe = BilSmartPlan.decode(jsonEncode(wire));
      expect(unsafe.hasSafeHomeRecovery, isFalse);
      await expectLater(
        catalog.validate(unsafe, const DietaryPreferences()),
        throwsStateError,
      );
      expect(original.encode(), before);
    },
  );
}
