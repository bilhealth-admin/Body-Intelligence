import 'dart:convert';
import 'dart:io';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all twelve real client schedules serialize into strict live RPC fixtures',
    () async {
      const catalog = BilSmartPlanCatalog();
      final workouts = await catalog.gymSessions(sessionMinutes: 45);
      final recipes = await catalog.sourcedRecipes(
        dietary: const DietaryPreferences(),
      );
      final phases = await const BilSmartPlanPrescriptions().phases();
      final now = DateTime.utc(2026, 10, 23);
      final cases = <Map<String, Object?>>[];
      for (final horizon in BilPlanHorizon.values) {
        for (final focus in BilPlanFocus.values) {
          final plan = const BilSmartPlanEngine().generate(
            BilPlanCreationRequest(
              ownerId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
              planId: 'fixture-${horizon.name}-${focus.name}',
              startOn: now,
              horizon: horizon,
              focus: focus,
              workoutsPerWeek: focus == BilPlanFocus.nutrition ? 0 : 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              workoutCatalog: workouts,
              recipeCatalog: recipes,
              setup: focus == BilPlanFocus.nutrition
                  ? null
                  : BilPlanSetup(
                      environment: BilPlanEnvironment.gym,
                      experience: BilPlanExperience.beginner,
                      sessionMinutes: 45,
                      equipment: const ['gym'],
                      preferredTime: '18:00',
                    ),
              phases: focus == BilPlanFocus.nutrition ? const [] : phases,
            ),
            now,
          );
          await catalog.validate(plan, const DietaryPreferences());
          expect(BilSmartPlan.decode(plan.encode()).encode(), plan.encode());
          cases.add({
            'horizon': horizon.name,
            'focus': focus.name,
            'draft': plan.toJson(),
          });
        }
      }
      final last = BilSmartPlan.decode(jsonEncode(cases.last['draft']));
      final active = last.withStatus(
        BilPlanStatus.active,
        now.add(const Duration(minutes: 1)),
      );
      final completed = active.recordWorkout(
        date: now,
        now: now.add(const Duration(minutes: 2)),
        completed: true,
      );
      final output = File('build/qa_live_smart_plan_fixtures.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        jsonEncode({
          'schema': 'bil.smart-plan.live-fixtures.v1',
          'cases': cases,
          'active': active.toJson(),
          'completed': completed.toJson(),
        }),
      );
      final readback = jsonDecode(await output.readAsString()) as Map;
      expect((readback['cases'] as List).length, 12);
      expect(
        BilSmartPlan.decode(jsonEncode(readback['completed'])).changes.length,
        2,
      );
    },
  );
}
