import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/seed_data.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_attempt.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_catalog_entry.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_food_bridge.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_review_dialog.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/unified_food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_food_search_pipeline.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = 'photo-catalog-owner';
final _ownerKey = LocalDatabaseScope.keyForOwner(_owner);
const _asset = 'assets/catalogs/bil_food_core.sqlite';

void main() {
  late UnifiedFood apple;
  setUpAll(() async {
    final source = UsdaCoreCatalogRepository.open(_asset);
    try {
      apple = (await source.findById('usda:171688'))!;
    } finally {
      source.close();
    }
  });

  test(
    'real installed APPLE candidates retain actual names and nullable evidence',
    () async {
      final state = _State();
      final entries = await _real().lookup('APPLE', state.begin());
      expect(entries, isNotEmpty);
      final actual = entries.first;
      final source = UsdaCoreCatalogRepository.open(_asset);
      final original = (await source.findById(actual.food.identity))!;
      source.close();
      expect(actual.food.name, original.name);
      expect(actual.food.name, isNot('APPLE'));
      expect(actual.row.id, 0);
      expect(actual.row.syncStatus, 'presentation-only');
      expect(actual.row.uuid, original.id);
      expect(actual.food.basisGrams, 100);
      for (final nutrient in FoodNutrient.values) {
        expect(actual.food.nutrients[nutrient], original.knownValue(nutrient));
      }
      expect(actual.food.nutrients[FoodNutrient.vitaminC], isNull);
      expect(actual.food.source.kind, CoachFoodSourceKind.reference);
      expect(actual.food.source.ref, original.sourceLabel);
      expect(actual.food.source.revision, startsWith('catalog:'));
      expect(actual.unitRule, isNull);
      final displayed = FoodBasisEvidence.read(actual.row);
      expect(displayed.isValid, isTrue);
      expect(displayed.isCatalog, isTrue);
      for (final nutrient in FoodNutrient.values) {
        expect(displayed.value(nutrient), actual.food.nutrients[nutrient]);
      }
      // A presentation projection still cannot be re-imported as a local row.
      expect(
        CoachMediaCatalogEntry.fromLocalFood(actual.row, ownerKey: _ownerKey),
        isNull,
      );
    },
  );

  test(
    'explicit source selection/grams precede a real journal commit, never FK0',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _owner,
      );
      addTearDown(db.close);
      final foods = FoodRepository(db);
      await SeedData.seedStarterCatalog(foods);
      final original = await foods.getFoods();
      final oldApple = original.singleWhere((row) => row.name == 'Apple');
      expect(
        CoachMediaCatalogEntry.fromLocalFood(oldApple, ownerKey: _ownerKey),
        isNull,
      );
      final state = _State();
      final attempt = state.begin();
      final candidates = await _real().lookup(
        'Apples raw includes foods distribution',
        attempt,
      );
      final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => candidates);
      final input = _input(amount: 1, unit: 'item');
      final matches =
          await bridge.lookup(input: input, attempt: attempt)
              as CoachMediaFoodMatches;
      final selected = matches.candidates.singleWhere(
        (entry) => entry.food.identity == apple.id,
      );
      expect(matches.candidates, isNotEmpty);
      expect(
        bridge.select(matches: matches, selected: selected),
        isA<CoachMediaFoodUnresolved>().having(
          (value) => value.issue,
          'issue',
          CoachMediaFoodIssue.missingUnitWeight,
        ),
      );
      expect(await foods.getFoods(), original);
      expect(await db.select(db.meals).get(), isEmpty);
      expect(await db.select(db.mealItems).get(), isEmpty);

      final ready =
          bridge.select(
                matches: matches,
                selected: selected,
                reviewedInput: input.withUserQuantity(100, 'g'),
              )
              as CoachMediaFoodReady;
      final review = bridge.takeReview([ready])!;
      expect(review.items.single.food.identity, apple.id);
      expect(await foods.getFoods(), original);
      expect(await db.select(db.meals).get(), isEmpty);
      final command = CoachMealCommand.foods(
        operationId: 'actual-catalog-reviewed',
        date: DateTime(2026, 10, 17),
        mealType: 'lunch',
        review: review,
      );
      final meals = MealRepository(db);
      final scope = CoachMealOwnerScope(
        ownerId: _owner,
        isCurrent: () => attempt.isCurrent,
      );
      final committed = await meals.commitCoachMeal(
        command: command,
        scope: scope,
      );
      expect(committed.after.single.item.foodId, greaterThan(0));
      expect(committed.after.single.item.calories, 52);
      expect(committed.after.single.item.protein, .26);
      expect(committed.after.single.item.carbs, 13.81);
      expect(committed.after.single.item.fats, .17);
      expect(committed.after.single.meal.type, 'lunch');
      expect((await foods.getFoods()).where((row) => row.id == 0), isEmpty);
      expect(
        (await foods.getFoods()).singleWhere((row) => row.id == oldApple.id),
        oldApple,
      );
      final replay = await meals.commitCoachMeal(
        command: command,
        scope: scope,
      );
      expect(replay.replayed, isTrue);
      expect(await db.select(db.mealItems).get(), hasLength(1));
    },
  );

  for (final change in ['cancel', 'owner', 'ownerRoundTrip', 'permission']) {
    test(
      '$change after review cannot commit a projected catalog row',
      () async {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: _owner,
        );
        addTearDown(db.close);
        final state = _State();
        final attempt = state.begin();
        final entries = await _real().lookup('APPLE', attempt);
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => entries);
        final input = _input(amount: 100, unit: 'g').withUserQuantity(100, 'g');
        final matches =
            await bridge.lookup(input: input, attempt: attempt)
                as CoachMediaFoodMatches;
        final selected = matches.candidates.first;
        final ready =
            bridge.select(matches: matches, selected: selected)
                as CoachMediaFoodReady;
        final review = bridge.takeReview([ready])!;
        state.invalidate(change, attempt);
        final command = CoachMealCommand.foods(
          operationId: 'retired-$change',
          date: DateTime(2026, 10, 17),
          mealType: 'snack',
          review: review,
        );
        await expectLater(
          MealRepository(db).commitCoachMeal(
            command: command,
            scope: CoachMealOwnerScope(
              ownerId: _owner,
              isCurrent: () => attempt.isCurrent,
            ),
          ),
          throwsA(isA<CoachMealConflict>()),
        );
        expect(await db.select(db.foods).get(), isEmpty);
        expect(await db.select(db.meals).get(), isEmpty);
        expect(await db.select(db.mealItems).get(), isEmpty);
      },
    );
  }

  for (final point in ['open', 'search', 'resolve']) {
    test(
      'owner change while $point is pending discards results and closes handle',
      () async {
        final state = _State();
        final attempt = state.begin();
        final source = _Catalog(apple);
        final opened = Completer<UnifiedFoodRepository?>();
        final search = Completer<List<FoodSearchHit>>();
        final resolved = Completer<UnifiedFood?>();
        source.searchResult = point == 'search' ? search.future : null;
        source.resolveResult = point == 'resolve' ? resolved.future : null;
        final lookup = CoachMediaInstalledCatalogLookup(
          ownerKey: _ownerKey,
          openCatalog: () =>
              point == 'open' ? opened.future : Future.value(source),
        );
        final pending = lookup.lookup('APPLE', attempt);
        if (point == 'search') await source.searchStarted.future;
        if (point == 'resolve') await source.resolveStarted.future;
        state.invalidate('ownerRoundTrip', attempt);
        if (point == 'open') opened.complete(source);
        if (point == 'search') search.complete(source.hits);
        if (point == 'resolve') resolved.complete(apple);
        expect(await pending, isEmpty);
        expect(source.closed, isTrue);
        expect(attempt.isCurrent, isFalse);
      },
    );
  }

  test('private/local repository is never searched or promoted', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: _owner,
    );
    addTearDown(db.close);
    final foods = FoodRepository(db);
    await SeedData.seedStarterCatalog(foods);
    final before = await foods.getFoods();
    final lookup = CoachMediaInstalledCatalogLookup(
      ownerKey: _ownerKey,
      openCatalog: () async => foods,
    );
    expect(await lookup.lookup('APPLE', _State().begin()), isEmpty);
    expect(await foods.getFoods(), before);
  });

  for (final change in [
    'private',
    'unverified',
    'unknown',
    'localId',
    'missingCore',
    'drift',
  ]) {
    test('$change cannot manufacture installed reference evidence', () async {
      final changed = _changed(apple, change);
      final source = _Catalog(change == 'drift' ? apple : changed)
        ..resolvedFood = changed;
      final lookup = CoachMediaInstalledCatalogLookup(
        ownerKey: _ownerKey,
        openCatalog: () async => source,
      );
      expect(await lookup.lookup('APPLE', _State().begin()), isEmpty);
      expect(source.closed, isTrue);
    });
  }

  test('disposed provider cannot revive an otherwise current owner', () async {
    final source = _Catalog(apple);
    var current = false;
    final attempt = _State().begin();
    final lookup = CoachMediaInstalledCatalogLookup(
      ownerKey: _ownerKey,
      openCatalog: () async => source,
      isCurrent: () => current,
    );
    expect(await lookup.lookup('APPLE', attempt), isEmpty);
    current = true;
    expect(await lookup.lookup('APPLE', attempt), isEmpty);
    expect(attempt.isCancelled, isTrue);
    expect(source.searchCalls, 0);
  });

  for (final retire in [false, true]) {
    testWidgets(
      'unpersisted catalog picker requires selection and ${retire ? 'retires' : 'cancels'} without result',
      (tester) async {
        final state = _State();
        final source = _Catalog(apple);
        final lookup = CoachMediaInstalledCatalogLookup(
          ownerKey: _ownerKey,
          openCatalog: () async => source,
        );
        final entries = await lookup.lookup('APPLE', state.begin());
        final lifetime = MealVisionReviewLifetime();
        Food? result;
        var returned = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showTrustedVisionFoodMatchDialog(
                      context,
                      recognizedName: 'APPLE',
                      foods: entries.map((entry) => entry.row).toList(),
                      evidenceOwnerKey: _ownerKey,
                      lifetime: lifetime,
                    );
                    returned = true;
                  },
                  child: const Text('Open catalog review'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open catalog review'));
        await tester.pumpAndSettle();
        final use = find.byKey(const Key('premium-vision-use-food'));
        expect(tester.widget<FilledButton>(use).onPressed, isNull);
        await tester.tap(find.widgetWithText(ListTile, apple.name));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(use).onPressed, isNotNull);
        if (retire) {
          lifetime.retire();
          await tester.pump();
        } else {
          await tester.tap(find.byIcon(Icons.close));
        }
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

CoachMediaInstalledCatalogLookup _real() => CoachMediaInstalledCatalogLookup(
  ownerKey: _ownerKey,
  openCatalog: () async => UsdaCoreCatalogRepository.open(_asset),
);

CoachMediaFoodInput _input({required double amount, required String unit}) =>
    CoachMediaFoodInput.fromUntrustedPhoto({
      'name': 'APPLE',
      'amount': amount,
      'unit': unit,
    }, requestId: 'photo:catalog-qa');

class _State {
  CoachFoodOwnerStamp owner = CoachFoodOwnerStamp(
    ownerKey: _ownerKey,
    epoch: 0,
  );
  var authorized = true;
  CoachMediaAttempt begin() => CoachMediaAttempt(
    ownerScope: CoachFoodOwnerScope(captured: owner, readCurrent: () => owner),
    conversationEpoch: 0,
    requestGeneration: 0,
    readConversationEpoch: () => 0,
    readRequestGeneration: () => 0,
    isAuthorized: () => authorized,
  );
  void invalidate(String change, CoachMediaAttempt attempt) {
    if (change == 'cancel') attempt.cancel();
    if (change == 'permission') authorized = false;
    if (change == 'owner') {
      owner = CoachFoodOwnerStamp(ownerKey: 'other-owner', epoch: 1);
    }
    if (change == 'ownerRoundTrip') {
      owner = CoachFoodOwnerStamp(ownerKey: 'other-owner', epoch: 1);
      attempt.ownerScope.cancel();
      owner = CoachFoodOwnerStamp(ownerKey: _ownerKey, epoch: 2);
    }
  }
}

class _Catalog extends Fake implements UsdaCoreCatalogRepository {
  _Catalog(this.food);
  final UnifiedFood food;
  UnifiedFood? resolvedFood;
  Future<List<FoodSearchHit>>? searchResult;
  Future<UnifiedFood?>? resolveResult;
  final searchStarted = Completer<void>();
  final resolveStarted = Completer<void>();
  var closed = false;
  var searchCalls = 0;
  List<FoodSearchHit> get hits => [
    FoodSearchHit(food: food, score: 100, reasons: const []),
  ];
  @override
  Future<List<FoodSearchHit>> searchUnified(String query, {int limit = 50}) {
    searchCalls++;
    searchStarted.complete();
    return searchResult ?? Future.value(hits);
  }

  @override
  Future<UnifiedFood?> findById(String id) {
    resolveStarted.complete();
    return resolveResult ?? Future.value(resolvedFood ?? food);
  }

  @override
  void close() => closed = true;
}

UnifiedFood _changed(UnifiedFood food, String change) => UnifiedFood(
  id: food.id,
  localId: change == 'localId' ? 1 : null,
  name: food.name,
  arabicName: food.arabicName,
  category: food.category,
  serving: food.serving,
  source: change == 'unknown' ? FoodDataSource.unknown : food.source,
  sourceLabel: food.sourceLabel,
  verified: change != 'unverified',
  isCustom: change == 'private',
  updatedAt: food.updatedAt,
  nutrients: {
    ...food.nutrients,
    if (change == 'missingCore')
      FoodNutrient.protein: const NutrientAmount.missing(),
    if (change == 'drift')
      FoodNutrient.calories: const NutrientAmount.known(999),
  },
);
