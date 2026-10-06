import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coach_food_v2_fixtures.dart';

void main() {
  CoachFoodUnitRule rule({
    String identity = 'synthetic-food',
    String preparedState = 'cooked',
    String inputUnit = 'item',
    double gramsPerUnit = 42,
    CoachFoodSourceKind kind = CoachFoodSourceKind.userFixed,
    String? ownerKey = 'account-a',
  }) => CoachFoodUnitRule(
    identity: identity,
    preparedState: preparedState,
    inputUnit: inputUnit,
    gramsPerUnit: gramsPerUnit,
    source: CoachFoodSourceEvidence(
      kind: kind,
      ref: 'synthetic:explicit-unit-rule',
      revision: 'fixture-unit-v1',
      ownerKey: ownerKey,
    ),
  );

  test(
    'user-fixed count is account-specific and has no universal fallback',
    () {
      final food = syntheticFood();
      final quantity = CoachFoodQuantities.fromUnit(
        food: food,
        amount: 3,
        inputUnit: 'item',
        rule: rule(),
        scope: syntheticOwner(),
        description:
            'Three synthetic items at the explicitly saved unit weight',
      );
      expect(quantity.grams, 126);
      expect(quantity.evidence.kind, CoachFoodQuantityKind.userDeclared);
      expect(quantity.evidence.confidence, isNull);
      expect(quantity.evidence.conversion!.source.ownerKey, 'account-a');
      expect(quantity.evidence.conversion!.inputAmount, 3);
      expect(quantity.evidence.conversion!.gramsPerUnit, 42);
      expect(
        () => CoachFoodQuantities.fromUnit(
          food: food,
          amount: 3,
          inputUnit: 'item',
          rule: null,
          scope: syntheticOwner(),
          description: 'No approved unit',
        ),
        throwsA(foodError('unit_weight_required')),
      );
      expect(
        () => CoachFoodQuantities.fromUnit(
          food: food,
          amount: 3,
          inputUnit: 'item',
          rule: rule(),
          scope: syntheticOwner(ownerKey: 'account-b'),
          description: 'Wrong owner',
        ),
        throwsA(foodError('evidence_owner_mismatch')),
      );
    },
  );

  test(
    'ml without density is refused; attributed conversion survives stored readback',
    () {
      final food = syntheticFood();
      expect(
        () => CoachFoodQuantities.fromUnit(
          food: food,
          amount: 200,
          inputUnit: 'ml',
          rule: null,
          scope: syntheticOwner(),
          description: 'No density is available',
        ),
        throwsA(foodError('density_required')),
      );
      final density = rule(
        inputUnit: 'ml',
        gramsPerUnit: 1.03,
        kind: CoachFoodSourceKind.label,
        ownerKey: null,
      );
      final quantity = CoachFoodQuantities.fromUnit(
        food: food,
        amount: 200,
        inputUnit: 'ml',
        rule: density,
        scope: syntheticOwner(),
        description: 'Synthetic volume with attributed density',
        confidence: CoachFoodConfidence(
          score: .8,
          basis: 'synthetic volume confidence',
        ),
      );
      final saved = CoachFoodPortion(
        food: food,
        quantity: quantity,
      ).encodeForStorage();
      final readback = CoachFoodPortion.decodeFromStorage(saved);
      expect(readback.quantity.grams, 206);
      expect(readback.quantity.evidence.conversion!.inputUnit, 'ml');
      expect(readback.quantity.evidence.conversion!.inputAmount, 200);
      expect(readback.quantity.evidence.conversion!.gramsPerUnit, 1.03);
      expect(
        readback.quantity.evidence.conversion!.source.ref,
        density.source.ref,
      );
      expect(
        readback.quantity.evidence.conversion!.source.revision,
        density.source.revision,
      );
      expect(readback.quantity.evidence.confidence!.score, .8);
      expect(readback.food.source.confidence, isNull);
      expect(readback.nutrients[FoodNutrient.calories], closeTo(329.6, 1e-9));
    },
  );

  test(
    'density and portion weights require the exact food and preparation',
    () {
      for (final mismatch in [
        rule(identity: 'other-food'),
        rule(preparedState: 'raw'),
        rule(inputUnit: 'ml', gramsPerUnit: 1.03),
      ]) {
        expect(
          () => CoachFoodQuantities.fromUnit(
            food: syntheticFood(),
            amount: 2,
            inputUnit: 'item',
            rule: mismatch,
            scope: syntheticOwner(),
            description: 'Wrong basis',
          ),
          throwsA(foodError('unit_rule_identity_mismatch')),
        );
      }
      expect(
        () => rule(inputUnit: 'ml', gramsPerUnit: 31),
        throwsA(foodError('invalid_density')),
      );
    },
  );

  test('quantity cannot silently contradict its recorded conversion', () {
    final conversion = CoachFoodQuantityConversion(
      inputAmount: 200,
      inputUnit: 'ml',
      gramsPerUnit: 1.03,
      source: rule().source,
    );
    expect(
      () => CoachFoodQuantity(
        grams: 200,
        evidence: CoachFoodQuantityEvidence(
          kind: CoachFoodQuantityKind.userDeclared,
          description: 'A false ml=g assumption',
          conversion: conversion,
        ),
      ),
      throwsA(foodError('quantity_conversion_mismatch')),
    );
  });

  test('an estimated conversion cannot claim measured quantity in storage', () {
    final conversion = CoachFoodQuantityConversion(
      inputAmount: 2,
      inputUnit: 'item',
      gramsPerUnit: 42,
      source: rule(kind: CoachFoodSourceKind.estimated).source,
    );
    for (final kind in [
      CoachFoodQuantityKind.measured,
      CoachFoodQuantityKind.userDeclared,
    ]) {
      expect(
        () => CoachFoodQuantityEvidence.fromJson({
          'kind': kind.wireName,
          'description': 'Synthetic dishonest conversion claim',
          'conversion': conversion.toJson(),
        }),
        throwsA(foodError('estimated_conversion_requires_estimated_quantity')),
      );
    }
  });

  test(
    'explicitly permitted estimates retain bounds without borrowing source confidence',
    () {
      final estimate = rule(
        kind: CoachFoodSourceKind.estimated,
        ownerKey: null,
        gramsPerUnit: 100,
      );
      expect(
        () => CoachFoodQuantities.fromUnit(
          food: syntheticFood(),
          amount: 2,
          inputUnit: 'item',
          rule: estimate,
          scope: syntheticOwner(),
          description: 'Unpermitted estimate',
        ),
        throwsA(foodError('estimate_not_allowed')),
      );
      final quantity = CoachFoodQuantities.fromUnit(
        food: syntheticFood(),
        amount: 2,
        inputUnit: 'item',
        rule: estimate,
        scope: syntheticOwner(),
        description: 'Two synthetic medium items',
        allowEstimate: true,
        lowerGrams: 160,
        upperGrams: 260,
        confidence: CoachFoodConfidence(score: .4, basis: 'synthetic estimate'),
      );
      expect(quantity.grams, 200);
      expect(quantity.evidence.kind, CoachFoodQuantityKind.estimated);
      expect(quantity.evidence.lowerGrams, 160);
      expect(quantity.evidence.upperGrams, 260);
      expect(quantity.evidence.confidence!.score, .4);
      expect(quantity.evidence.conversion!.source.confidence, isNull);
    },
  );

  test(
    'half a saved unit stays fractional, while explicit grams need no count guess',
    () {
      final half = CoachFoodQuantities.fromUnit(
        food: syntheticFood(),
        amount: .5,
        inputUnit: 'item',
        rule: rule(),
        scope: syntheticOwner(),
        description: 'Half of the approved synthetic unit',
      );
      expect(half.grams, 21);
      expect(
        CoachFoodQuantities.declaredGrams(
          80,
          description: 'An explicit weight',
        ).grams,
        80,
      );
    },
  );

  test(
    'invalid quantity intervals cannot manufacture a usable point estimate',
    () {
      CoachFoodQuantityEvidence interval(double? lower, double? upper) =>
          CoachFoodQuantityEvidence(
            kind: CoachFoodQuantityKind.estimated,
            description: 'Synthetic interval',
            lowerGrams: lower,
            upperGrams: upper,
          );
      expect(
        () => interval(80, null),
        throwsA(foodError('invalid_quantity_interval')),
      );
      expect(
        () => interval(null, 120),
        throwsA(foodError('invalid_quantity_interval')),
      );
      expect(
        () => interval(130, 120),
        throwsA(foodError('invalid_quantity_interval')),
      );
      expect(
        () => CoachFoodQuantity(grams: 100, evidence: interval(110, 120)),
        throwsA(foodError('quantity_outside_interval')),
      );
      for (final grams in [0.0, -.1, double.nan, double.infinity, 100001.0]) {
        expect(
          () => syntheticQuantity(grams),
          throwsA(foodError('invalid_number')),
        );
      }
    },
  );

  CoachFoodItemVersion version({
    String ownerKey = 'account-a',
    int id = 7,
    String uuid = 'stable-item-uuid',
    int revision = 3,
  }) => CoachFoodItemVersion(
    ownerKey: ownerKey,
    localId: id,
    uuid: uuid,
    revision: revision,
  );

  test(
    'quantity correction replaces at the stable item version using the original food basis',
    () {
      final original = CoachFoodPortion(
        food: syntheticFood(),
        quantity: syntheticQuantity(150),
        identityConfidence: CoachFoodConfidence(
          score: .86,
          basis: 'synthetic identity',
        ),
      );
      final proposal = CoachFoodReplacement.quantity(
        operationId: 'quantity-correction-1',
        expected: version(),
        original: original,
        quantity: syntheticQuantity(75),
      );
      proposal.checkCurrent(actual: version(), scope: syntheticOwner());
      expect(proposal.expected.uuid, 'stable-item-uuid');
      expect(proposal.expected.revision, 3);
      expect(proposal.replacement.food.digest, original.food.digest);
      expect(proposal.replacement.identityConfidence!.score, .86);
      expect(proposal.replacement.nutrients[FoodNutrient.calories], 120);
      expect(original.nutrients[FoodNutrient.calories], 240);
      final mutableCatalog = syntheticFood(
        nutrients: {...syntheticNutrients, FoodNutrient.calories: 400},
        revision: 'new-catalog',
      );
      expect(mutableCatalog.digest, isNot(original.food.digest));
      expect(proposal.replacement.nutrients[FoodNutrient.calories], 120);
      expect(proposal.argumentsDigest, hasLength(64));
    },
  );

  test(
    'replacement rejects stale revisions, recycled IDs and cross-owner rows',
    () {
      final proposal = CoachFoodReplacement(
        operationId: 'replace-1',
        expected: version(),
        replacement: syntheticPortion(),
      );
      for (final stale in [
        version(revision: 4),
        version(uuid: 'reused-local-id'),
        version(id: 8),
      ]) {
        expect(
          () => proposal.checkCurrent(actual: stale, scope: syntheticOwner()),
          throwsA(foodError('item_revision_conflict')),
        );
      }
      expect(
        () => proposal.checkCurrent(
          actual: version(ownerKey: 'account-b'),
          scope: syntheticOwner(),
        ),
        throwsA(foodError('owner_changed')),
      );
      expect(
        () => proposal.checkCurrent(
          actual: version(),
          scope: syntheticOwner(ownerKey: 'account-b'),
        ),
        throwsA(foodError('owner_changed')),
      );
    },
  );

  test(
    'a correction cannot carry another owner fixed snapshot and its digest includes evidence',
    () {
      final other = syntheticFood(
        kind: CoachFoodSourceKind.userFixed,
        ownerKey: 'account-b',
      );
      expect(
        () => CoachFoodReplacement(
          operationId: 'replace-2',
          expected: version(),
          replacement: syntheticPortion(food: other),
        ),
        throwsA(foodError('evidence_owner_mismatch')),
      );
      final first = CoachFoodReplacement(
        operationId: 'same-operation',
        expected: version(),
        replacement: syntheticPortion(),
      );
      final changed = CoachFoodReplacement(
        operationId: 'same-operation',
        expected: version(),
        replacement: syntheticPortion(
          food: syntheticFood(revision: 'changed-source-revision'),
        ),
      );
      expect(first.argumentsDigest, isNot(changed.argumentsDigest));
      expect(
        () => CoachFoodItemVersion(
          ownerKey: 'account-a',
          localId: 7,
          uuid: 'id',
          revision: 0,
        ),
        throwsA(foodError('invalid_revision')),
      );
    },
  );
}
