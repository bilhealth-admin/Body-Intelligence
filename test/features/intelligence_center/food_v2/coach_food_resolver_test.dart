import 'dart:async';

import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coach_food_v2_fixtures.dart';

void main() {
  final query = CoachFoodQuery(
    concept: 'synthetic-concept',
    preparedState: 'cooked',
    localeTag: 'ar',
  );
  CoachFoodCandidate candidate({
    CoachFoodSnapshot? food,
    String concept = 'synthetic-concept',
    CoachFoodUnitRule? unitRule,
  }) => CoachFoodCandidate(
    concept: concept,
    food: food ?? syntheticFood(),
    unitRule: unitRule,
  );

  CoachFoodResolverPorts ports({
    Future<CoachFoodCandidate?> Function(String, CoachFoodQuery)? fixed,
    Future<List<CoachFoodCandidate>> Function(CoachFoodQuery)? catalog,
    Future<List<CoachFoodCandidate>> Function(CoachFoodQuery)? reference,
    Future<CoachFoodCandidate> Function(CoachFoodQuery)? estimate,
  }) => CoachFoodResolverPorts(
    fixed: fixed ?? (_, _) async => null,
    catalog: catalog ?? (_) async => [],
    reference: reference ?? (_) async => [],
    estimate:
        estimate ?? (_) async => throw StateError('Estimate must not run'),
  );

  test(
    'owned fixed nutrition takes priority before any catalog/provider lookup',
    () async {
      final fixed = candidate(
        food: syntheticFood(
          kind: CoachFoodSourceKind.userFixed,
          ownerKey: 'account-a',
        ),
      );
      final calls = <String>[];
      final result =
          await CoachFoodResolver.resolve(
                query: query,
                scope: syntheticOwner(),
                allowEstimate: true,
                ports: ports(
                  fixed: (owner, query) async {
                    calls.add('fixed:$owner');
                    return fixed;
                  },
                  catalog: (_) async {
                    calls.add('catalog');
                    return [candidate()];
                  },
                  reference: (_) async {
                    calls.add('reference');
                    return [candidate()];
                  },
                  estimate: (_) async {
                    calls.add('estimate');
                    return candidate();
                  },
                ),
              )
              as CoachResolvedFood;
      expect(result.path, CoachFoodResolutionPath.userFixed);
      expect(result.food.digest, fixed.food.digest);
      expect(calls, ['fixed:account-a']);
      expect(result.food.source.confidence, isNull);
    },
  );

  test(
    'fixed owner, preparation and source authority are independently checked',
    () async {
      for (final testCase in <(CoachFoodCandidate, String)>[
        (
          candidate(
            food: syntheticFood(
              kind: CoachFoodSourceKind.userFixed,
              ownerKey: 'account-b',
            ),
          ),
          'evidence_owner_mismatch',
        ),
        (
          candidate(
            food: syntheticFood(
              kind: CoachFoodSourceKind.userFixed,
              ownerKey: 'account-a',
              preparedState: 'raw',
            ),
          ),
          'fixed_food_identity_mismatch',
        ),
        (candidate(), 'fixed_source_not_authorized'),
      ]) {
        await expectLater(
          CoachFoodResolver.resolve(
            query: query,
            scope: syntheticOwner(),
            ports: ports(fixed: (_, _) async => testCase.$1),
          ),
          throwsA(foodError(testCase.$2)),
        );
      }
      expect(
        () => syntheticFood(kind: CoachFoodSourceKind.userFixed),
        throwsA(foodError('fixed_owner_required')),
      );
    },
  );

  test(
    'exact catalog match precedes reference and preserves trusted provenance',
    () async {
      final calls = <String>[];
      final result =
          await CoachFoodResolver.resolve(
                query: query,
                scope: syntheticOwner(),
                ports: ports(
                  catalog: (_) async {
                    calls.add('catalog');
                    return [candidate()];
                  },
                  reference: (_) async {
                    calls.add('reference');
                    return [candidate()];
                  },
                ),
              )
              as CoachResolvedFood;
      expect(result.path, CoachFoodResolutionPath.catalog);
      expect(result.food.source.ref, 'synthetic:test-only-reference');
      expect(result.food.source.revision, 'fixture-v1');
      expect(calls, ['catalog']);
    },
  );

  test(
    'wrong preparation is never substituted and ambiguous identity asks for clarification',
    () async {
      final mismatch =
          await CoachFoodResolver.resolve(
                query: query,
                scope: syntheticOwner(),
                ports: ports(
                  catalog: (_) async => [
                    candidate(food: syntheticFood(preparedState: 'raw')),
                  ],
                ),
              )
              as CoachFoodClarification;
      expect(mismatch.reason, CoachFoodClarificationReason.missingReference);
      final ambiguous =
          await CoachFoodResolver.resolve(
                query: query,
                scope: syntheticOwner(),
                ports: ports(
                  reference: (_) async => [candidate(), candidate()],
                ),
              )
              as CoachFoodClarification;
      expect(ambiguous.reason, CoachFoodClarificationReason.ambiguousIdentity);
    },
  );

  test(
    'catalog cannot grant itself estimated or user-fixed authority',
    () async {
      for (final food in [
        syntheticFood(kind: CoachFoodSourceKind.estimated),
        syntheticFood(
          kind: CoachFoodSourceKind.userFixed,
          ownerKey: 'account-a',
        ),
      ]) {
        await expectLater(
          CoachFoodResolver.resolve(
            query: query,
            scope: syntheticOwner(),
            ports: ports(catalog: (_) async => [candidate(food: food)]),
          ),
          throwsA(foodError('untrusted_resolver_source')),
        );
      }
    },
  );

  test(
    'missing reference cannot trigger an unpermitted generative estimate',
    () async {
      var calls = 0;
      final result = await CoachFoodResolver.resolve(
        query: query,
        scope: syntheticOwner(),
        ports: ports(
          estimate: (_) async {
            calls++;
            return candidate();
          },
        ),
      );
      expect(result, isA<CoachFoodClarification>());
      expect(calls, 0);
    },
  );

  test(
    'generated estimate loses invented identity/ref/revision/verification claims and unit grants',
    () async {
      Future<CoachResolvedFood> resolve(String revision, String ref) async {
        final model = syntheticFood(
          identity: 'invented-usda-food-id',
          ref: ref,
          revision: revision,
          sourceConfidence: CoachFoodConfidence(
            score: .91,
            basis: 'Invented USDA verification claim',
          ),
        );
        return await CoachFoodResolver.resolve(
              query: query,
              scope: syntheticOwner(),
              allowEstimate: true,
              ports: ports(
                estimate: (_) async => CoachFoodCandidate(
                  concept: query.concept,
                  food: model,
                  identityConfidence: CoachFoodConfidence(
                    score: .75,
                    basis: 'Another invented certification',
                  ),
                  unitRule: CoachFoodUnitRule(
                    identity: model.identity,
                    preparedState: model.preparedState,
                    inputUnit: 'item',
                    gramsPerUnit: 50,
                    source: CoachFoodSourceEvidence(
                      kind: CoachFoodSourceKind.userFixed,
                      ref: 'invented-owner-approval',
                      revision: 'fake-approved',
                      ownerKey: 'account-a',
                    ),
                  ),
                ),
              ),
            )
            as CoachResolvedFood;
      }

      final result = await resolve(
        'fake-usda-revision',
        'USDA:invented-reference',
      );
      final otherClaim = await resolve(
        'different-invented-revision',
        'Different fake reference',
      );
      expect(result.path, CoachFoodResolutionPath.estimate);
      expect(result.food.source.kind, CoachFoodSourceKind.estimated);
      expect(result.food.identity, startsWith('estimate:'));
      expect(result.food.identity, isNot('invented-usda-food-id'));
      expect(result.food.source.ref, startsWith('local-estimate:'));
      expect(result.food.source.revision, startsWith('sha256:'));
      expect(result.food.source.ref, otherClaim.food.source.ref);
      expect(result.food.source.revision, otherClaim.food.source.revision);
      expect(
        result.food.source.toJson().toString().toLowerCase(),
        isNot(contains('usda')),
      );
      expect(result.food.source.ownerKey, isNull);
      expect(result.food.source.confidence!.score, .91);
      expect(result.food.source.confidence!.basis, 'model_reported_estimate');
      expect(result.candidate.identityConfidence!.score, .75);
      expect(
        result.candidate.identityConfidence!.basis,
        'model_reported_identity',
      );
      expect(result.candidate.unitRule, isNull);
      final portion = CoachFoodPortion(
        food: result.food,
        identityConfidence: result.candidate.identityConfidence,
        quantity: CoachFoodQuantity(
          grams: 90,
          evidence: CoachFoodQuantityEvidence(
            kind: CoachFoodQuantityKind.estimated,
            description: 'Separately reviewed synthetic portion',
            confidence: CoachFoodConfidence(
              score: .28,
              basis: 'quantity-only estimate',
            ),
            lowerGrams: 70,
            upperGrams: 110,
          ),
        ),
      );
      expect(portion.food.source.confidence!.score, .91);
      expect(portion.quantity.evidence.confidence!.score, .28);
    },
  );

  test(
    'estimate still needs the exact interpreted concept and preparation',
    () async {
      await expectLater(
        CoachFoodResolver.resolve(
          query: query,
          scope: syntheticOwner(),
          allowEstimate: true,
          ports: ports(
            estimate: (_) async => candidate(concept: 'another-concept'),
          ),
        ),
        throwsA(foodError('estimate_identity_mismatch')),
      );
    },
  );

  for (final stage in ['fixed', 'catalog', 'reference', 'estimate']) {
    test(
      'owner A to B to A during $stage cannot reactivate the old resolution',
      () async {
        var current = CoachFoodOwnerStamp(ownerKey: 'account-a', epoch: 0);
        final scope = CoachFoodOwnerScope(
          captured: current,
          readCurrent: () => current,
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        final calls = <String>[];
        Future<void> boundary(String name) async {
          calls.add(name);
          if (stage == name) {
            entered.complete();
            await release.future;
          }
        }

        final result = CoachFoodResolver.resolve(
          query: query,
          scope: scope,
          allowEstimate: true,
          ports: ports(
            fixed: (_, _) async {
              await boundary('fixed');
              return null;
            },
            catalog: (_) async {
              await boundary('catalog');
              return [];
            },
            reference: (_) async {
              await boundary('reference');
              return [];
            },
            estimate: (_) async {
              await boundary('estimate');
              return candidate();
            },
          ),
        );
        final assertion = expectLater(
          result,
          throwsA(foodError('owner_changed')),
        );
        await entered.future;
        current = CoachFoodOwnerStamp(ownerKey: 'account-b', epoch: 1);
        current = CoachFoodOwnerStamp(ownerKey: 'account-a', epoch: 2);
        release.complete();
        await assertion;
        expect(calls.last, stage);
        current = scope.captured;
        expect(scope.check, throwsA(foodError('owner_changed')));
      },
    );
  }

  test(
    'explicit cancellation and callback failure never produce a resolved result',
    () async {
      final scope = syntheticOwner()..cancel();
      await expectLater(
        CoachFoodResolver.resolve(query: query, scope: scope, ports: ports()),
        throwsA(foodError('owner_changed')),
      );
      await expectLater(
        CoachFoodResolver.resolve(
          query: query,
          scope: syntheticOwner(),
          ports: ports(
            catalog: (_) async =>
                throw StateError('synthetic offline transport'),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'a reviewed batch retains owned fixed snapshots and rejects a different current owner',
    () {
      final owned = syntheticFood(
        kind: CoachFoodSourceKind.userFixed,
        ownerKey: 'account-a',
      );
      final review = CoachFoodReview([
        syntheticPortion(food: owned),
        syntheticPortion(),
      ]);
      review.checkOwner(syntheticOwner());
      expect(
        () => review.checkOwner(syntheticOwner(ownerKey: 'account-b')),
        throwsA(foodError('evidence_owner_mismatch')),
      );
    },
  );
}
