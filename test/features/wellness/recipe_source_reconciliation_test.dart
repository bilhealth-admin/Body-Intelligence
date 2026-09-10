import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/recipe_coach_lookup.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_diary_service.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_ingredient_reconciler.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/recipe_ingredient_evidence.dart';
import 'package:body_intelligence_log/features/recipe_import/services/catalog_recipe_draft.dart';
import 'package:body_intelligence_log/features/wellness/domain/recipe_source_copy.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecipeReleaseRepository repository;
  late List<RecipeCatalogDetail> details;
  setUpAll(() async {
    repository = RecipeReleaseRepository();
    details = [
      for (final summary in await repository.loadIndex())
        await repository.loadDetail(summary),
    ];
  });

  test(
    'all 1500 recipes have consistent identity, portions and calculation',
    () {
      expect(details, hasLength(1500));
      final invalid = [
        for (final detail in details)
          if (RecipeIngredientEvidence.recordNeedsReview(detail.record))
            detail.summary.id,
      ];
      expect(invalid, isEmpty);
    },
  );

  test('every per-100g value is the exact bundled USDA row, not a guess', () {
    const columns = {
      'kcal': 'energy_kcal',
      'proteinG': 'protein_g',
      'carbohydrateG': 'carbs_g',
      'fatG': 'fat_g',
      'fiberG': 'fiber_g',
      'sugarG': 'sugars_g',
      'sodiumMg': 'sodium_mg',
      'potassiumMg': 'potassium_mg',
    };
    final db = sqlite3.open(
      'assets/catalogs/bil_food_core.sqlite',
      mode: OpenMode.readOnly,
    );
    try {
      final sources = <String, Row>{};
      for (final detail in details) {
        for (final item
            in (detail.record['ingredients'] as List)
                .cast<Map<String, dynamic>>()) {
          final id = item['recordId'] as String;
          final row = sources.putIfAbsent(
            id,
            () => db.select('SELECT * FROM foods WHERE fdc_id = ?', [
              int.parse(id.split(':').last),
            ]).single,
          );
          expect(
            item['sourceDescription'],
            row['description'],
            reason: '${detail.summary.id}:$id',
          );
          for (final entry in columns.entries) {
            expect(
              (item['nutrientsPer100g'] as Map)[entry.key],
              row[entry.value],
              reason: '$id:${entry.key}',
            );
          }
          expect(item['sourceRefs'], [id]);
          expect(item['unit'], 'g');
          expect(item['quantity'], item['grams']);
          expect(
            item['sourcePreparation'],
            isIn(['raw', 'cooked', 'dry', 'unbaked', 'as-sold']),
          );
        }
      }
      expect(sources, hasLength(120));
    } finally {
      db.close();
    }
  });

  test(
    'cards and saved drafts retain the same calculated macros for all recipes',
    () {
      for (final detail in details) {
        final card = RecipeCatalogCardFacts.fromDetail(detail);
        final draft = CatalogRecipeDraft.fromDetail(detail, 'ar');
        expect(card.nutritionNeedsReview, isFalse, reason: detail.summary.id);
        expect(draft.nutrition, isNotNull, reason: detail.summary.id);
        expect(draft.nutrition!.caloriesKcal, card.kcalPerServing);
        expect(draft.nutrition!.proteinG, card.proteinGramsPerServing);
        expect(draft.servings, card.servings);
        expect(
          draft.nutrition!.provenance.recordId,
          contains('bil-source-reconciled-20260910-v1'),
        );
      }
    },
  );

  test(
    'specific mismatches and the old 4-vs-6 serving divisor are repaired',
    () {
      RecipeCatalogDetail find(String id) =>
          details.singleWhere((d) => d.summary.id == id);
      final aji = find('aji-gallina-ligero');
      final ajiIds = (aji.record['ingredients'] as List).map(
        (i) => (i as Map)['recordId'],
      );
      expect(
        ajiIds,
        containsAll(['usda:171477', 'usda:171265', 'usda:170187']),
      );
      expect(ajiIds, isNot(contains('usda:174980')));
      final arroz = find('arroz-con-gandules');
      expect((arroz.record['serving'] as Map)['count'], 6);
      expect((arroz.record['nutrition'] as Map)['servings'], 6);
      for (final detail in details) {
        for (final item in (detail.record['ingredients'] as List).cast<Map>()) {
          if (item['itemId'] == 'whole-wheat-pasta') {
            expect(item['recordId'], 'usda:168910');
          }
        }
      }
    },
  );

  Map<String, dynamic> copyRecord() =>
      jsonDecode(jsonEncode(details.first.record)) as Map<String, dynamic>;

  test('stale totals, missing food identity and portion drift fail closed', () {
    final original = copyRecord();
    expect(RecipeIngredientEvidence.recordNeedsReview(original), isFalse);
    for (final corrupt in <void Function(Map<String, dynamic>)>[
      (r) => (r['nutrition'] as Map)['servings'] = 99,
      (r) => ((r['nutrition'] as Map)['perServing'] as Map)['kcal'] = 123456,
      (r) => (r['ingredients'][0] as Map)['grams'] = 999,
      (r) => (r['ingredients'][0] as Map)['sourceDescription'] = '',
      (r) => (r['ingredients'][0] as Map)['sourceRefs'] = <String>[],
      (r) => (r['nutrition'] as Map)['sourceRefs'] = ['usda:123'],
    ]) {
      final changed = copyRecord();
      corrupt(changed);
      expect(RecipeIngredientEvidence.recordNeedsReview(changed), isTrue);
      expect(
        CatalogRecipeDraft.fromDetail(
          RecipeCatalogDetail(summary: details.first.summary, record: changed),
          'en',
        ).nutrition,
        isNull,
      );
    }
  });

  test(
    'unknown optional sugar is null, never fabricated zero or a subtotal',
    () {
      final unknown = details.where(
        (detail) => (detail.record['nutrition']['missingNutrients'] as List)
            .contains('sugarG'),
      );
      expect(unknown, hasLength(366));
      for (final detail in unknown) {
        expect(detail.record['nutrition']['perServing']['sugarG'], isNull);
        expect(
          RecipeIngredientEvidence.recordNeedsReview(detail.record),
          isFalse,
        );
      }
      final invalid =
          jsonDecode(jsonEncode(unknown.first.record)) as Map<String, dynamic>;
      invalid['nutrition']['perServing']['sugarG'] = 0;
      expect(RecipeIngredientEvidence.recordNeedsReview(invalid), isTrue);
    },
  );

  test(
    'whole-wheat, dairy, beans and preparation identity cannot be confused',
    () {
      for (final pair in const [
        ('egg', 'Eggnog'),
        ('corn', 'Cornstarch'),
        ('milk', 'Crackers, milk'),
        ('yogurt', 'Tofu yogurt'),
        ('olive oil', 'Mayonnaise, reduced fat, with olive oil'),
        ('artichoke', 'Jerusalem-artichokes, raw'),
        ('raw beef', 'Beef, cooked'),
        ('whole-wheat-pasta', 'Spaghetti, protein-fortified, cooked'),
        ('black beans', 'Restaurant rice and black beans'),
        ('kidney beans', 'Beans, liquid from stewed kidney beans'),
      ]) {
        expect(
          RecipeIngredientEvidence.hasKnownMismatch(pair.$1, pair.$2),
          isTrue,
          reason: '$pair',
        );
      }
      expect(
        RecipeIngredientEvidence.hasKnownMismatch(
          'flatbread',
          'Bread, pita, white, enriched',
        ),
        isFalse,
      );
      expect(
        RecipeIngredientEvidence.hasKnownMismatch(
          'tahini',
          'Seeds, sesame butter, tahini',
        ),
        isFalse,
      );
    },
  );

  test('weight basis is written in every supported app language', () {
    final index = details.first.summary.localizedTitles.keys;
    expect(index, hasLength(25));
    for (final locale in index) {
      expect(RecipeSourceCopy.weighingBasis(locale), isNotEmpty);
      if (locale != 'en') {
        expect(
          RecipeSourceCopy.weighingBasis(locale),
          isNot(RecipeSourceCopy.weighingBasis('en')),
          reason: locale,
        );
      }
    }
    expect(RecipeSourceCopy.state('raw', 'ar'), 'نيئ');
    expect(RecipeSourceCopy.state('cooked', 'ar'), 'مطهو');
  });

  test(
    'all distinct ingredient identities resolve through the production catalog adapter',
    () async {
      final local = AppDatabase.forTesting(NativeDatabase.memory());
      final source = sqlite3.open(
        'assets/catalogs/bil_food_core.sqlite',
        mode: OpenMode.readOnly,
      );
      addTearDown(local.close);
      addTearDown(source.close);
      final unique = <String, TrustedRecipeIngredient>{};
      for (final detail in details) {
        for (final ingredient in CatalogRecipeDraft.fromDetail(
          detail,
          'en',
        ).ingredients) {
          unique['${ingredient.name}:${ingredient.sourceRecordId}'] =
              ingredient;
        }
      }
      final draft = TrustedRecipeDraft(
        name: 'Identity audit',
        servings: 1,
        prepMinutes: 0,
        cookMinutes: 0,
        ingredients: unique.values.toList(),
        steps: const ['Review source identity.'],
        sourceUrl: null,
      );
      final authority = FoodRuntimeSearchAuthority(
        FoodRepository(local),
        catalogResolver: () async =>
            UsdaCoreCatalogRepository.fromDatabase(source),
      );
      final matches = await TrustedRecipeIngredientReconciler(
        authority,
      ).reconcile(draft);
      expect(
        matches
            .where((m) => m.status != IngredientMatchStatus.exact)
            .map((m) => m.ingredient.name),
        isEmpty,
      );
      expect(matches.length, unique.length);
    },
  );

  test(
    'real catalog draft survives save, reload and atomic diary logging unchanged',
    () async {
      final local = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(local.close);
      final savedRecipes = TrustedRecipeRepository(
        PreferencesRepository(local),
      );
      final meals = MealRepository(local);
      final diary = TrustedRecipeDiaryService(FoodRepository(local), meals);
      final detail = details.singleWhere(
        (d) => d.summary.id == 'aji-gallina-ligero',
      );
      final draft = CatalogRecipeDraft.fromDetail(detail, 'ar');
      await savedRecipes.saveReviewed(draft);
      final restored = (await savedRecipes.load()).single;
      expect(restored.recipe.nutrition!.toJson(), draft.nutrition!.toJson());
      expect(restored.recipe.fingerprint, draft.fingerprint);
      final date = DateTime(2026, 9, 10);
      await diary.addServing(saved: restored, date: date, mealType: 'lunch');
      final logged =
          (await meals.watchMealsForDate(date).first).single.items.single;
      expect(logged.calories, draft.nutrition!.caloriesKcal);
      expect(logged.protein, draft.nutrition!.proteinG);
      expect(logged.carbs, draft.nutrition!.carbohydrateG);
      expect(logged.fats, draft.nutrition!.fatG);
      expect(logged.foodVerifiedSnapshot, isFalse);
    },
  );

  test('recovered sources and database are pinned in the release evidence', () {
    final provenance =
        jsonDecode(
              File(
                'assets/catalogs/recipes/v1/recipe-provenance.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(
      provenance['nutrition_claim']['ingredient_evidence_incomplete_record_count'],
      0,
    );
    expect(
      provenance['source_reconciliation']['core_nutrients_calculated_record_count'],
      1500,
    );
    expect(
      provenance['nutrition_claim']['professional_attestation_artifact'],
      isNull,
    );
  });

  test(
    'Coach quotes the same corrected calories as the card and saved draft',
    () async {
      final detail = details.singleWhere(
        (d) => d.summary.id == 'aji-gallina-ligero',
      );
      final lookup = RecipeCoachLookup(repository: repository);
      final calories = RecipeCatalogCardFacts.fromDetail(
        detail,
      ).kcalPerServing.round();
      for (final locale in ['ar', 'en', 'fr', 'es', 'tr']) {
        final answer = await lookup.answer(
          question: 'recipe ${detail.summary.titleFor(locale)}',
          locale: locale,
        );
        expect(answer?.recipeId, detail.summary.id);
        expect(answer?.text, contains('$calories'), reason: locale);
        expect(
          CatalogRecipeDraft.fromDetail(
            detail,
            locale,
          ).nutrition!.caloriesKcal.round(),
          calories,
        );
      }
    },
  );
}
