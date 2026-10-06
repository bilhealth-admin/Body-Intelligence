import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'food_basis_fixtures.dart';

void main() {
  test(
    'basis codec preserves full snapshot provenance and thirteen values',
    () {
      final snapshot = basisSnapshot();
      final raw = FoodBasisEvidence.encode(snapshot);
      expect(jsonDecode(raw), {
        'schema': 'bil.food.basis.v1',
        'food': snapshot.toJson(),
      });
      final evidence = FoodBasisEvidence.read(basisFood(raw: raw));
      expect(evidence.state, FoodBasisEvidenceState.valid);
      expect(evidence.isModern, isTrue);
      expect(evidence.isValid, isTrue);
      expect(evidence.basisGrams, 40);
      expect(evidence.snapshot!.digest, snapshot.digest);
      expect(evidence.snapshot!.identity, 'fixture-food-identity');
      expect(evidence.snapshot!.preparedState, 'cooked');
      expect(evidence.snapshot!.source.ref, 'fixture://nutrition-label');
      expect(evidence.snapshot!.source.revision, 'label-2');
      expect(evidence.snapshot!.source.confidence!.score, .8);
      expect(evidence.values, basisNutrients);
      expect(FoodBasisEvidence.projection(snapshot), basisNutrients);
      expect(FoodBasisEvidence.mask(snapshot), 2047);
      expect(FoodBasisEvidence.sourceLabel(snapshot), 'coach_food_v2:label');
    },
  );

  test('iron and vitamin C evidence never gets invented legacy mask bits', () {
    final snapshot = basisSnapshot(
      values: const {FoodNutrient.iron: 0, FoodNutrient.vitaminC: 8},
    );
    final evidence = FoodBasisEvidence.read(basisFood(snapshot: snapshot));
    expect(FoodBasisEvidence.mask(snapshot), 0);
    expect(evidence.state, FoodBasisEvidenceState.valid);
    expect(evidence.value(FoodNutrient.iron), 0);
    expect(evidence.value(FoodNutrient.vitaminC), 8);
    expect(evidence.value(FoodNutrient.calories), isNull);
    expect(evidence.values, hasLength(13));
  });

  test(
    'an owner-scoped fixed food refuses another owner without reinterpretation',
    () {
      final row = basisFood(
        snapshot: basisSnapshot(
          kind: CoachFoodSourceKind.userFixed,
          ownerKey: 'owner-a',
        ),
      );
      expect(FoodBasisEvidence.read(row).isValid, isTrue);
      expect(FoodBasisEvidence.read(row, ownerKey: 'owner-a').isValid, isTrue);
      final wrong = FoodBasisEvidence.read(row, ownerKey: 'owner-b');
      expect(wrong.state, FoodBasisEvidenceState.invalid);
      expect(wrong.isModern, isTrue);
      expect(wrong.snapshot, isNull);
      expect(wrong.values.values, everyElement(isNull));
    },
  );

  test('immutable evidence maps cannot be changed after validation', () {
    final evidence = FoodBasisEvidence.read(basisFood());
    expect(
      () => evidence.values[FoodNutrient.iron] = 99,
      throwsUnsupportedError,
    );
    expect(
      () =>
          FoodBasisEvidence.projection(evidence.snapshot!)[FoodNutrient.iron] =
              99,
      throwsUnsupportedError,
    );
    expect(evidence.value(FoodNutrient.iron), 2);
  });

  test('a large envelope fails closed before decoding its food', () {
    final raw = '${FoodBasisEvidence.encode(basisSnapshot())}${' ' * 65536}';
    final evidence = FoodBasisEvidence.read(basisFood(raw: raw));
    expect(evidence.state, FoodBasisEvidenceState.invalid);
    expect(evidence.values.values, everyElement(isNull));
    expect(evidence.basisGrams, isNull);
  });

  for (final invalid in <Object?>[
    null,
    'not a food',
    {'name': 'Incomplete food'},
    {
      ...basisSnapshot().toJson(),
      'nutrients': {...basisSnapshot().nutrients.toJson(), 'iron': -1},
    },
    {
      ...basisSnapshot().toJson(),
      'source': {'kind': 'reference', 'ref': 'claimed-reference'},
    },
    {...basisSnapshot().toJson(), 'verified': true},
  ]) {
    test('a malformed snapshot has no nutrient fallback: $invalid', () {
      final evidence = FoodBasisEvidence.read(
        basisFood(
          raw: jsonEncode({
            'schema': FoodBasisEvidence.schema,
            'food': invalid,
          }),
        ),
      );
      expect(evidence.state, FoodBasisEvidenceState.invalid);
      expect(evidence.values.values, everyElement(isNull));
    });
  }

  test(
    'unknown and nonfinite row columns cannot pass projection validation',
    () {
      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final row = basisFood().copyWith(iron: value);
        expect(
          FoodBasisEvidence.read(row).state,
          FoodBasisEvidenceState.invalid,
        );
      }
      final unknown = basisFood(
        snapshot: basisSnapshot(values: const {}),
      ).copyWith(iron: 1);
      expect(
        FoodBasisEvidence.read(unknown).state,
        FoodBasisEvidenceState.invalid,
      );
    },
  );

  test('a negative row value cannot be accepted as a rounded known zero', () {
    final row = basisFood(
      snapshot: basisSnapshot(values: const {FoodNutrient.iron: 0}),
    ).copyWith(iron: -1e-12);
    expect(FoodBasisEvidence.read(row).state, FoodBasisEvidenceState.invalid);
  });

  for (final source in <(String, bool)>[
    ('local', true),
    ('foundation', true),
    ('legacy', true),
    ('quick_add', false),
    ('BIL community imported', false),
    ('bil-mobile-catalog', false),
  ]) {
    test(
      'legacy required-core interpretation remains unchanged for ${source.$1}',
      () {
        final row = basisFood(
          snapshot: basisSnapshot(values: const {}),
          includeEvidence: false,
        ).copyWith(source: source.$1);
        final evidence = FoodBasisEvidence.read(row);
        expect(evidence.state, FoodBasisEvidenceState.legacy);
        expect(evidence.isModern, isFalse);
        expect(evidence.isValid, isTrue);
        expect(evidence.value(FoodNutrient.calories), source.$2 ? 0 : null);
        expect(evidence.value(FoodNutrient.iron), isNull);
        expect(evidence.value(FoodNutrient.vitaminC), isNull);
      },
    );
  }

  test(
    'database readback preserves an immutable basis and detects later catalog edits',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final original = basisFood();
      await database.into(database.foods).insert(original.toCompanion(true));
      final stored = await database.select(database.foods).getSingle();
      final evidence = FoodBasisEvidence.read(stored);
      expect(stored.foodEvidenceJson, original.foodEvidenceJson);
      expect(evidence.values, basisNutrients);
      expect(evidence.snapshot!.source.revision, 'label-2');
      await (database.update(database.foods)
            ..where((row) => row.id.equals(stored.id)))
          .write(const FoodsCompanion(protein: Value(15)));
      final edited = await database.select(database.foods).getSingle();
      final current = FoodBasisEvidence.read(edited);
      expect(current.state, FoodBasisEvidenceState.invalid);
      expect(current.values.values, everyElement(isNull));
      expect(evidence.value(FoodNutrient.protein), 10);
      expect(evidence.snapshot!.source.revision, 'label-2');
    },
  );
}
