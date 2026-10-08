import 'dart:async';

import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_attempt.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_catalog_entry.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_food_bridge.dart';
import 'package:body_intelligence_log/features/nutrition/domain/barcode_identity.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../features/nutrition/food_basis_fixtures.dart';

// Every row, label, conversion and recognizer response in this file is synthetic.
// Food rows are normalized through the real local-row adapter; no database,
// network provider, model, recognizer, or persistence callback is instantiated.
const _syntheticBarcode = '1234567890128';
final _ownerA = LocalDatabaseScope.keyForOwner('synthetic-media-food-owner-a');
final _ownerB = LocalDatabaseScope.keyForOwner('synthetic-media-food-owner-b');
const _nutrients = <FoodNutrient, double?>{
  FoodNutrient.calories: 200,
  FoodNutrient.protein: 12,
  FoodNutrient.carbohydrates: 20,
  FoodNutrient.fat: 8,
  FoodNutrient.fiber: 3,
  FoodNutrient.sodium: 0,
};

void main() {
  group('local identity matching and explicit selection', () {
    test(
      'one local match still requires selection before an unclaimed review',
      () async {
        final state = _MediaState();
        final attempt = state.begin();
        final entry = _entry();
        var lookups = 0;
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (input) async {
            lookups++;
            expect(input.name, 'Synthetic local food');
            return [entry];
          },
        );

        final matches = await _matches(bridge, attempt, _photo());
        expect(lookups, 1);
        expect(matches.ambiguous, isFalse);
        expect(matches.candidates.single, same(entry));
        expect(attempt.isClaimed, isFalse);
        final ready = _select(bridge, matches, entry);
        expect(ready.review.items.single.food.digest, entry.food.digest);
        expect(ready.review.items.single.quantity.grams, 80);
        expect(
          ready.review.items.single.quantity.evidence.kind,
          CoachFoodQuantityKind.estimated,
        );
        expect(attempt.isClaimed, isFalse);
        expect(ready.attempt, same(attempt));
      },
    );

    test('no local match remains unresolved and claims no attempt', () async {
      final attempt = _MediaState().begin();
      final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => []);
      expect(
        await bridge.lookup(input: _photo(), attempt: attempt),
        _issue(CoachMediaFoodIssue.noMatch),
      );
      expect(attempt.isClaimed, isFalse);
      expect(attempt.isCurrent, isTrue);
    });

    test(
      'multiple foods remain ambiguous until one exact candidate is selected',
      () async {
        final first = _entry();
        final second = _entry(identity: 'synthetic-food-b', localId: 2);
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [first, second],
        );
        final attempt = _MediaState().begin();
        final matches = await _matches(bridge, attempt, _photo());

        expect(matches.ambiguous, isTrue);
        expect(matches.candidates, [first, second]);
        expect(attempt.isClaimed, isFalse);
        final ready = _select(bridge, matches, second);
        expect(ready.review.items.single.food.identity, second.food.identity);
        expect(ready.review.items, hasLength(1));
        expect(attempt.isClaimed, isFalse);
      },
    );

    test(
      'a reconstructed outside candidate cannot impersonate a selected hit',
      () async {
        final offered = _entry();
        final outside = _entry();
        expect(outside.food.digest, offered.food.digest);
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [offered],
        );
        final attempt = _MediaState().begin();
        final matches = await _matches(bridge, attempt, _photo());

        expect(
          bridge.select(matches: matches, selected: outside),
          _issue(CoachMediaFoodIssue.selectionRequired),
        );
        expect(attempt.isClaimed, isFalse);
      },
    );

    test(
      'duplicate complete local evidence collapses without hiding other foods',
      () async {
        final first = _entry(conversionUnit: 'ml');
        final sameEvidence = _entry(conversionUnit: 'ml');
        final other = _entry(identity: 'synthetic-food-b', localId: 2);
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [first, first, sameEvidence, other],
        );
        final matches = await _matches(bridge, _MediaState().begin(), _photo());

        expect(matches.candidates, hasLength(2));
        expect(
          matches.candidates.map((entry) => entry.food.identity),
          containsAll([first.food.identity, other.food.identity]),
        );
        expect(matches.ambiguous, isTrue);
      },
    );

    test(
      'same food identity with different nutrient evidence stays ambiguous',
      () async {
        final original = _entry();
        final revised = _entry(
          values: {..._nutrients, FoodNutrient.protein: 14},
        );
        expect(original.food.identity, revised.food.identity);
        expect(original.food.digest, isNot(revised.food.digest));
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [original, revised],
        );

        final matches = await _matches(bridge, _MediaState().begin(), _photo());
        expect(matches.candidates, hasLength(2));
        expect(matches.ambiguous, isTrue);
      },
    );

    test(
      'same food with conflicting documented densities needs explicit choice',
      () async {
        final first = _entry(conversionUnit: 'ml', gramsPerUnit: 1.04);
        final otherDensity = _entry(conversionUnit: 'ml', gramsPerUnit: 1.2);
        expect(first.food.digest, otherDensity.food.digest);
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [first, otherDensity],
        );
        final matches = await _matches(
          bridge,
          _MediaState().begin(),
          _photo(amount: 100, unit: 'ml'),
        );

        expect(matches.candidates, hasLength(2));
        expect(matches.ambiguous, isTrue);
        expect(
          _select(bridge, matches, first).review.items.single.quantity.grams,
          104,
        );
        expect(
          _select(
            bridge,
            matches,
            otherDensity,
          ).review.items.single.quantity.grams,
          120,
        );
      },
    );

    test(
      'foreign-owner food evidence cannot cross the catalog boundary',
      () async {
        final foreign = _entry(
          sourceKind: CoachFoodSourceKind.userFixed,
          evidenceOwner: _ownerB,
          normalizationOwner: _ownerB,
        );
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [foreign],
        );
        final attempt = _MediaState().begin();

        expect(
          await bridge.lookup(input: _photo(), attempt: attempt),
          _issue(CoachMediaFoodIssue.unavailable),
        );
        expect(attempt.isClaimed, isFalse);
      },
    );

    test(
      'foreign-owner conversion evidence cannot cross the catalog boundary',
      () async {
        final foreignRule = _entry(
          conversionUnit: 'ml',
          ruleOwner: _ownerB,
          normalizationOwner: _ownerB,
        );
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [foreignRule],
        );
        final attempt = _MediaState().begin();

        expect(
          await bridge.lookup(
            input: _photo(unit: 'ml'),
            attempt: attempt,
          ),
          _issue(CoachMediaFoodIssue.unavailable),
        );
        expect(attempt.isClaimed, isFalse);
      },
    );
  });

  group('untrusted model payload and nutrition provenance', () {
    test(
      'model authority, nutrients and grams claims never replace the local snapshot',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final attempt = _MediaState().begin();
        final input = CoachMediaFoodInput.fromUntrustedPhoto({
          'name': 'Synthetic local food',
          'amount': 80,
          'unit': 'g',
          'confidence': .99,
          'requestId': 'model-overridden-request',
          'barcode': _syntheticBarcode,
          'verified': true,
          'source': 'USDA FoodData Central',
          'sourceKind': 'reference',
          'fdcId': 'model-fabricated-id',
          'usdaId': 'model-fabricated-id',
          'identity': 'model-fabricated-id',
          'nutrients': {'calories': 99999, 'sodium': 88888, 'potassium': 77777},
          'calories': 99999,
          'quantityGrams': 50000,
          'grams': 50000,
          'quantityKind': 'measured',
          'quantity_kind': 'measured',
          'density': 9,
        }, requestId: 'photo:host-generated-request');
        final matches = await _matches(bridge, attempt, input);
        final ready = _select(bridge, matches, entry);
        final item = ready.review.items.single;

        expect(input.requestId, 'photo:host-generated-request');
        expect(input.source, CoachMediaFoodSource.photo);
        expect(input.barcode, isNull);
        expect(item.food.toJson(), entry.food.toJson());
        expect(item.food.source.kind, CoachFoodSourceKind.label);
        expect(
          item.food.source.ref,
          'synthetic://local-label/synthetic-food-a',
        );
        expect(item.food.source.confidence, isNull);
        expect(item.identityConfidence, isNull);
        expect(item.quantity.grams, 80);
        expect(item.quantity.evidence.kind, CoachFoodQuantityKind.estimated);
        // Recognition confidence does not establish weight uncertainty.
        expect(input.recognitionConfidence, .99);
        expect(item.quantity.evidence.confidence, isNull);
        expect(item.quantity.evidence.conversion, isNull);
        expect(item.quantity.evidence.description, contains(input.requestId));
        expect(item.nutrients[FoodNutrient.calories], 160);
        expect(item.nutrients[FoodNutrient.sodium], 0);
        expect(item.nutrients[FoodNutrient.potassium], isNull);
        expect(attempt.isClaimed, isFalse);
      },
    );

    test('a model-provided density cannot turn ml into grams', () async {
      final entry = _entry();
      final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
      final input = CoachMediaFoodInput.fromUntrustedPhoto({
        'name': 'Synthetic local food',
        'amount': 200,
        'unit': 'ml',
        'verified': true,
        'density': 1.04,
        'gramsPerUnit': 1.04,
        'grams': 208,
        'source': 'USDA',
      }, requestId: 'photo:model-density-is-not-evidence');
      final attempt = _MediaState().begin();
      final matches = await _matches(bridge, attempt, input);

      expect(
        bridge.select(matches: matches, selected: entry),
        _issue(CoachMediaFoodIssue.missingDensity),
      );
      expect(attempt.isClaimed, isFalse);
    });

    test(
      'known zero and unknown nutrients survive scaling and review handoff',
      () async {
        final entry = _entry(
          values: const {
            FoodNutrient.calories: 0,
            FoodNutrient.protein: 6,
            FoodNutrient.sodium: 0,
            FoodNutrient.iron: 0,
          },
        );
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final attempt = _MediaState().begin();
        final matches = await _matches(bridge, attempt, _photo(amount: 200));
        final ready = _select(bridge, matches, entry);
        final review = bridge.takeReview([ready])!;

        expect(review.items.single.nutrients[FoodNutrient.calories], 0);
        expect(review.items.single.nutrients[FoodNutrient.protein], 12);
        expect(review.items.single.nutrients[FoodNutrient.iron], 0);
        expect(review.items.single.nutrients[FoodNutrient.potassium], isNull);
        expect(review.totals[FoodNutrient.sodium].value, 0);
        expect(review.totals[FoodNutrient.sodium].complete, isTrue);
        expect(review.totals[FoodNutrient.potassium].value, isNull);
        expect(review.totals[FoodNutrient.potassium].missingItems, 1);
        expect(review.totals.netCarbohydrates, isNull);
      },
    );

    test(
      'an all-unknown local label stays all-unknown in a reviewed portion',
      () async {
        final entry = _entry(values: const {});
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final matches = await _matches(bridge, _MediaState().begin(), _photo());
        final ready = _select(bridge, matches, entry);

        expect(
          ready.review.items.single.nutrients.toJson().values,
          everyElement(isNull),
        );
        expect(
          ready.review.totals.values.values.map((value) => value.value),
          everyElement(isNull),
        );
      },
    );
  });

  group('quantity review and documented conversion', () {
    for (final amount in <double?>[
      null,
      0,
      -1,
      .0009,
      double.nan,
      double.infinity,
      100001,
    ]) {
      test(
        'missing or invalid amount $amount requires a quantity answer',
        () async {
          final entry = _entry();
          final bridge = CoachMediaFoodBridge(
            lookupLocal: (_) async => [entry],
          );
          final attempt = _MediaState().begin();
          final matches = await _matches(
            bridge,
            attempt,
            _photo(amount: amount),
          );

          expect(
            bridge.select(matches: matches, selected: entry),
            _issue(CoachMediaFoodIssue.missingQuantity),
          );
          expect(attempt.isClaimed, isFalse);
        },
      );
    }

    for (final unit in <String?>[null, '  ']) {
      test('missing unit $unit is a quantity question', () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final matches = await _matches(
          bridge,
          _MediaState().begin(),
          _photo(unit: unit),
        );
        expect(
          bridge.select(matches: matches, selected: entry),
          _issue(CoachMediaFoodIssue.missingQuantity),
        );
      });
    }

    test(
      'explicit user quantity resolves a missing amount without changing identity',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final input = _photo(amount: null, unit: null);
        final matches = await _matches(bridge, _MediaState().begin(), input);
        expect(
          bridge.select(matches: matches, selected: entry),
          _issue(CoachMediaFoodIssue.missingQuantity),
        );

        final ready = _select(
          bridge,
          matches,
          entry,
          reviewedInput: input.withUserQuantity(75, 'g'),
        );
        expect(ready.review.items.single.quantity.grams, 75);
        expect(
          ready.review.items.single.quantity.evidence.kind,
          CoachFoodQuantityKind.userDeclared,
        );
        expect(ready.review.items.single.quantity.evidence.confidence, isNull);
        expect(ready.review.items.single.food.digest, entry.food.digest);
        expect(ready.input.requestId, input.requestId);
      },
    );

    for (final quantity in <(double, String, double)>[
      (80, 'g', 80),
      (.25, 'kg', 250),
      (2, 'oz', 56.69904625),
      (1, 'lb', 453.59237),
      (500, 'mg', .5),
    ]) {
      test(
        'explicit ${quantity.$2} input reuses the existing mass converter',
        () async {
          final entry = _entry();
          final bridge = CoachMediaFoodBridge(
            lookupLocal: (_) async => [entry],
          );
          final matches = await _matches(
            bridge,
            _MediaState().begin(),
            _photo(amount: quantity.$1, unit: quantity.$2),
          );

          expect(
            _select(bridge, matches, entry).review.items.single.quantity.grams,
            closeTo(quantity.$3, 1e-12),
          );
        },
      );
    }

    test('ml without a documented local density is unresolved', () async {
      final entry = _entry();
      final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
      final matches = await _matches(
        bridge,
        _MediaState().begin(),
        _photo(amount: 200, unit: 'ml'),
      );
      expect(
        bridge.select(matches: matches, selected: entry),
        _issue(CoachMediaFoodIssue.missingDensity),
      );
    });

    test(
      'a documented item weight does not satisfy missing ml density',
      () async {
        final entry = _entry(conversionUnit: 'item', gramsPerUnit: 50);
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final matches = await _matches(
          bridge,
          _MediaState().begin(),
          _photo(amount: 200, unit: 'ml'),
        );
        expect(
          bridge.select(matches: matches, selected: entry),
          _issue(CoachMediaFoodIssue.missingDensity),
        );
      },
    );

    test(
      'documented density converts estimated volume but keeps the estimate flag',
      () async {
        final entry = _entry(conversionUnit: 'ml', gramsPerUnit: 1.04);
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final matches = await _matches(
          bridge,
          _MediaState().begin(),
          _photo(amount: 200, unit: 'ml', confidence: .75),
        );
        final quantity = _select(
          bridge,
          matches,
          entry,
        ).review.items.single.quantity;

        expect(quantity.grams, 208);
        expect(quantity.evidence.kind, CoachFoodQuantityKind.estimated);
        // Even a documented density cannot calibrate a model's amount guess.
        expect(matches.input.recognitionConfidence, .75);
        expect(quantity.evidence.confidence, isNull);
        expect(quantity.evidence.conversion!.inputAmount, 200);
        expect(quantity.evidence.conversion!.inputUnit, 'ml');
        expect(quantity.evidence.conversion!.gramsPerUnit, 1.04);
        expect(
          quantity.evidence.conversion!.source.toJson(),
          entry.unitRule!.source.toJson(),
        );
      },
    );

    test(
      'user-corrected volume retains documented density and declared evidence',
      () async {
        final entry = _entry(conversionUnit: 'ml');
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final input = _photo(amount: 200, unit: 'ml');
        final matches = await _matches(bridge, _MediaState().begin(), input);
        final quantity = _select(
          bridge,
          matches,
          entry,
          reviewedInput: input.withUserQuantity(100, 'ml'),
        ).review.items.single.quantity;

        expect(quantity.grams, 104);
        expect(quantity.evidence.kind, CoachFoodQuantityKind.userDeclared);
        expect(quantity.evidence.confidence, isNull);
        expect(quantity.evidence.conversion!.inputAmount, 100);
        expect(
          quantity.evidence.conversion!.source.ref,
          entry.unitRule!.source.ref,
        );
      },
    );

    test('counted items require an identity-bound unit weight', () async {
      final withoutRule = _entry();
      final withRule = _entry(conversionUnit: 'item', gramsPerUnit: 50);
      final bridge = CoachMediaFoodBridge(
        lookupLocal: (_) async => [withoutRule, withRule],
      );
      final matches = await _matches(
        bridge,
        _MediaState().begin(),
        _photo(amount: 2, unit: 'item'),
      );

      expect(matches.candidates, hasLength(2));
      expect(
        bridge.select(matches: matches, selected: withoutRule),
        _issue(CoachMediaFoodIssue.missingUnitWeight),
      );
      final quantity = _select(
        bridge,
        matches,
        withRule,
      ).review.items.single.quantity;
      expect(quantity.grams, 100);
      expect(quantity.evidence.kind, CoachFoodQuantityKind.estimated);
      expect(quantity.evidence.conversion!.inputUnit, 'item');
    });

    for (final unit in ['cup', 'serving', 'liter']) {
      test(
        '$unit does not receive an implicit serving or density fallback',
        () async {
          final entry = _entry(conversionUnit: 'ml');
          final bridge = CoachMediaFoodBridge(
            lookupLocal: (_) async => [entry],
          );
          final matches = await _matches(
            bridge,
            _MediaState().begin(),
            _photo(amount: 1, unit: unit),
          );
          expect(
            bridge.select(matches: matches, selected: entry),
            _issue(CoachMediaFoodIssue.unsupportedUnit),
          );
        },
      );
    }

    test(
      'quantity correction cannot replace request, source, name or barcode identity',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final input = _photo();
        final matches = await _matches(bridge, _MediaState().begin(), input);
        for (final replacement in [
          CoachMediaFoodInput(
            source: input.source,
            requestId: 'other-request',
            name: input.name,
            amount: 100,
            unit: 'g',
          ),
          CoachMediaFoodInput(
            source: CoachMediaFoodSource.barcode,
            requestId: input.requestId,
            name: input.name,
            amount: 100,
            unit: 'g',
          ),
          CoachMediaFoodInput(
            source: input.source,
            requestId: input.requestId,
            name: 'different food',
            amount: 100,
            unit: 'g',
          ),
          CoachMediaFoodInput(
            source: input.source,
            requestId: input.requestId,
            name: input.name,
            barcode: _syntheticBarcode,
            amount: 100,
            unit: 'g',
          ),
        ]) {
          expect(
            bridge.select(
              matches: matches,
              selected: entry,
              reviewedInput: replacement,
            ),
            _issue(CoachMediaFoodIssue.invalidInput),
          );
        }
        expect(matches.attempt.isClaimed, isFalse);
      },
    );
  });

  group('barcode and invalid input gates', () {
    for (final barcode in ['', 'bad', '1234', '1234567890123']) {
      test(
        'invalid barcode "$barcode" never invokes the local lookup',
        () async {
          var lookups = 0;
          final bridge = CoachMediaFoodBridge(
            lookupLocal: (_) async {
              lookups++;
              return [_entry()];
            },
          );
          final attempt = _MediaState().begin();

          expect(
            await bridge.lookup(input: _barcode(barcode), attempt: attempt),
            _issue(CoachMediaFoodIssue.invalidBarcode),
          );
          expect(lookups, 0);
          expect(attempt.isClaimed, isFalse);
        },
      );
    }

    test(
      'valid barcode alone does not supply a trusted food or nutrition',
      () async {
        expect(BarcodeIdentity.parse(_syntheticBarcode).isValid, isTrue);
        final unverifiedRow = basisFood(
          includeEvidence: false,
        ).copyWith(barcode: const Value(_syntheticBarcode));
        final normalized = CoachMediaCatalogEntry.fromLocalFood(
          unverifiedRow,
          ownerKey: _ownerA,
        );
        expect(normalized, isNull);
        var lookups = 0;
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (input) async {
            lookups++;
            expect(input.barcode, _syntheticBarcode);
            return [?normalized];
          },
        );
        final attempt = _MediaState().begin();

        expect(
          await bridge.lookup(
            input: _barcode(_syntheticBarcode),
            attempt: attempt,
          ),
          _issue(CoachMediaFoodIssue.noMatch),
        );
        expect(lookups, 1);
        expect(attempt.isClaimed, isFalse);
      },
    );

    test(
      'valid barcode uses separately matched local evidence after explicit selection',
      () async {
        final entry = _entry(barcode: _syntheticBarcode);
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final attempt = _MediaState().begin();
        final input = _barcode(_syntheticBarcode);
        final matches = await _matches(bridge, attempt, input);
        expect(attempt.isClaimed, isFalse);
        final ready = _select(bridge, matches, entry);

        expect(ready.review.items.single.food.toJson(), entry.food.toJson());
        expect(
          ready.review.items.single.food.source.kind,
          CoachFoodSourceKind.label,
        );
        expect(
          ready.review.items.single.food.source.ref,
          isNot(contains(_syntheticBarcode)),
        );
        expect(
          ready.review.items.single.food.source.ref,
          isNot(contains('USDA')),
        );
        expect(ready.review.items.single.food.source.confidence, isNull);
        expect(
          ready.review.items.single.quantity.evidence.description,
          contains('barcode:'),
        );
        expect(attempt.isClaimed, isFalse);
      },
    );

    test('invalid photo identity never reaches the catalog callback', () async {
      var lookups = 0;
      final bridge = CoachMediaFoodBridge(
        lookupLocal: (_) async {
          lookups++;
          return [_entry()];
        },
      );
      for (final input in [
        _photo(requestId: 'invalid/request'),
        _photo(requestId: ''),
        _photo(name: null),
        _photo(name: '  '),
        _photo(name: 'synthetic\nfood'),
        _photo(name: 'x' * 201),
      ]) {
        final attempt = _MediaState().begin();
        expect(
          await bridge.lookup(input: input, attempt: attempt),
          _issue(CoachMediaFoodIssue.invalidInput),
        );
        expect(attempt.isClaimed, isFalse);
      }
      expect(lookups, 0);
    });
  });

  group('delayed callbacks and request lifetime', () {
    for (final change in [
      'owner',
      'ownerRoundTrip',
      'conversation',
      'request',
      'permission',
      'cancel',
      'dispose',
      'readerDisposed',
    ]) {
      test(
        '$change while local lookup is delayed rejects the returned candidates',
        () async {
          final state = _MediaState();
          final attempt = state.begin();
          final pending = Completer<List<CoachMediaCatalogEntry>>();
          final entry = _entry();
          var lookups = 0;
          final bridge = CoachMediaFoodBridge(
            lookupLocal: (_) {
              lookups++;
              return pending.future;
            },
          );
          final outcome = bridge.lookup(input: _photo(), attempt: attempt);
          expect(lookups, 1);
          state.invalidate(change, attempt);
          pending.complete([entry]);

          expect(await outcome, _issue(CoachMediaFoodIssue.staleRequest));
          expect(attempt.isClaimed, isFalse);
          expect(attempt.isCurrent, isFalse);
        },
      );
    }

    test(
      'permission denied before lookup never opens the catalog port',
      () async {
        final state = _MediaState()..authorized = false;
        final attempt = state.begin();
        var lookups = 0;
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async {
            lookups++;
            return [_entry()];
          },
        );

        expect(
          await bridge.lookup(input: _photo(), attempt: attempt),
          _issue(CoachMediaFoodIssue.staleRequest),
        );
        expect(lookups, 0);
        state.authorized = true;
        expect(
          await bridge.lookup(input: _photo(), attempt: attempt),
          _issue(CoachMediaFoodIssue.staleRequest),
        );
        expect(lookups, 0);
      },
    );

    test(
      'lookup failure reports unavailable without claiming or fabricating a match',
      () async {
        final attempt = _MediaState().begin();
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async =>
              throw StateError('synthetic unavailable local lookup'),
        );

        expect(
          await bridge.lookup(input: _photo(), attempt: attempt),
          _issue(CoachMediaFoodIssue.unavailable),
        );
        expect(attempt.isClaimed, isFalse);
        expect(attempt.isCurrent, isTrue);
      },
    );

    test(
      'a late lookup error after cancellation remains stale rather than retryable',
      () async {
        final state = _MediaState();
        final attempt = state.begin();
        final pending = Completer<List<CoachMediaCatalogEntry>>();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) => pending.future);
        final outcome = bridge.lookup(input: _photo(), attempt: attempt);
        attempt.cancel();
        pending.completeError(StateError('synthetic delayed lookup failure'));

        expect(await outcome, _issue(CoachMediaFoodIssue.staleRequest));
        expect(attempt.isClaimed, isFalse);
      },
    );

    test(
      'a replaced request cannot use a selection from its earlier matches',
      () async {
        final state = _MediaState();
        final attempt = state.begin();
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final matches = await _matches(bridge, attempt, _photo());
        state.requestGeneration++;

        expect(
          bridge.select(matches: matches, selected: entry),
          _issue(CoachMediaFoodIssue.staleRequest),
        );
        expect(attempt.isClaimed, isFalse);
      },
    );

    for (final change in [
      'owner',
      'conversation',
      'request',
      'permission',
      'dispose',
    ]) {
      test('$change after review prevents its handoff', () async {
        final state = _MediaState();
        final attempt = state.begin();
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final matches = await _matches(bridge, attempt, _photo());
        final ready = _select(bridge, matches, entry);
        state.invalidate(change, attempt);

        expect(bridge.takeReview([ready]), isNull);
        expect(attempt.isClaimed, isFalse);
      });
    }

    test(
      'a fresh retry can finish while the old delayed result stays rejected',
      () async {
        final state = _MediaState();
        final firstAttempt = state.begin();
        final pendingOld = Completer<List<CoachMediaCatalogEntry>>();
        final entry = _entry();
        var lookups = 0;
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (input) {
            lookups++;
            return input.requestId == 'photo:old'
                ? pendingOld.future
                : Future.value([entry]);
          },
        );
        final oldOutcome = bridge.lookup(
          input: _photo(requestId: 'photo:old'),
          attempt: firstAttempt,
        );
        state.requestGeneration++;
        final retry = state.begin();
        final matches = await _matches(
          bridge,
          retry,
          _photo(requestId: 'photo:retry'),
        );
        final ready = _select(bridge, matches, entry);
        expect(bridge.takeReview([ready]), isNotNull);
        pendingOld.complete([entry]);

        expect(await oldOutcome, _issue(CoachMediaFoodIssue.staleRequest));
        expect(firstAttempt.isClaimed, isFalse);
        expect(retry.isClaimed, isTrue);
        expect(lookups, 2);
      },
    );
  });

  group('one handoff per reviewed batch', () {
    test(
      'empty batches and duplicate takeReview calls cannot make extra handoffs',
      () async {
        final entry = _entry();
        var lookups = 0;
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async {
            lookups++;
            return [entry];
          },
        );
        final attempt = _MediaState().begin();
        expect(bridge.takeReview([]), isNull);
        final matches = await _matches(bridge, attempt, _photo());
        final ready = _select(bridge, matches, entry);
        expect(bridge.takeReview([ready])!.items, hasLength(1));
        expect(bridge.takeReview([ready]), isNull);
        expect(attempt.isCurrent, isTrue);
        expect(attempt.isClaimed, isTrue);
        expect(
          await bridge.lookup(input: _photo(), attempt: attempt),
          _issue(CoachMediaFoodIssue.staleRequest),
        );
        expect(lookups, 1);
      },
    );

    test(
      'multiple selected foods in the same attempt and request combine once',
      () async {
        final first = _entry();
        final second = _entry(
          identity: 'synthetic-food-b',
          localId: 2,
          values: const {FoodNutrient.calories: 100, FoodNutrient.protein: 0},
        );
        final bridge = CoachMediaFoodBridge(
          lookupLocal: (_) async => [first, second],
        );
        final attempt = _MediaState().begin();
        final firstMatches = await _matches(
          bridge,
          attempt,
          _photo(name: 'Synthetic first food', amount: 50),
        );
        final secondMatches = await _matches(
          bridge,
          attempt,
          _photo(name: 'Synthetic second food', amount: 100),
        );
        final firstReady = _select(bridge, firstMatches, first);
        final secondReady = _select(bridge, secondMatches, second);
        expect(attempt.isClaimed, isFalse);

        final review = bridge.takeReview([firstReady, secondReady])!;
        expect(review.items, hasLength(2));
        expect(review.items.map((item) => item.food.identity), [
          first.food.identity,
          second.food.identity,
        ]);
        expect(review.totals[FoodNutrient.calories].value, 200);
        expect(review.totals[FoodNutrient.protein].value, 6);
        expect(review.totals[FoodNutrient.sodium].value, isNull);
        expect(review.totals[FoodNutrient.sodium].knownSubtotal, 0);
        expect(review.totals[FoodNutrient.sodium].missingItems, 1);
        expect(bridge.takeReview([secondReady, firstReady]), isNull);
      },
    );

    test(
      'a batch cannot mix distinct attempts even when owner and request ID match',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final state = _MediaState();
        final firstAttempt = state.begin();
        final secondAttempt = state.begin();
        final first = _select(
          bridge,
          await _matches(bridge, firstAttempt, _photo()),
          entry,
        );
        final second = _select(
          bridge,
          await _matches(bridge, secondAttempt, _photo()),
          entry,
        );

        expect(bridge.takeReview([first, second]), isNull);
        expect(firstAttempt.isClaimed, isFalse);
        expect(secondAttempt.isClaimed, isFalse);
      },
    );

    test(
      'a batch cannot mix different request IDs inside the same attempt',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final attempt = _MediaState().begin();
        final first = _select(
          bridge,
          await _matches(bridge, attempt, _photo(requestId: 'photo:first')),
          entry,
        );
        final second = _select(
          bridge,
          await _matches(bridge, attempt, _photo(requestId: 'photo:second')),
          entry,
        );

        expect(bridge.takeReview([first, second]), isNull);
        expect(attempt.isClaimed, isFalse);
      },
    );

    test(
      'repeating the same ready item cannot double its portion within one batch',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final attempt = _MediaState().begin();
        final matches = await _matches(bridge, attempt, _photo());
        final ready = _select(bridge, matches, entry);

        expect(bridge.takeReview([ready, ready]), isNull);
        expect(attempt.isClaimed, isFalse);
        expect(bridge.takeReview([ready])!.items, hasLength(1));
      },
    );

    test(
      'distinct recognized portions may legitimately use the same local food',
      () async {
        final entry = _entry();
        final bridge = CoachMediaFoodBridge(lookupLocal: (_) async => [entry]);
        final attempt = _MediaState().begin();
        final first = _select(
          bridge,
          await _matches(bridge, attempt, _photo(amount: 50)),
          entry,
        );
        final second = _select(
          bridge,
          await _matches(bridge, attempt, _photo(amount: 25)),
          entry,
        );

        final review = bridge.takeReview([first, second])!;
        expect(review.items, hasLength(2));
        expect(review.items.map((item) => item.quantity.grams), [50, 25]);
        expect(review.totals[FoodNutrient.calories].value, 150);
      },
    );
  });
}

