import 'dart:convert';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_review.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bil_smart_plan_engine_test.dart' show buildRequest;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 22);
  test(
    'Home plan uses released movements and only explicitly available equipment',
    () async {
      final setup = BilPlanSetup(
        environment: BilPlanEnvironment.home,
        experience: BilPlanExperience.beginner,
        sessionMinutes: 25,
        equipment: const {'none'},
        preferredTime: '18:00',
        goalId: 'saved-goal',
      );
      const catalog = BilSmartPlanCatalog();
      final sessions = await catalog.homeSessions(setup);
      expect(sessions, isNotEmpty);
      final discovery = const WorkoutDiscoveryCatalogRepository().parse(
        await rootBundle.loadString(
          WorkoutDiscoveryCatalogRepository.assetPath,
        ),
        await const WorkoutReleaseCatalogRepository().load(),
      );
      for (final session in sessions) {
        expect(session.exerciseIds.length, lessThanOrEqualTo(4));
        for (final id in session.exerciseIds) {
          final item = discovery.singleWhere(
            (item) => item.id == id && item.releaseBundleId == 'home-training',
          );
          expect(item.equipment, everyElement('none'));
        }
      }
      for (final horizon in BilPlanHorizon.values) {
        final plan = const BilSmartPlanEngine().generate(
          BilPlanCreationRequest(
            ownerId: 'owner-setup',
            planId: 'setup-plan',
            startOn: now,
            horizon: horizon,
            focus: BilPlanFocus.training,
            workoutsPerWeek: 3,
            confirmedPreferences: true,
            adultConfirmed: true,
            workoutCatalog: sessions,
            recipeCatalog: const [],
            setup: setup,
          ),
          now,
        );
        final reopened = BilSmartPlan.decode(
          plan.encode(),
        ).withStatus(BilPlanStatus.active, now);
        expect(reopened.setup!.preferredTime, '18:00');
        expect(reopened.setup!.goalId, 'saved-goal');
        expect(
          reopened.days
              .where((day) => day.workout != null)
              .every((day) => day.workout!.minutes == 25),
          isTrue,
        );
        expect(reopened.previousVersion()!.encode(), plan.encode());
      }
    },
  );
  test(
    'setup rejects unsupported equipment environment dose and malformed times',
    () {
      final valid = BilPlanSetup(
        environment: BilPlanEnvironment.home,
        experience: BilPlanExperience.regular,
        sessionMinutes: 30,
        equipment: const {'none'},
      ).toJson();
      for (final bad in [
        {...valid, 'sessionMinutes': 0},
        {...valid, 'sessionMinutes': 30.5},
        {
          ...valid,
          'equipment': ['none', 'none'],
        },
        {
          ...valid,
          'equipment': ['unsafe-injected-equipment'],
        },
        {...valid, 'preferredTime': '24:30'},
        {...valid, 'preferredTime': null},
        {...valid, 'environment': 'gym'},
        {...valid, 'ownerId': 'another-owner'},
        {...valid, 'goalId': 'another/goal'},
      ]) {
        expect(
          () => BilPlanSetup.fromJson(Map<String, dynamic>.from(bad)),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'weekly review does not call unrecorded activity a missed workout or count future days',
    () {
      final active = const BilSmartPlanEngine()
          .generate(buildRequest(), now)
          .withStatus(BilPlanStatus.active, now);
      final today = BilSmartPlanWeekReview(active, now);
      expect(today.scheduled, 1);
      expect(today.dueToday, 1);
      expect(today.unconfirmedPast, 0);
      final tomorrow = BilSmartPlanWeekReview(
        active,
        now.add(const Duration(days: 1)),
      );
      expect(tomorrow.unconfirmedPast, 1);
      expect(tomorrow.confirmed, 0);
      final done = active.recordWorkout(date: now, now: now, completed: true);
      expect(BilSmartPlanWeekReview(done, now).confirmed, 1);
      expect(active.onDate(now)!.workout!.completed, isFalse);
    },
  );
  test('unknown setup fields cannot be dropped silently when restoring', () {
    final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
    expect(
      () => BilSmartPlan.decode(jsonEncode({...plan.toJson(), 'setup': null})),
      throwsFormatException,
    );
    expect(
      () => BilSmartPlan.decode(
        jsonEncode({...plan.toJson(), 'futureUnapprovedHealthData': {}}),
      ),
      throwsFormatException,
    );
  });
}
