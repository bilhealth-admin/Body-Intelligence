import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/meal_planner/services/meal_plan_engine.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecipeFixtureBundle extends CachingAssetBundle {
  _RecipeFixtureBundle(this.overrides);

  final Map<String, ByteData> overrides;

  @override
  Future<ByteData> load(String key) async =>
      overrides[key] ?? await rootBundle.load(key);
}

void main() {
  for (final style in MealPlanDiet.values) {
    test(
      'reported Gym75 week beginner3 creates a complete ${style.name} draft',
      () async {
        const catalog = BilSmartPlanCatalog();
        const dietary = DietaryPreferences();
        final recipes = await catalog.checkRecipeStyle(style, dietary);
        expect(recipes.missing, isEmpty, reason: style.name);
        final workouts = await catalog.gymSessions(sessionMinutes: 75);
        final request = BilPlanCreationRequest(
          ownerId: 'reported-style-owner',
          planId: 'reported-style-${style.name}',
          startOn: DateTime(2026, 11, 21),
          horizon: BilPlanHorizon.week,
          focus: BilPlanFocus.combined,
          workoutsPerWeek: 3,
          confirmedPreferences: true,
          adultConfirmed: true,
          ageYears: 18,
          highRiskSymptoms: false,
          underMedicalReview: false,
          workoutCatalog: workouts,
          recipeCatalog: recipes.recipes,
          setup: BilPlanSetup(
            environment: BilPlanEnvironment.gym,
            experience: BilPlanExperience.beginner,
            sessionMinutes: 75,
            equipment: const {'gym'},
            preferredTime: '05:00',
          ),
          phases: await const BilSmartPlanPrescriptions().phases(),
        );
        final assessment = BilPlanSafety.assess(request);
        expect(
          assessment.result,
          BilPlanSafetyResult.ready,
          reason: assessment.reasons.join(','),
        );
        final plan = const BilSmartPlanEngine().generate(
          request,
          DateTime.utc(2026, 11, 21),
        );
        expect(plan.status, BilPlanStatus.draft);
        expect(plan.days, hasLength(7));
        expect(plan.days.where((day) => day.workout != null), hasLength(3));
        expect(plan.setup!.sessionMinutes, 75);
        expect(plan.setup!.environment, BilPlanEnvironment.gym);
        await catalog.validate(BilSmartPlan.decode(plan.encode()), dietary);
        debugPrint(
          'Reported style ${style.name}: ${recipes.recipes.length} verified choices; complete seven-day draft, three Gym sessions, no medical override.',
        );
      },
    );
  }

  test(
    'a saved milk allergy retires the untagged source yogurt breakfast',
    () async {
      const catalog = BilSmartPlanCatalog();
      const dietary = DietaryPreferences(allergens: {DietaryAllergen.milk});
      await expectLater(
        catalog.recipeDetail('overnight-oats-figs', dietary),
        throwsStateError,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  test('saved oat exclusions screen the released index and detail', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final saved = DietaryPreferencesRepository(PreferencesRepository(db));
    final recipes = RecipeReleaseRepository();
    final index = await recipes.loadIndex();
    final oats = index.singleWhere((r) => r.id == 'overnight-oats-figs');
    final other = index.singleWhere((r) => r.id == 'spinach-omelet');
    final oatDetail = await recipes.loadDetail(oats);
    final otherDetail = await recipes.loadDetail(other);
    expect(oatDetail.dietaryEvidence.complete, isTrue);
    for (final term in ['oats', 'oat', 'شوفان', 'figs']) {
      await saved.save(DietaryPreferences(excludedIngredients: {term}));
      final restored = await saved.read();
      expect(restored.excludedIngredients, {term});
      expect(oats.isCompatibleWith(restored), isFalse, reason: term);
      expect(oatDetail.dietaryEvidence.allows(restored), isFalse, reason: term);
      expect(other.isCompatibleWith(restored), isTrue, reason: term);
      expect(
        otherDetail.dietaryEvidence.allows(restored),
        isTrue,
        reason: term,
      );
    }
  });
  test(
    'an exclusion alias cannot validate a stale oat-bran source binding',
    () async {
      const manifestPath = RecipeReleaseRepository.manifestPath;
      final manifest =
          jsonDecode(await rootBundle.loadString(manifestPath)) as Map;
      final index = await RecipeReleaseRepository().loadIndex();
      final original = index.singleWhere((r) => r.id == 'overnight-oats-figs');
      final descriptor = manifest['shards'][original.shard] as Map;
      final path = descriptor['path'] as String;
      final shard = jsonDecode(await rootBundle.loadString(path)) as Map;
      final row =
          (shard['records'][original.ordinal]['ingredients'] as List)
                  .singleWhere((i) => i['recordId'] == 'usda:168872')
              as Map;
      expect(row['sourceDescription'], 'Oat bran, raw');
      expect(row['itemId'], 'raw oat bran');
      row['itemId'] = 'oats';
      Uint8List encode(Map value) =>
          Uint8List.fromList(utf8.encode(jsonEncode(value)));
      final bytes = encode(shard);
      descriptor['size_bytes'] = bytes.length;
      descriptor['sha256'] = sha256.convert(bytes).toString();
      final repo = RecipeReleaseRepository(
        bundle: _RecipeFixtureBundle({
          manifestPath: ByteData.sublistView(encode(manifest)),
          path: ByteData.sublistView(bytes),
        }),
      );
      final summary = (await repo.loadIndex()).singleWhere(
        (r) => r.id == original.id,
      );
      final detail = await repo.loadDetail(summary);
      expect(detail.dietaryEvidence.complete, isFalse);
      expect(detail.dietaryEvidence.highProtein, isFalse);
      expect(
        detail.dietaryEvidence.allows(
          const DietaryPreferences(excludedIngredients: {'figs'}),
        ),
        isFalse,
      );
    },
  );
  test(
    'source food identity, edited recipes and verified protein boundary',
    () async {
      const catalog = BilSmartPlanCatalog();
      const unrestricted = DietaryPreferences();
      final oats = (await catalog.recipeDetail(
        'overnight-oats-figs',
        unrestricted,
      ))!;
      expect(oats.dietaryEvidence.dietTags, contains('vegetarian'));
      expect(oats.dietaryEvidence.dietTags, isNot(contains('vegan')));
      expect(oats.dietaryEvidence.highProtein, isTrue);
      final mixed = (await catalog.recipeDetail('yogurt-oats', unrestricted))!;
      expect(mixed.dietaryEvidence.allergens, containsAll(['treeNut', 'milk']));
      expect(mixed.dietaryEvidence.complete, isFalse);
      expect(mixed.dietaryEvidence.highProtein, isFalse);
      for (final id in ['shakshuka', 'spinach-omelet']) {
        await expectLater(
          catalog.recipeDetail(
            id,
            const DietaryPreferences(allergens: {DietaryAllergen.egg}),
          ),
          throwsStateError,
        );
        expect(
          (await catalog.recipeDetail(
            id,
            unrestricted,
          ))!.dietaryEvidence.highProtein,
          isTrue,
        );
      }
      expect(
        () => (oats.record['ingredients'][0] as Map)['recordId'] = 'unknown',
        throwsUnsupportedError,
      );
      final changed =
          jsonDecode(jsonEncode(oats.record)) as Map<String, dynamic>;
      (changed['ingredients'][0] as Map)['recordId'] = 'unknown';
      final edited = RecipeCatalogDetail(
        summary: oats.summary,
        record: changed,
      );
      expect(edited.dietaryEvidence.complete, isFalse);
      expect(edited.dietaryEvidence.highProtein, isFalse);
      expect(
        edited.dietaryEvidence.allows(
          const DietaryPreferences(pattern: DietaryPattern.vegetarian),
        ),
        isFalse,
      );
      expect(RecipeDietaryEvidence.meetsProteinEnergyShare(5, 100), isTrue);
      for (final pair in <(Object?, Object?)>[
        (4.99, 100),
        (null, 100),
        (5, null),
        (double.nan, 100),
        (5, double.infinity),
        (0, 100),
        (1, 0),
        (-5, 100),
        (40, 100),
      ]) {
        expect(
          RecipeDietaryEvidence.meetsProteinEnergyShare(pair.$1, pair.$2),
          isFalse,
        );
      }
    },
  );
  test(
    'all released recipes are audited and each offered style contains only compatible records',
    () async {
      final repository = RecipeReleaseRepository();
      final summaries = await repository.loadIndex();
      expect(summaries, hasLength(1500));
      var unknown = 0, protein = 0, newlyIdentifiedAllergens = 0;
      for (final summary in summaries) {
        final record = await repository.loadDetail(summary);
        final evidence = record.dietaryEvidence;
        expect(
          summary.dietaryEvidence.dietTags,
          evidence.dietTags,
          reason: summary.id,
        );
        expect(
          summary.dietaryEvidence.allergens,
          evidence.allergens,
          reason: summary.id,
        );
        expect(
          summary.dietaryEvidence.complete,
          evidence.complete,
          reason: summary.id,
        );
        expect(
          summary.dietaryEvidence.ingredientNames,
          evidence.ingredientNames,
          reason: summary.id,
        );
        if (!evidence.complete) {
          unknown++;
          expect(
            evidence.allows(
              const DietaryPreferences(allergens: {DietaryAllergen.peanut}),
            ),
            isFalse,
          );
        }
        if (evidence.highProtein) protein++;
        if (evidence.allergens
            .difference(summary.allergens.toSet())
            .isNotEmpty) {
          newlyIdentifiedAllergens++;
        }
      }
      expect(unknown, greaterThan(0));
      expect(protein, greaterThan(0));
      expect(newlyIdentifiedAllergens, greaterThan(0));
      debugPrint(
        'Verified recipe index records=${summaries.length} unresolved ingredient selections=$unknown eligible protein=$protein additional allergen evidence=$newlyIdentifiedAllergens',
      );
      const catalog = BilSmartPlanCatalog();
      for (final style in MealPlanDiet.values) {
        const dietary = DietaryPreferences(allergens: {DietaryAllergen.milk});
        final choices = await catalog.checkRecipeStyle(style, dietary);
        expect(choices.missing, isEmpty, reason: style.name);
        for (final choice in choices.recipes) {
          final detail = (await catalog.recipeDetail(choice.id, dietary))!;
          expect(detail.dietaryEvidence.complete, isTrue);
          expect(detail.dietaryEvidence.allergens, isNot(contains('milk')));
          if (style == MealPlanDiet.vegetarian) {
            expect(detail.dietaryEvidence.dietTags, contains('vegetarian'));
          }
          if (style == MealPlanDiet.highProtein) {
            expect(detail.dietaryEvidence.highProtein, isTrue);
          }
        }
      }
    },
  );
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
