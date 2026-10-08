import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_catalog_entry.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/nutrition/food_basis_fixtures.dart';

final _ownerKey = LocalDatabaseScope.keyForOwner('synthetic-media-owner');

CoachMediaCatalogEntry? _entry(Food row, {CoachFoodUnitRule? rule}) =>
    CoachMediaCatalogEntry.fromLocalFood(
      row,
      ownerKey: _ownerKey,
      unitRule: rule,
    );

Food _legacy({String source = 'foundation'}) =>
    basisFood(includeEvidence: false).copyWith(source: source, verified: true);

CoachFoodUnitRule _rule(
  CoachFoodSnapshot food, {
  String? identity,
  String? preparation,
  String? ownerKey,
  bool estimated = false,
}) => CoachFoodUnitRule(
  identity: identity ?? food.identity,
  preparedState: preparation ?? food.preparedState,
  inputUnit: 'ml',
  gramsPerUnit: 1.04,
  source: CoachFoodSourceEvidence(
    kind: estimated
        ? CoachFoodSourceKind.estimated
        : ownerKey == null
        ? CoachFoodSourceKind.label
        : CoachFoodSourceKind.userFixed,
    ref: 'synthetic-density-label',
    revision: 'synthetic-density-1',
    ownerKey: ownerKey,
  ),
);

