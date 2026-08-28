import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/engine/body_profile.dart';
import 'package:body_intelligence_log/engine/plan_engine.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/meal_planner/services/meal_plan_engine.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';

void main() {
  group('dietary preference persistence', () {
    late AppDatabase database;
    late PreferencesRepository preferences;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      preferences = PreferencesRepository(database);
    });

    tearDown(() => database.close());

    test('migrates legacy approach and saves one versioned contract', () async {
      await preferences.set('dietApproach', 'low_carb');
      final repository = DietaryPreferencesRepository(preferences);

      expect((await repository.read()).approach, 'low_carb');

      const saved = DietaryPreferences(
        pattern: DietaryPattern.vegan,
        approach: 'high_protein',
        requirements: {DietaryRequirement.glutenFree},
        allergens: {DietaryAllergen.sesame},
      );
      await repository.save(saved);

      final restored = await repository.read();
      expect(restored.pattern, DietaryPattern.vegan);
      expect(restored.requirements, {DietaryRequirement.glutenFree});
      expect(restored.allergens, {DietaryAllergen.sesame});
      expect(await preferences.get('dietApproach'), 'high_protein');
    });

    test('malformed payload fails closed to a neutral legacy value', () {
      final value = DietaryPreferences.decode(
        '{broken',
        legacyApproach: 'keto',
      );
      expect(value.pattern, DietaryPattern.omnivore);
      expect(value.approach, 'keto');
      expect(value.allergens, isEmpty);
    });
  });

  group('food-selection engines', () {
    const veganNutFree = DietaryPreferences(
      pattern: DietaryPattern.vegan,
      allergens: {DietaryAllergen.treeNut},
    );

    test('meal planner never falls back to an incompatible recipe', () {
      final plan = const MealPlanEngine().generate(
        const MealPlanPreferences(),
        dietaryPreferences: veganNutFree,
      );
      expect(plan.meals, isNotEmpty);
      for (final meal in plan.meals) {
        final recipe = recipeById(meal.recipeId)!;
        expect(recipe.dietTags, contains('vegan'));
        expect(recipe.allergens, isNot(contains('treeNut')));
      }

      final unsupported = const MealPlanEngine().generate(
        const MealPlanPreferences(),
        dietaryPreferences: const DietaryPreferences(
          requirements: {DietaryRequirement.kosher},
        ),
      );
      expect(unsupported.meals, isEmpty);
    });

    test('recipe search compatibility uses catalog tags and allergens', () {
      const safe = RecipeCatalogSummary(
        id: 'safe',
        fingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        shard: 0,
        ordinal: 0,
        primaryLocale: 'en',
        title: 'Safe bowl',
        localizedTitles: {'en': 'Safe bowl'},
        totalMinutes: 10,
        mealTypes: ['lunch'],
        dietTags: ['vegan', 'gluten_free'],
        allergens: [],
        imageStatus: 'placeholder',
      );
      const unsafe = RecipeCatalogSummary(
        id: 'unsafe',
        fingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        shard: 0,
        ordinal: 1,
        primaryLocale: 'en',
        title: 'Nut bowl',
        localizedTitles: {'en': 'Nut bowl'},
        totalMinutes: 10,
        mealTypes: ['lunch'],
        dietTags: ['vegan', 'gluten_free'],
        allergens: ['tree_nuts'],
        imageStatus: 'placeholder',
      );

      expect(safe.isCompatibleWith(veganNutFree), isTrue);
      expect(unsafe.isCompatibleWith(veganNutFree), isFalse);
    });

    test('macros stay scientific while the selection boundary is explicit', () {
      const profile = BodyProfile(
        age: 35,
        gender: 'female',
        height: 165,
        weight: 70,
        targetWeight: 65,
        activityLevel: 'moderate',
        exercises: true,
        goalType: 'lose',
      );
      final neutral = PlanEngine.recommend(profile);
      final constrained = PlanEngine.recommend(
        profile,
        dietaryPreferences: veganNutFree,
      );
      expect(constrained.targets.calories, neutral.targets.calories);
      expect(constrained.targets.protein, neutral.targets.protein);
      expect(
        constrained.assumptions,
        contains(contains('food-selection constraints')),
      );
    });
  });
}