Matcher _issue(CoachMediaFoodIssue issue) => isA<CoachMediaFoodUnresolved>()
    .having((outcome) => outcome.issue, 'issue', issue);

CoachMediaFoodInput _photo({
  String requestId = 'photo:synthetic-request',
  String? name = 'Synthetic local food',
  double? amount = 80,
  String? unit = 'g',
  double? confidence = .7,
}) => CoachMediaFoodInput.fromUntrustedPhoto({
  'name': name,
  'amount': amount,
  'unit': unit,
  'confidence': confidence,
}, requestId: requestId);

CoachMediaFoodInput _barcode(String barcode) => CoachMediaFoodInput(
  source: CoachMediaFoodSource.barcode,
  requestId: 'barcode:synthetic-request',
  barcode: barcode,
  amount: 80,
  unit: 'g',
);

CoachMediaCatalogEntry _entry({
  String identity = 'synthetic-food-a',
  int localId = 1,
  Map<FoodNutrient, double?> values = _nutrients,
  CoachFoodSourceKind sourceKind = CoachFoodSourceKind.label,
  String? evidenceOwner,
  String? normalizationOwner,
  String? conversionUnit,
  double gramsPerUnit = 1.04,
  String? ruleOwner,
  String? barcode,
}) {
  final snapshot = CoachFoodSnapshot(
    identity: identity,
    name: 'Synthetic local food $localId',
    preparedState: 'synthetic-as-listed',
    basisGrams: 100,
    nutrients: CoachFoodNutrients(values),
    source: CoachFoodSourceEvidence(
      kind: sourceKind,
      ref: 'synthetic://local-label/$identity',
      revision: 'synthetic-label-v1',
      ownerKey: evidenceOwner,
    ),
  );
  final row = basisFood(snapshot: snapshot).copyWith(
    id: localId,
    uuid: 'synthetic-local-row-$localId',
    barcode: Value(barcode),
  );
  final rule = conversionUnit == null
      ? null
      : CoachFoodUnitRule(
          identity: snapshot.identity,
          preparedState: snapshot.preparedState,
          inputUnit: conversionUnit,
          gramsPerUnit: gramsPerUnit,
          source: CoachFoodSourceEvidence(
            kind: ruleOwner == null
                ? CoachFoodSourceKind.label
                : CoachFoodSourceKind.userFixed,
            ref: 'synthetic://local-conversion/$identity/$conversionUnit',
            revision: 'synthetic-conversion-v1',
            ownerKey: ruleOwner,
          ),
        );
  return CoachMediaCatalogEntry.fromLocalFood(
    row,
    ownerKey: normalizationOwner ?? _ownerA,
    unitRule: rule,
  )!;
}

