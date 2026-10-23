import 'package:body_intelligence_log/features/meal_planner/services/meal_plan_engine.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real gym artifact and release manifests resolve only approved exercise IDs',
    () async {
      final sessions = await const BilSmartPlanCatalog().gymSessions(
        sessionMinutes: 35,
      );
      expect(sessions, isNotEmpty);
      final approved = (await const WorkoutReleaseCatalogRepository().load())
          .where((record) => record.canPlay)
          .map((record) => record.exerciseId)
          .toSet();
      expect(
        sessions.every(
          (session) => session.exerciseIds.every(approved.contains),
        ),
        isTrue,
      );
    },
  );
  test(
    'source-backed recipe choices cover every meal slot with diversity and traceable nutrients',
    () async {
      const catalog = BilSmartPlanCatalog();
      const dietary = DietaryPreferences();
      final choices = await catalog.sourcedRecipes(dietary: dietary);
      for (final slot in BilPlanMealSlot.values) {
        final ids = choices
            .where((item) => item.slot == slot)
            .map((item) => item.id)
            .toSet();
        expect(ids.length, greaterThan(1), reason: slot.name);
        expect(ids.length, lessThanOrEqualTo(12));
        final detail = (await catalog.recipeDetail(ids.first, dietary))!;
        expect(detail.summary.mealTypes, contains(slot.name));
        expect(detail.record['contentFingerprint'], detail.summary.fingerprint);
        final facts = catalog.sourcedNutrition(detail);
        if (facts != null) {
          expect(
            facts['kcal'],
            (detail.record['nutrition'] as Map)['perServing']['kcal'],
          );
          expect((detail.record['nutrition'] as Map)['sourceRefs'], isNotEmpty);
        }
      }
      final workouts = await catalog.gymSessions(sessionMinutes: 35);
      for (final horizon in BilPlanHorizon.values) {
        for (final focus in BilPlanFocus.values) {
          final plan = const BilSmartPlanEngine().generate(
            BilPlanCreationRequest(
              ownerId: 'catalog-owner',
              planId: 'catalog-plan',
              startOn: DateTime(2026, 10, 23),
              horizon: horizon,
              focus: focus,
              workoutsPerWeek: focus == BilPlanFocus.nutrition ? 0 : 3,
              confirmedPreferences: true,
              adultConfirmed: true,
              workoutCatalog: workouts,
              recipeCatalog: choices,
            ),
            DateTime.utc(2026, 10, 23),
          );
          await catalog.validate(BilSmartPlan.decode(plan.encode()), dietary);
          expect(
            plan.days.where((day) => day.workout?.completed == true),
            isEmpty,
          );
        }
      }
    },
  );
  test(
    'ingredient exclusions are checked in source details before any recipe is proposed',
    () async {
      const catalog = BilSmartPlanCatalog();
      final dietary = DietaryPreferences(
        allergens: const {DietaryAllergen.milk, DietaryAllergen.peanut},
        excludedIngredients: const {'chicken', 'beef'},
      );
      final choices = await catalog.sourcedRecipes(dietary: dietary);
      expect(choices, isNotEmpty);
      for (final id in choices.map((item) => item.id).toSet()) {
        final detail = (await catalog.recipeDetail(id, dietary))!;
        expect(
          DietaryCompatibility.allows(
            preferences: dietary,
            dietTags: detail.summary.dietTags,
            allergens: detail.summary.allergens,
            ingredients: (detail.record['ingredients'] as List).cast<Map>().map(
              (item) => item['itemId'] as String,
            ),
          ),
          isTrue,
        );
      }
    },
  );
  test(
    'bundle-scoped movement routing does not open a Home duplicate for a Gym session',
    () async {
      final records = await const WorkoutReleaseCatalogRepository().load();
      final gymIds = records
          .where((row) => row.bundleId == 'gym-six-month' && row.canPlay)
          .map((row) => row.exerciseId)
          .toSet();
      final duplicate = records.firstWhere(
        (row) =>
            row.bundleId == 'home-training' && gymIds.contains(row.exerciseId),
      );
      final route = await const BilSmartPlanCatalog().exerciseRoute(
        duplicate.exerciseId,
      );
      expect(
        Uri.parse(route).queryParameters['item'],
        'gym-six-month:${duplicate.exerciseId}',
      );
      final home = await const BilSmartPlanCatalog().exerciseRoute(
        duplicate.exerciseId,
        bundleId: 'home-training',
      );
      expect(Uri.parse(home).queryParameters['item'], duplicate.releaseKey);
    },
  );
  test(
    'real saved dietary constraints take precedence for every proposed recipe',
    () {
      final dietary = DietaryPreferences(
        allergens: const {DietaryAllergen.milk, DietaryAllergen.wheat},
        excludedIngredients: const {'chicken'},
      );
      final recipes = const BilSmartPlanCatalog().recipes(dietary: dietary);
      for (final row in recipes) {
        final recipe = recipeById(row.id)!;
        expect(
          DietaryCompatibility.allows(
            preferences: dietary,
            dietTags: recipe.dietTags,
            allergens: recipe.allergens,
            ingredients: recipe.ingredients.keys,
          ),
          isTrue,
        );
      }
      expect(
        const BilSmartPlanCatalog()
            .recipes(dietary: const DietaryPreferences())
            .map((recipe) => recipe.slot)
            .toSet(),
        containsAll(BilPlanMealSlot.values),
      );
    },
  );
}
