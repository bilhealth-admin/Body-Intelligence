import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../meal_planner/domain/meal_plan.dart';
import '../../meal_planner/services/meal_plan_engine.dart';
import '../../nutrition/domain/dietary_preferences.dart';
import '../../wellness/repositories/gym_six_month_plan_repository.dart';
import '../../wellness/repositories/workout_release_catalog_repository.dart';
import '../../wellness/domain/workout_release_catalog_item.dart';
import '../domain/bil_smart_plan.dart';
import '../domain/bil_smart_plan_engine.dart';

/// Reuse released workout and recipe identities. Never invent videos or food.
final class BilSmartPlanCatalog {
  const BilSmartPlanCatalog();

  Future<List<BilVerifiedWorkout>> gymSessions() async {
    final repository = const GymSixMonthPlanRepository();
    final records = await Future.wait([
      rootBundle.loadString(GymSixMonthPlanRepository.artifactPath),
      rootBundle.load(GymSixMonthPlanRepository.releaseManifestPath),
    ]);
    final source = records[0] as String;
    final manifest = records[1] as ByteData;
    final plan = repository.parse(source,
        releaseManifestBytes: manifest.buffer.asUint8List(
          manifest.offsetInBytes, manifest.lengthInBytes));
    final catalog = await const WorkoutReleaseCatalogRepository().load();
    final approved = catalog.where((item) =>
        item.availability == WorkoutReleaseAvailability.approved)
        .map((item) => item.exerciseId).toSet();
    return List.unmodifiable(plan.sessions
        .where((session) => session.exerciseIds.every(approved.contains))
        .map((session) => BilVerifiedWorkout(
          id: session.id,
          exerciseIds: session.exerciseIds,
          minutes: 35,
        )));
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
              recipe.cost != MealPlanBudget.value)) continue;
      if (!DietaryCompatibility.allows(
        preferences: dietary,
        dietTags: recipe.dietTags,
        allergens: recipe.allergens,
        ingredients: recipe.ingredients.keys,
      )) continue;
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
      if (slot != null) rows.add(BilVerifiedRecipe(
        id: recipe.id, slot: slot,
      ));
    }
    return List.unmodifiable(rows);
  }

  String recipeTitle(String id) => recipeById(id)?.title ?? id;

  /// Readable metadata from approved release identifiers; never an invented
  /// exercise or a promise that a video is locally installed.
  String exerciseTitle(String id) {
    final words = id.replaceAll(RegExp(r'-technique
), '')
        .replaceAll('-', ' ').trim().split(RegExp(r'\s+'));
    return words.map((word) => word.isEmpty ? word :
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
