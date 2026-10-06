import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coach_food_v2_fixtures.dart';

void main() {
  test(
    'the strict contract preserves the exact thirteen native nutrient units',
    () {
      expect(FoodNutrient.values, hasLength(13));
      expect(
        CoachFoodNutrients.units.keys.toSet(),
        FoodNutrient.values.toSet(),
      );
      expect(CoachFoodNutrients.units[FoodNutrient.calories], 'kcal');
      expect(
        CoachFoodNutrients.units.values.where((unit) => unit == 'g'),
        hasLength(5),
      );
      expect(
        CoachFoodNutrients.units.values.where((unit) => unit == 'mg'),
        hasLength(7),
      );
      final scaled = CoachFoodNutrition.scale(syntheticFood(), 150);
      expect(scaled[FoodNutrient.calories], 240);
      expect(scaled[FoodNutrient.iron], closeTo(1.8, 1e-12));
      expect(scaled[FoodNutrient.vitaminC], 18);
      expect(scaled[FoodNutrient.potassium], 195);
    },
  );

  for (final nutrient in FoodNutrient.values) {
    test(
      '${nutrient.name}: unknown and a known zero remain distinct after scale/storage',
      () {
        final known = syntheticFood(nutrients: {nutrient: 0});
        final missing = syntheticFood(nutrients: const {});
        final recorded = syntheticPortion(food: known, grams: 230);
        final readback = CoachFoodPortion.decodeFromStorage(
          recorded.encodeForStorage(),
        );
        expect(readback.nutrients[nutrient], 0);
        expect(CoachFoodNutrition.scale(missing, 230)[nutrient], isNull);
        final total = CoachFoodNutrition.total([
          recorded,
          syntheticPortion(food: missing),
        ]);
        expect(total[nutrient].value, isNull);
        expect(total[nutrient].knownSubtotal, 0);
        expect(total[nutrient].knownItems, 1);
        expect(total[nutrient].missingItems, 1);
        expect(total[nutrient].coverage, .5);
        expect(total[nutrient].complete, isFalse);
      },
    );
  }

  test(
    'a zero-evidence measured food never becomes complete zero nutrition',
    () {
      final portion = CoachFoodPortion(
        food: syntheticFood(nutrients: const {}),
        quantity: CoachFoodQuantities.declaredGrams(
          80,
          kind: CoachFoodQuantityKind.measured,
          description: 'Synthetic scale measurement',
          confidence: CoachFoodConfidence(score: 1, basis: 'synthetic scale'),
        ),
      );
      final readback = CoachFoodPortion.decodeFromStorage(
        portion.encodeForStorage(),
      );
      for (final nutrient in FoodNutrient.values) {
        expect(readback.nutrients[nutrient], isNull);
        expect(
          CoachFoodNutrition.total([readback])[nutrient].complete,
          isFalse,
        );
      }
      expect(readback.food.source.confidence, isNull);
      expect(readback.quantity.evidence.confidence!.score, 1);
    },
  );

  test(
    'empty arithmetic has zero logged items without manufacturing food evidence',
    () {
      final total = CoachFoodNutrition.total(const []);
      expect(total[FoodNutrient.calories].value, 0);
      expect(total[FoodNutrient.calories].totalItems, 0);
      expect(total[FoodNutrient.calories].coverage, 0);
      expect(
        () => CoachFoodReview(const []),
        throwsA(foodError('invalid_batch_size')),
      );
    },
  );

  test(
    'partial subtotal is visible separately from unavailable complete total',
    () {
      final missing = syntheticFood(
        nutrients: {...syntheticNutrients, FoodNutrient.potassium: null},
      );
      final total = CoachFoodNutrition.total([
        syntheticPortion(grams: 150),
        syntheticPortion(food: missing),
      ]);
      expect(total[FoodNutrient.potassium].value, isNull);
      expect(total[FoodNutrient.potassium].knownSubtotal, 195);
      expect(total[FoodNutrient.calories].value, 400);
    },
  );

  test('source, identity and quantity confidence survive independently', () {
    final portion = CoachFoodPortion(
      food: syntheticFood(
        sourceConfidence: CoachFoodConfidence(
          score: .91,
          basis: 'synthetic source audit',
        ),
      ),
      identityConfidence: CoachFoodConfidence(
        score: .82,
        basis: 'synthetic identity match',
      ),
      quantity: CoachFoodQuantity(
        grams: 100,
        evidence: CoachFoodQuantityEvidence(
          kind: CoachFoodQuantityKind.estimated,
          description: 'Synthetic portion estimate',
          confidence: CoachFoodConfidence(
            score: .37,
            basis: 'synthetic quantity estimate',
          ),
          lowerGrams: 75,
          upperGrams: 140,
        ),
      ),
    );
    final copy = CoachFoodPortion.decodeFromStorage(portion.encodeForStorage());
    expect(copy.food.source.confidence!.score, .91);
    expect(copy.identityConfidence!.score, .82);
    expect(copy.quantity.evidence.confidence!.score, .37);
    expect(copy.quantity.evidence.lowerGrams, 75);
    expect(copy.quantity.evidence.upperGrams, 140);
    expect(copy.digest, portion.digest);
    expect(
      jsonDecode(copy.encodeForStorage())['schema'],
      'bil.food.portion.v1',
    );
  });

  test(
    'input maps, serialization output and batch lists cannot mutate snapshots',
    () {
      final values = Map<FoodNutrient, double?>.from(syntheticNutrients);
      final food = syntheticFood(nutrients: values);
      final digest = food.digest;
      values[FoodNutrient.calories] = 999;
      expect(food.nutrients[FoodNutrient.calories], 160);
      expect(
        () => food.nutrients.values[FoodNutrient.calories] = 999,
        throwsUnsupportedError,
      );
      final raw = food.toJson();
      (raw['nutrients']! as Map)[FoodNutrient.calories.name] = 999;
      (raw['source']! as Map)['ref'] = 'changed-after-serialization';
      expect(food.digest, digest);
      final items = [syntheticPortion(food: food)];
      final review = CoachFoodReview(items);
      items.clear();
      expect(review.items, hasLength(1));
      expect(() => review.items.clear(), throwsUnsupportedError);
      expect(review.totals[FoodNutrient.calories].value, 160);
    },
  );

  test(
    'canonical digest ignores JSON key order without ignoring actual source changes',
    () {
      final original = syntheticFood();
      final raw = original.toJson();
      final reversed = {
        for (final key in raw.keys.toList().reversed) key: raw[key],
      };
      expect(CoachFoodSnapshot.fromJson(reversed).digest, original.digest);
      expect(
        syntheticFood(revision: 'fixture-v2').digest,
        isNot(original.digest),
      );
    },
  );

  test(
    'cholesterol and extra source/food fields are rejected, not discarded',
    () {
      final nutrient = syntheticFood().toJson();
      (nutrient['nutrients']! as Map)['cholesterol'] = 5;
      expect(
        () => CoachFoodSnapshot.fromJson(nutrient),
        throwsA(foodError('unknown_field')),
      );
      final source = syntheticFood().toJson();
      (source['source']! as Map)['verified'] = true;
      expect(
        () => CoachFoodSnapshot.fromJson(source),
        throwsA(foodError('unknown_field')),
      );
      expect(
        () => CoachFoodSnapshot.fromJson({
          ...syntheticFood().toJson(),
          'confidence': 1,
        }),
        throwsA(foodError('unknown_field')),
      );
    },
  );

  for (final invalid in [double.nan, double.infinity, -1.0, '100', true]) {
    test('invalid nutrient payload rejected: $invalid', () {
      final raw = syntheticFood().toJson();
      (raw['nutrients']! as Map)['iron'] = invalid;
      expect(
        () => CoachFoodSnapshot.fromJson(raw),
        throwsA(foodError('invalid_number')),
      );
    });
  }

  test(
    'incomplete codecs, source claims and stored schema versions fail closed',
    () {
      expect(
        () => CoachFoodSnapshot.fromJson({'name': 'missing basis'}),
        throwsA(foodError('missing_field')),
      );
      expect(
        () => CoachFoodSourceEvidence.fromJson({
          'kind': 'USDA-verified-by-model',
          'ref': 'synthetic',
          'revision': '1',
        }),
        throwsA(foodError('invalid_source_kind')),
      );
      expect(
        () => CoachFoodPortion.decodeFromStorage('{broken'),
        throwsA(foodError('invalid_snapshot_json')),
      );
      expect(
        () => CoachFoodPortion.decodeFromStorage(
          jsonEncode({
            'schema': 'future-v2',
            'portion': syntheticPortion().toJson(),
          }),
        ),
        throwsA(foodError('unsupported_snapshot_schema')),
      );
      expect(
        () => CoachFoodPortion.decodeFromStorage(
          jsonEncode({
            'schema': CoachFoodPortion.storageSchema,
            'portion': syntheticPortion().toJson(),
            'verified': true,
          }),
        ),
        throwsA(foodError('unknown_field')),
      );
    },
  );

  test(
    'confidence cannot be inferred, negative, nonfinite or greater than one',
    () {
      expect(syntheticFood().source.confidence, isNull);
      for (final score in [-.1, 1.01, double.nan, double.infinity]) {
        expect(
          () => CoachFoodConfidence(score: score, basis: 'synthetic'),
          throwsA(foodError('invalid_number')),
        );
      }
      expect(
        () => CoachFoodConfidence(score: .8, basis: ''),
        throwsA(foodError('invalid_text')),
      );
    },
  );

  test(
    'source basis bounds and total-carbohydrate convention are enforced',
    () {
      expect(
        () => syntheticFood(nutrients: {FoodNutrient.calories: 1001}),
        throwsA(foodError('invalid_number')),
      );
      expect(
        () => syntheticFood(
          nutrients: {FoodNutrient.carbohydrates: 10, FoodNutrient.fiber: 11},
        ),
        throwsA(foodError('carbohydrate_basis_conflict')),
      );
      expect(
        syntheticFood(
          nutrients: {FoodNutrient.carbohydrates: 10},
        ).nutrients.netCarbohydrates,
        isNull,
      );
      expect(syntheticFood().nutrients.netCarbohydrates, 21);
      final missingFiber = syntheticFood(
        nutrients: {...syntheticNutrients, FoodNutrient.fiber: null},
      );
      expect(
        CoachFoodNutrition.total([
          syntheticPortion(),
          syntheticPortion(food: missingFiber),
        ]).netCarbohydrates,
        isNull,
      );
    },
  );

  test('250 deterministic portions sum from the original food basis', () {
    final food = syntheticFood();
    final grams = [for (var i = 0; i < 250; i++) (i * 37 % 311) + .125];
    final total = CoachFoodNutrition.total([
      for (final amount in grams) syntheticPortion(food: food, grams: amount),
    ]);
    final expected = CoachFoodNutrition.scale(
      food,
      grams.reduce((a, b) => a + b),
    );
    for (final nutrient in FoodNutrient.values) {
      expect(total[nutrient].value, closeTo(expected[nutrient]!, 1e-7));
    }
  });

  test(
    'bounded batch keeps all nutrients without permitting a 31-item proposal',
    () {
      final items = List.generate(30, (_) => syntheticPortion());
      expect(
        CoachFoodReview(items).totals[FoodNutrient.iron].value,
        closeTo(36, 1e-9),
      );
      expect(
        () => CoachFoodReview([...items, syntheticPortion()]),
        throwsA(foodError('invalid_batch_size')),
      );
    },
  );
}