void main() {
  group('modern repository evidence', () {
    test('preserves exact snapshot provenance and all nullable nutrients', () {
      final snapshot = basisSnapshot(
        values: const {
          FoodNutrient.calories: 0,
          FoodNutrient.protein: 6,
          FoodNutrient.iron: 0,
        },
      );
      final row = basisFood(snapshot: snapshot);
      final actual = _entry(row)!;
      expect(actual.row, same(row));
      expect(actual.food.digest, snapshot.digest);
      expect(actual.food.toJson(), snapshot.toJson());
      expect(actual.food.nutrients[FoodNutrient.calories], 0);
      expect(actual.food.nutrients[FoodNutrient.iron], 0);
      expect(actual.food.nutrients[FoodNutrient.sodium], isNull);
      expect(actual.food.nutrients[FoodNutrient.carbohydrates], isNull);
      expect(actual.row.verified, isFalse);
      expect(actual.unitRule, isNull);
    });

    test('all-unknown label remains all-unknown and has no guessed values', () {
      final actual = _entry(
        basisFood(snapshot: basisSnapshot(values: const {})),
      )!;
      expect(actual.food.nutrients.toJson().values, everyElement(isNull));
    });

    for (final kind in [
      CoachFoodSourceKind.reference,
      CoachFoodSourceKind.label,
      CoachFoodSourceKind.calculatedRecipe,
      CoachFoodSourceKind.userFixed,
    ]) {
      test('preserves non-estimated ${kind.name} without raising trust', () {
        final snapshot = basisSnapshot(
          kind: kind,
          ownerKey: kind == CoachFoodSourceKind.userFixed ? _ownerKey : null,
        );
        expect(
          _entry(basisFood(snapshot: snapshot))!.food.digest,
          snapshot.digest,
        );
      });
    }

    test('owner-bound evidence uses the opaque local owner key', () {
      final snapshot = basisSnapshot(
        kind: CoachFoodSourceKind.userFixed,
        ownerKey: _ownerKey,
      );
      final row = basisFood(snapshot: snapshot);
      expect(_entry(row), isNotNull);
      expect(
        CoachMediaCatalogEntry.fromLocalFood(
          row,
          ownerKey: 'synthetic-media-owner',
        ),
        isNull,
      );
      expect(
        CoachMediaCatalogEntry.fromLocalFood(
          row,
          ownerKey: LocalDatabaseScope.keyForOwner('another-synthetic-owner'),
        ),
        isNull,
      );
    });

    for (final mutate in <(String, Food Function(Food))>[
      (
        'missing envelope',
        (row) => row.copyWith(foodEvidenceJson: const Value(null)),
      ),
      (
        'malformed envelope',
        (row) => row.copyWith(foodEvidenceJson: const Value('{')),
      ),
      ('source mismatch', (row) => row.copyWith(source: 'foundation')),
      ('manufactured verified flag', (row) => row.copyWith(verified: true)),
      ('row nutrient conflict', (row) => row.copyWith(protein: 99)),
      ('row basis conflict', (row) => row.copyWith(servingUnit: 'ml')),
    ]) {
      test('${mutate.$1} never falls back to legacy trust', () {
        expect(_entry(mutate.$2(basisFood())), isNull);
      });
    }

    test('stored model estimate is not promoted to a catalog match', () {
      expect(
        _entry(
          basisFood(
            snapshot: basisSnapshot(kind: CoachFoodSourceKind.estimated),
          ),
        ),
        isNull,
      );
    });
  });

  group('legacy local catalog evidence', () {
    for (final source in [
      'local',
      'starter',
      'foundation',
      'brand',
      'branded',
      'bil-mobile-catalog',
    ]) {
      test(
        'accepts verified persisted $source with explicit source attribution',
        () {
          final row = _legacy(source: source);
          final actual = _entry(row)!;
          expect(actual.food.identity, 'local-food:${row.uuid}');
          expect(
            actual.food.source.ref,
            'local-food:${row.uuid};source:$source',
          );
          expect(actual.food.source.ref, isNot(contains('USDA')));
          expect(actual.food.source.confidence, isNull);
          expect(actual.food.source.revision.length, lessThanOrEqualTo(100));
          expect(
            actual.food.source.kind,
            source == 'brand' || source == 'branded'
                ? CoachFoodSourceKind.label
                : CoachFoodSourceKind.reference,
          );
          expect(actual.food.basisGrams, 40);
          expect(actual.unitRule, isNull);
        },
      );
    }

    for (final source in [
      'legacy',
      'unverified-provider',
      'USDA FoodData Central — model',
      'USDA',
      'bil-mobile-catalog:model',
      'BIL community',
    ]) {
      test('unrecognized $source is unresolved despite verified=true', () {
        expect(_entry(_legacy(source: source)), isNull);
      });
    }

    test('row verification and custom-food status cannot be bypassed', () {
      expect(_entry(_legacy().copyWith(verified: false)), isNull);
      expect(_entry(_legacy().copyWith(isCustom: true)), isNull);
      expect(
        _entry(_legacy(source: 'bil-mobile-catalog').copyWith(verified: false)),
        isNull,
      );
      expect(
        _entry(_legacy(source: 'bil-mobile-catalog').copyWith(isCustom: true)),
        isNull,
      );
    });

    test(
      'legacy adapter evidence keeps missing nutrients distinct from zero',
      () {
        final row = basisFood(
          snapshot: basisSnapshot(values: const {FoodNutrient.fiber: 0}),
          includeEvidence: false,
        ).copyWith(verified: true);
        final actual = _entry(row)!;
        expect(actual.food.nutrients[FoodNutrient.fiber], 0);
        expect(actual.food.nutrients[FoodNutrient.sodium], isNull);
        expect(actual.food.nutrients[FoodNutrient.iron], isNull);
        expect(actual.food.nutrients[FoodNutrient.vitaminC], isNull);
      },
    );

    for (final value in <(String, double, double)>[
      ('g', 40, 40),
      ('kg', .5, 500),
      ('oz', 2, 56.69904625),
      ('lb', 1, 453.59237),
      ('mg', 500, .5),
    ]) {
      test('reuses explicit ${value.$1} mass conversion', () {
        final row =
            basisFood(
              snapshot: basisSnapshot(values: const {}),
              includeEvidence: false,
            ).copyWith(
              verified: true,
              servingSize: value.$2,
              servingUnit: value.$1,
            );
        expect(_entry(row)!.food.basisGrams, value.$3);
      });
    }

    for (final unit in ['ml', 'liter', 'cup', 'piece', 'serving']) {
      test(
        '$unit does not create a gram basis without conversion evidence',
        () {
          expect(_entry(_legacy().copyWith(servingUnit: unit)), isNull);
        },
      );
    }

    test(
      'unchanged evidence is stable while edits change snapshot revision',
      () {
        final original = _legacy();
        final first = _entry(original)!.food;
        expect(_entry(original.copyWith())!.food.digest, first.digest);
        expect(
          _entry(
            original.copyWith(updatedAt: original.updatedAt.toUtc()),
          )!.food.digest,
          first.digest,
        );
        for (final changed in [
          original.copyWith(protein: original.protein + 1),
          original.copyWith(servingSize: original.servingSize + 1),
          original.copyWith(name: 'Another synthetic catalog food'),
          original.copyWith(source: 'starter'),
          original.copyWith(revision: original.revision + 1),
          original.copyWith(
            updatedAt: original.updatedAt.add(const Duration(seconds: 1)),
          ),
        ]) {
          final next = _entry(changed)!.food;
          expect(next.source.revision, isNot(first.source.revision));
          expect(next.digest, isNot(first.digest));
        }
      },
    );

    test(
      'invalid or excessive evidence cannot construct a reviewed snapshot',
      () {
        for (final changed in [
          _legacy().copyWith(servingSize: 0),
          _legacy().copyWith(servingSize: double.infinity),
          _legacy().copyWith(calories: 999999),
          _legacy().copyWith(carbs: 1, fiber: 20),
        ]) {
          expect(_entry(changed), isNull);
        }
      },
    );
  });

  group('local conversion rule binding', () {
    test(
      'retains a documented matching density without inferring a new one',
      () {
        final row = basisFood();
        final food = _entry(row)!.food;
        final rule = _rule(food, ownerKey: _ownerKey);
        final actual = _entry(row, rule: rule)!;
        expect(actual.unitRule, same(rule));
        final stamp = CoachFoodOwnerStamp(ownerKey: _ownerKey, epoch: 1);
        final quantity = CoachFoodQuantities.fromUnit(
          food: actual.food,
          amount: 200,
          inputUnit: 'ml',
          rule: actual.unitRule,
          scope: CoachFoodOwnerScope(captured: stamp, readCurrent: () => stamp),
          description:
              'Synthetic user-declared volume with a documented density.',
        );
        expect(quantity.grams, 208);
        expect(quantity.evidence.kind, CoachFoodQuantityKind.userDeclared);
        expect(
          quantity.evidence.conversion!.source.ref,
          'synthetic-density-label',
        );
      },
    );

    test(
      'foreign, wrong-identity, wrong-preparation and estimated rules fail closed',
      () {
        final row = basisFood();
        final food = _entry(row)!.food;
        for (final rule in [
          _rule(food, identity: 'another-local-identity'),
          _rule(food, preparation: 'raw'),
          _rule(food, ownerKey: 'another-owner'),
          _rule(food, estimated: true),
        ]) {
          expect(_entry(row, rule: rule), isNull);
        }
      },
    );
  });

  test('rejects tombstones, non-persisted identities and unbounded text', () {
    for (final row in [
      _legacy().copyWith(id: 0),
      _legacy().copyWith(uuid: ''),
      _legacy().copyWith(uuid: ' ${_legacy().uuid}'),
      _legacy().copyWith(uuid: 'x' * 129),
      _legacy().copyWith(name: 'x' * 241),
      _legacy().copyWith(name: 'Injected\nfood'),
      _legacy().copyWith(source: 'x' * 201),
      _legacy().copyWith(servingUnit: 'x' * 33),
      _legacy().copyWith(revision: 0),
      _legacy().copyWith(deletedAt: Value(DateTime(2026, 10, 7))),
    ]) {
      expect(_entry(row), isNull);
    }
    for (final owner in ['', ' x ', 'x' * 129, 'owner\nkey']) {
      expect(
        CoachMediaCatalogEntry.fromLocalFood(_legacy(), ownerKey: owner),
        isNull,
      );
    }
  });

  test(
    'real local catalog materialization preserves unknowns and writes no meal',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'synthetic-media-owner',
      );
      addTearDown(database.close);
      final repository = FoodRepository(database);
      final row = await repository.materializeUnifiedFood(
        const UnifiedFood(
          id: 'synthetic-installed-catalog-record',
          name: 'Synthetic catalog label',
          category: 'branded',
          serving: FoodServing(amount: 1, unit: 'serving', grams: 50),
          nutrients: {
            FoodNutrient.calories: NutrientAmount.known(120),
            FoodNutrient.protein: NutrientAmount.missing(),
            FoodNutrient.carbohydrates: NutrientAmount.known(18),
            FoodNutrient.fat: NutrientAmount.known(3),
            FoodNutrient.fiber: NutrientAmount.known(0),
            FoodNutrient.sodium: NutrientAmount.missing(),
          },
          source: FoodDataSource.branded,
          sourceLabel: 'bil-mobile-catalog',
          verified: true,
          isCustom: false,
        ),
      );
      final persisted = await (database.select(
        database.foods,
      )..where((table) => table.id.equals(row.id))).getSingle();
      final actual = _entry(persisted)!;
      expect(actual.row.id, row.id);
      expect(
        actual.food.identity,
        'local-food:synthetic-installed-catalog-record',
      );
      expect(actual.food.basisGrams, 50);
      expect(actual.food.nutrients[FoodNutrient.calories], 120);
      expect(actual.food.nutrients[FoodNutrient.fiber], 0);
      expect(actual.food.nutrients[FoodNutrient.protein], isNull);
      expect(actual.food.nutrients[FoodNutrient.sodium], isNull);
      expect(actual.food.source.ref, contains('source:bil-mobile-catalog'));
      expect(actual.unitRule, isNull);
      expect(await database.select(database.mealItems).get(), isEmpty);
      expect(await database.select(database.meals).get(), isEmpty);
      expect(await database.select(database.foods).get(), hasLength(1));
    },
  );
}
