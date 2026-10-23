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
    'all 36 real Home client schedules validate and serialize for independent authenticated RPC probes',
    () async {
      const catalog = BilSmartPlanCatalog();
      final recipes = await catalog.sourcedRecipes(
        dietary: const DietaryPreferences(),
      );
      final now = DateTime.utc(2026, 10, 23);
      for (final level in BilPlanExperience.values) {
        final setup = BilPlanSetup(
          environment: BilPlanEnvironment.home,
          experience: level,
          sessionMinutes: 45,
          equipment: const {'none', 'dumbbell pair', 'kettlebell single'},
          preferredTime: '18:00',
        );
        final workouts = await catalog.homeSessions(setup);
        final cases = <Map<String, Object?>>[];
        for (final horizon in BilPlanHorizon.values) {
          for (final focus in BilPlanFocus.values) {
            final plan = const BilSmartPlanEngine().generate(
              BilPlanCreationRequest(
                ownerId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
                planId: 'home-${level.name}-${horizon.name}-${focus.name}',
                startOn: now,
                horizon: horizon,
                focus: focus,
                workoutsPerWeek: focus == BilPlanFocus.nutrition ? 0 : 3,
                confirmedPreferences: true,
                adultConfirmed: true,
                workoutCatalog: workouts,
                recipeCatalog: recipes,
                setup: focus == BilPlanFocus.nutrition ? null : setup,
              ),
              now,
            );
            await catalog.validate(plan, const DietaryPreferences());
            expect(BilSmartPlan.decode(plan.encode()).encode(), plan.encode());
            expect(plan.hasSafeHomeRecovery, isTrue);
            for (final day in plan.days.where((day) => day.workout != null)) {
              expect(
                await const BilSmartPlanPrescriptions().session(day.workout!),
                hasLength(6),
              );
              expect(
                await const BilSmartPlanPrescriptions().warmup(day.workout!),
                hasLength(5),
              );
            }
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
        final output = File(
          'build/qa_live_home_smart_plan_${level.name}_fixtures.json',
        );
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
        expect(readback['cases'], hasLength(12));
        expect(
          BilSmartPlan.decode(jsonEncode(readback['completed'])).changes.length,
          2,
        );
        expect(active.days.first.workout!.completed, isFalse);
        expect(completed.days.first.workout!.completed, isTrue);
      }
    },
  );
}
