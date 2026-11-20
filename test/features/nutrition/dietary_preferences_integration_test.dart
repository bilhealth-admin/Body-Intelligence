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
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test(
      'recipe search screens verified ingredients and unknown summaries',
      () async {
        final recipes = RecipeReleaseRepository();
        final index = await recipes.loadIndex();
        final safe = index.singleWhere((r) => r.id == 'bean-corn-salad');
        final walnuts = index.singleWhere((r) => r.id == 'aji-gallina-ligero');
        const unverified = RecipeCatalogSummary(
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
        expect(safe.dietaryEvidence.complete, isTrue);
        expect(safe.isCompatibleWith(veganNutFree), isTrue);
        expect(unverified.dietaryEvidence.complete, isFalse);
        expect(unverified.isCompatibleWith(veganNutFree), isFalse);
        const treeNutOnly = DietaryPreferences(
          allergens: {DietaryAllergen.treeNut},
        );
        expect(walnuts.dietaryEvidence.allergens, contains('treeNut'));
        expect(walnuts.isCompatibleWith(treeNutOnly), isFalse);
        expect(
          (await recipes.loadDetail(
            walnuts,
          )).dietaryEvidence.allows(treeNutOnly),
          isFalse,
        );
      },
    );

    test(
      'ingredient exclusions match plural phrases and preserve unresolved restrictions',
      () {
        bool allows(String exclusion, String ingredient) =>
            DietaryCompatibility.allows(
              preferences: DietaryPreferences(excludedIngredients: {exclusion}),
              ingredients: [ingredient],
            );
        expect(allows('tomatoes', 'raw tomato'), isFalse);
        expect(allows('strawberries', 'fresh strawberry'), isFalse);
        expect(allows('oat brans', 'raw oat bran'), isFalse);
        expect(allows('oat brans', 'whole oats'), isTrue);
        expect(allows('شوفان', 'raw oat bran'), isFalse);
        expect(allows('شوفان', 'spinach'), isTrue);
        expect(allows('مكوّن غير مترجم', 'spinach'), isFalse);
      },
    );

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
