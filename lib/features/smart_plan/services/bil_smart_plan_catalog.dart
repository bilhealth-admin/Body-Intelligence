import 'package:flutter/services.dart';

import '../../meal_planner/domain/meal_plan.dart';
import '../../meal_planner/services/meal_plan_engine.dart';
import '../../nutrition/domain/dietary_preferences.dart';
import '../../wellness/repositories/gym_six_month_plan_repository.dart';
import '../../wellness/repositories/workout_release_catalog_repository.dart';
import '../../wellness/repositories/workout_discovery_catalog_repository.dart';
import '../../wellness/domain/workout_release_catalog_item.dart';
import '../../wellness/repositories/recipe_release_repository.dart';
import '../../recipe_import/domain/recipe_ingredient_evidence.dart';
import '../domain/bil_smart_plan.dart';
import '../domain/bil_smart_plan_engine.dart';
import '../domain/bil_smart_plan_nutrition.dart';
import 'bil_smart_plan_prescriptions.dart';

/// Reuse released workout and recipe identities. Never invent videos or food.
final class BilSmartPlanCatalog {
  const BilSmartPlanCatalog();
  static final _recipeRepository = RecipeReleaseRepository();
  static final _recipeTitles = <String, RecipeCatalogSummary>{};

  /// Source-backed strength practice over existing approved Home movements.
  Future<List<BilVerifiedWorkout>> homeSessions(BilPlanSetup setup) async {
    final released = await const WorkoutReleaseCatalogRepository().load();
    final discovery = const WorkoutDiscoveryCatalogRepository().parse(
      await rootBundle.loadString(WorkoutDiscoveryCatalogRepository.assetPath),
      released,
    );
    return const BilSmartPlanPrescriptions().homeWorkouts(
      setup: setup,
      equipmentByExercise: {
        for (final item in discovery.where(
          (item) => item.releaseBundleId == 'home-training',
        ))
          item.id: item.equipment.toSet(),
      },
    );
  }

  /// Hash-verified BIL recipe records, including ingredient-level exclusions.
  /// Keep a small diverse choice per slot; never send the complete catalog to AI.
  Future<List<BilVerifiedRecipe>> sourcedRecipes({
    required DietaryPreferences dietary,
    MealPlanPreferences preferences = const MealPlanPreferences(),
  }) async {
    final index = await _recipeRepository.loadIndex();
    final result = <BilVerifiedRecipe>[];
    for (final summary in index) {
      if (summary.totalMinutes > preferences.maxMinutes ||
          !summary.isCompatibleWith(dietary)) {
        continue;
      }
      if (preferences.diet == MealPlanDiet.vegetarian &&
          !summary.dietTags.any(
            (tag) => const {'vegetarian', 'vegan'}.contains(tag),
          )) {
        continue;
      }
      if (preferences.diet == MealPlanDiet.highProtein &&
          !summary.dietTags.any(
            (tag) => const {'high-protein', 'high_protein'}.contains(tag),
          )) {
        continue;
      }
      final slots = BilPlanMealSlot.values
          .where(
            (slot) =>
                summary.mealTypes.contains(slot.name) &&
                result.where((entry) => entry.slot == slot).length < 12,
          )
          .toList(growable: false);
      if (slots.isEmpty) continue;
      final detail = await _recipeRepository.loadDetail(summary);
      if (!_allowsRecipeDetail(detail, dietary)) continue;
      _recipeTitles[summary.id] = summary;
      final values = sourcedNutrition(detail);
      result.addAll(
        slots.map(
          (slot) => BilVerifiedRecipe(
            id: summary.id,
            slot: slot,
            nutrition: values == null
                ? null
                : BilPlanNutrients(
                    values: values,
                    source: 'verified_recipe:${summary.id}',
                  ),
          ),
        ),
      );
      if (BilPlanMealSlot.values.every(
        (slot) => result.where((entry) => entry.slot == slot).length >= 12,
      )) {
        break;
      }
    }
    return List.unmodifiable(result);
  }

  bool _allowsRecipeDetail(
    RecipeCatalogDetail detail,
    DietaryPreferences dietary,
  ) => DietaryCompatibility.allows(
    preferences: dietary,
    dietTags: detail.summary.dietTags,
    allergens: detail.summary.allergens,
    ingredients: (detail.record['ingredients'] as List).whereType<Map>().map(
      (ingredient) => '${ingredient['itemId']}',
    ),
  );

  Future<RecipeCatalogDetail?> recipeDetail(
    String id,
    DietaryPreferences dietary,
  ) async {
    final summary = (await _recipeRepository.loadIndex())
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (summary == null) return null;
    final detail = await _recipeRepository.loadDetail(summary);
    if (!_allowsRecipeDetail(detail, dietary)) {
      throw StateError('smart_plan_dietary_boundary_changed');
    }
    _recipeTitles[summary.id] = summary;
    return detail;
  }

  /// No static planner estimate is promoted to source-verified nutrition.
  Map<String, double>? sourcedNutrition(RecipeCatalogDetail detail) {
    if (RecipeIngredientEvidence.recordNeedsReview(detail.record)) return null;
    final nutrition = detail.record['nutrition'];
    if (nutrition is! Map ||
        nutrition['sourceRefs'] is! List ||
        (nutrition['sourceRefs'] as List).isEmpty ||
        nutrition['perServing'] is! Map) {
      return null;
    }
    final source = nutrition['perServing'] as Map;
    final values = <String, double>{};
    for (final key in const ['kcal', 'proteinG', 'carbohydrateG', 'fatG']) {
      final value = source[key];
      if (value is! num || !value.isFinite || value < 0) return null;
      values[key] = value.toDouble();
    }
    return Map.unmodifiable(values);
  }