Future<CoachMediaFoodMatches> _matches(
  CoachMediaFoodBridge bridge,
  CoachMediaAttempt attempt,
  CoachMediaFoodInput input,
) async {
  final outcome = await bridge.lookup(input: input, attempt: attempt);
  expect(outcome, isA<CoachMediaFoodMatches>());
  return outcome as CoachMediaFoodMatches;
}

CoachMediaFoodReady _select(
  CoachMediaFoodBridge bridge,
  CoachMediaFoodMatches matches,
  CoachMediaCatalogEntry entry, {
  CoachMediaFoodInput? reviewedInput,
}) {
  final outcome = bridge.select(
    matches: matches,
    selected: entry,
    reviewedInput: reviewedInput,
  );
  expect(outcome, isA<CoachMediaFoodReady>());
  return outcome as CoachMediaFoodReady;
}

final class _MediaState {
  CoachFoodOwnerStamp owner = CoachFoodOwnerStamp(ownerKey: _ownerA, epoch: 0);
  int conversationEpoch = 0;
  int requestGeneration = 0;
  bool authorized = true;
  bool readerDisposed = false;

  CoachMediaAttempt begin() => CoachMediaAttempt(
    ownerScope: CoachFoodOwnerScope(
      captured: owner,
      readCurrent: () {
        if (readerDisposed) {
          throw StateError('synthetic disposed owner observer');
        }
        return owner;
      },
    ),
    conversationEpoch: conversationEpoch,
    requestGeneration: requestGeneration,
    readConversationEpoch: () => conversationEpoch,
    readRequestGeneration: () => requestGeneration,
    isAuthorized: () => authorized,
  );

  void invalidate(String change, CoachMediaAttempt attempt) {
    switch (change) {
      case 'owner':
        owner = CoachFoodOwnerStamp(ownerKey: _ownerB, epoch: 1);
      case 'ownerRoundTrip':
        owner = CoachFoodOwnerStamp(ownerKey: _ownerB, epoch: 1);
        attempt.ownerScope.cancel();
        owner = CoachFoodOwnerStamp(ownerKey: _ownerA, epoch: 2);
      case 'conversation':
        conversationEpoch++;
      case 'request':
        requestGeneration++;
      case 'permission':
        authorized = false;
      case 'cancel':
        attempt.cancel();
      case 'dispose':
        attempt.dispose();
      case 'readerDisposed':
        readerDisposed = true;
      default:
        throw ArgumentError.value(change, 'change');
    }
  }
}
