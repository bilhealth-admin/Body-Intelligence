import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_vision_contract.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_legacy_adapter.dart';

void main() {
  const coordinator = MealVisionCoordinator();

  test(
    'unified result preserves item uncertainty alternatives and telemetry',
    () async {
      final result = await coordinator.analyze(
        _Provider(_validResult()),
        const MealVisionRequest(
          bytes: <int>[1],
          mimeType: 'image/jpeg',
          locale: 'en',
        ),
      );
      expect(result.items.single.normalizedName, 'grilled chicken');
      expect(result.items.single.amount, 120);
      expect(result.items.single.unit, 'g');
      expect(
        result.items.single.alternatives.single.normalizedName,
        'roasted chicken',
      );
      expect(result.items.single.uncertainty, isNotEmpty);
      expect(result.provider, 'fixture-provider');
      expect(result.model, 'fixture-model');
      expect(result.latency, const Duration(milliseconds: 125));
      expect(result.usage?.images, 1);
      expect(result.cost?.amount, 0.25);
      expect(result.requiresReview, isTrue);
      expect(result.canAutoLog, isFalse);
      final roundTrip = MealVisionResult.fromMap(result.toMap());
      expect(roundTrip.items.single.normalizedName, 'grilled chicken');
      expect(roundTrip.canAutoLog, isFalse);
    },
  );

  test('empty item result is explicitly non-food', () async {
    await expectLater(
      coordinator.analyze(_Provider(_validResult(items: const [])), _request),
      throwsA(_failure(MealVisionFailure.nonFood)),
    );
  });

  test('malformed item and low confidence are distinct failures', () async {
    await expectLater(
      coordinator.analyze(
        _Provider(_validResult(items: <MealVisionItem>[_item(amount: 0)])),
        _request,
      ),
      throwsA(_failure(MealVisionFailure.malformed)),
    );
    await expectLater(
      coordinator.analyze(
        _Provider(_validResult(items: <MealVisionItem>[_item(confidence: .2)])),
        _request,
      ),
      throwsA(_failure(MealVisionFailure.lowConfidence)),
    );
  });

  test('unknown provider failures are normalized', () async {
    await expectLater(
      coordinator.analyze(const _ThrowingProvider(), _request),
      throwsA(_failure(MealVisionFailure.providerFailure)),
    );
  });

  test('malformed serialized provider payload is rejected', () {
    expect(
      () => MealVisionResult.fromMap(<String, Object?>{'items': 'wrong'}),
      throwsA(_failure(MealVisionFailure.malformed)),
    );
  });

  test('legacy gateway adapts without inventing a serving', () {
    final result = adaptLegacyMealImageAnalysis(
      const MealImageAnalysis(
        candidates: <MealImageCandidate>[
          MealImageCandidate(
            name: 'Rice',
            confidence: .8,
            evidence: 'portion uncertain',
            identificationProvider: 'fixture-provider',
            modelRevision: 'fixture-model',
            nutritionResolution:
                MealNutritionResolution.requiresVerifiedFoodMatch,
          ),
        ],
        notice: 'Review required',
        requestId: 'request-1',
      ),
      latency: const Duration(milliseconds: 10),
    );
    expect(result.items.single.unit, 'review-required');
    expect(result.items.single.warnings, isNotEmpty);
    expect(result.canAutoLog, isFalse);
    expect(result.usage, isNull);
    expect(result.cost, isNull);
  });
}

const _request = MealVisionRequest(
  bytes: <int>[1],
  mimeType: 'image/jpeg',
  locale: 'en',
);

Matcher _failure(MealVisionFailure failure) => isA<MealVisionException>()
    .having((error) => error.failure, 'failure', failure);

MealVisionItem _item({double amount = 120, double confidence = .9}) =>
    MealVisionItem(
      normalizedName: 'grilled chicken',
      amount: amount,
      unit: 'g',
      confidence: confidence,
      alternatives: const <MealVisionAlternative>[
        MealVisionAlternative(
          normalizedName: 'roasted chicken',
          confidence: .6,
        ),
      ],
      uncertainty: 'sauce not visible',
      warnings: const <String>['portion must be reviewed'],
    );

MealVisionResult _validResult({List<MealVisionItem>? items}) =>
    MealVisionResult(
      items: items ?? <MealVisionItem>[_item()],
      provider: 'fixture-provider',
      model: 'fixture-model',
      latency: const Duration(milliseconds: 125),
      usage: const MealVisionUsage(inputUnits: 20, outputUnits: 10, images: 1),
      cost: const MealVisionCost(amount: 0.25, currency: 'USD'),
      warnings: const <String>['review required'],
    );

class _Provider implements MealVisionProvider {
  const _Provider(this.result);
  final MealVisionResult result;
  @override
  String get providerId => 'fixture-provider';
  @override
  String get modelId => 'fixture-model';
  @override
  Future<MealVisionResult> analyze(MealVisionRequest request) async => result;
}

class _ThrowingProvider implements MealVisionProvider {
  const _ThrowingProvider();
  @override
  String get providerId => 'fixture-provider';
  @override
  String get modelId => 'fixture-model';
  @override
  Future<MealVisionResult> analyze(MealVisionRequest request) =>
      throw StateError('offline');
}