  Future<List<BilVerifiedWorkout>> gymSessions({
    required int sessionMinutes,
  }) async {
    final repository = const GymSixMonthPlanRepository();
    // Cached asset loads can complete synchronously; don't mix differently
    // typed SynchronousFutures in Future.wait.
    final source = await rootBundle.loadString(
      GymSixMonthPlanRepository.artifactPath,
    );
    final manifest = await rootBundle.load(
      GymSixMonthPlanRepository.releaseManifestPath,
    );
    final plan = repository.parse(
      source,
      releaseManifestBytes: manifest.buffer.asUint8List(
        manifest.offsetInBytes,
        manifest.lengthInBytes,
      ),
    );
    final catalog = await const WorkoutReleaseCatalogRepository().load();
    final approved = catalog
        .where(
          (item) => item.availability == WorkoutReleaseAvailability.approved,
        )
        .map((item) => item.exerciseId)
        .toSet();
    final available = <BilVerifiedWorkout>[];
    for (final session in plan.sessions) {
      if (!session.exerciseIds.every(approved.contains)) continue;
      final restFloor = await const BilSmartPlanPrescriptions()
          .minimumRestSeconds(session.id);
      if (sessionMinutes * 60 <= restFloor) continue;
      available.add(
        BilVerifiedWorkout(
          id: session.id,
          exerciseIds: session.exerciseIds,
          minutes: sessionMinutes,
        ),
      );
    }
    return List.unmodifiable(available);
  }

  /// Restrict suggestions by the member's saved food selection boundaries.
  List<BilVerifiedRecipe> recipes({
    required DietaryPreferences dietary,
    MealPlanPreferences preferences = const MealPlanPreferences(),
  }) {
    final rows = <BilVerifiedRecipe>[];
    for (final recipe in plannerRecipes) {
      if (recipe.minutes > preferences.maxMinutes ||
          (preferences.budget == MealPlanBudget.value &&
              recipe.cost != MealPlanBudget.value)) {
        continue;
      }
      if (!DietaryCompatibility.allows(
        preferences: dietary,
        dietTags: recipe.dietTags,
        allergens: recipe.allergens,
        ingredients: recipe.ingredients.keys,
      )) {
        continue;
      }
      if (preferences.diet == MealPlanDiet.vegetarian && !recipe.vegetarian) {
        continue;
      }
      if (preferences.diet == MealPlanDiet.highProtein && !recipe.highProtein) {
        continue;
      }
      final slot = switch (recipe.meal.toLowerCase()) {
        'breakfast' => BilPlanMealSlot.breakfast,
        'lunch' => BilPlanMealSlot.lunch,
        'dinner' => BilPlanMealSlot.dinner,
        _ => null,
      };
      if (slot != null) rows.add(BilVerifiedRecipe(id: recipe.id, slot: slot));
    }
    return List.unmodifiable(rows);
  }

  Future<void> validate(BilSmartPlan plan, DietaryPreferences dietary) async {
    if (!plan.hasSafeHomeRecovery) {
      throw StateError('home_strength_recovery_days_required');
    }
    final sessions = plan.focus == BilPlanFocus.nutrition
        ? <BilVerifiedWorkout>[]
        : plan.setup?.environment == BilPlanEnvironment.home
        ? await homeSessions(plan.setup!)
        : plan.days.every((day) => day.workout == null)
        ? <BilVerifiedWorkout>[]
        : await gymSessions(
            sessionMinutes: plan.days
                .firstWhere((day) => day.workout != null)
                .workout!
                .minutes,
          );
    final allowedRecipes = recipes(dietary: dietary);
    final checked = <String>{};
    for (final day in plan.days) {
      final workout = day.workout;
      if (workout != null &&
          !sessions.any(
            (session) =>
                session.id == workout.templateId &&
                session.exerciseIds.join('|') == workout.exerciseIds.join('|'),
          )) {
        throw StateError('smart_plan_catalog_changed');
      }
      for (final meal in day.meals) {
        if (!allowedRecipes.any(
          (recipe) => recipe.id == meal.recipeId && recipe.slot == meal.slot,
        )) {
          final key = '${meal.slot.name}:${meal.recipeId}';
          if (!checked.contains(key)) {
            final detail = await recipeDetail(meal.recipeId, dietary);
            if (detail == null ||
                !detail.summary.mealTypes.contains(meal.slot.name)) {
              throw StateError('smart_plan_dietary_boundary_changed');
            }
            checked.add(key);
          }
        }
      }
    }
  }

  String recipeTitle(String id, {String locale = 'en'}) =>
      _recipeTitles[id]?.titleFor(locale) ?? recipeById(id)?.title ?? id;

  Future<String> exerciseRoute(
    String id, {
    String bundleId = 'gym-six-month',
  }) async {
    final catalog = await const WorkoutReleaseCatalogRepository().load();
    final matches = catalog.where(
      (record) =>
          record.exerciseId == id &&
          record.bundleId == bundleId &&
          record.canPlay,
    );
    if (matches.isEmpty) throw StateError('smart_plan_catalog_changed');
    return '/wellness/workouts/routines?item=${Uri.encodeQueryComponent(matches.first.releaseKey)}';
  }

  /// Readable metadata from approved release identifiers; never an invented
  /// exercise or a promise that a video is locally installed.
  String exerciseTitle(String id) {
    final words = id
        .replaceAll(RegExp(r'-technique$'), '')
        .replaceAll('-', ' ')
        .trim()
        .split(RegExp(r'\s+'));
    return words
        .map(
          (word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }
}
