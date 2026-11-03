import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nutritionOnly = ['nutrition_water'];
  const withoutSleep = [
    'nutrition_water',
    'training_activity',
    'weight_measurements_goal',
  ];
  const withoutWeight = [
    'nutrition_water',
    'sleep_habits',
    'training_activity',
  ];
  const allCategories = [
    'nutrition_water',
    'sleep_habits',
    'training_activity',
    'weight_measurements_goal',
  ];
  const cases = <String, List<String>>{
    'Review my day, using only my meals and water.': nutritionOnly,
    'Review my day from my nutrition and water only.': nutritionOnly,
    'راجع يومي من التغذية والماء فقط': nutritionOnly,
    'راجع يومي بس التغذية والماء': nutritionOnly,
    'راجع يومي فقط التغذية والماء': nutritionOnly,
    'Review my day, using only my workouts and steps.': ['training_activity'],
    'Review my day, only my sleep.': ['sleep_habits'],
    'راجع يومي، فقط وزني': ['weight_measurements_goal'],
    'Review my day, only my meals and water without changing my weight.':
        nutritionOnly,
    'Review my day without sleep.': withoutSleep,
    'Review my day excluding my weight.': withoutWeight,
    'Review my day but do not include my sleep.': withoutSleep,
    'راجع يومي دون النوم': withoutSleep,
    'راجع يومي باستثناء الوزن': withoutWeight,
    'راجع يومي بدون النوم': withoutSleep,
    // These constrain actions, not the fields used for this read-only review.
    'Review my day without changing my weight.': allCategories,
    'راجع يومي دون تغيير وزني': allCategories,
    'Review my day using only records shared in this request.': allCategories,
    'Review my day. I only slept 5 hours.': allCategories,
  };
  for (final entry in cases.entries) {
    test('day review respects explicit scope: ${entry.key}', () {
      final projection = projectCoachCloudContext(
        question: entry.key,
        context: _preparedContext(),
      );
      expect(projection.disclosure['categories'], entry.value);
      expect(
        projection.disclosure['included_context_fields'],
        projection.context.keys.toList()..sort(),
      );
      final encoded = jsonEncode(projection.context);
      if (!entry.value.contains('sleep_habits')) {
        expect(encoded, isNot(contains('sleepHours')));
        expect(encoded, isNot(contains('"sleep"')));
      }
      if (!entry.value.contains('weight_measurements_goal')) {
        expect(projection.context, isNot(contains('weight')));
        expect(encoded, isNot(contains('currentWeightKg')));
        expect(encoded, isNot(contains('private-profile-weight')));
      }
      if (!entry.value.contains('training_activity')) {
        expect(encoded, isNot(contains('exerciseEnergy')));
        expect(encoded, isNot(contains('"steps"')));
      }
    });
  }

  test(
    'restricted day review wire body omits other prepared fields and turns',
    () async {
      final cloud = _ReviewCloudSpy();
      final result = await LlamaCppLocalGateway(cloudAccess: cloud).answer(
        question: 'Review my day, using only my meals and water.',
        locale: 'en',
        languageDetected: true,
        context: _preparedContext(),
        conversation: const [
          CoachConversationTurn(
            role: 'user',
            content: 'Review my weight private-weight',
          ),
          CoachConversationTurn(
            role: 'assistant',
            content: 'Weight private-weight',
          ),
          CoachConversationTurn(
            role: 'user',
            content: 'Review my sleep private-sleep',
          ),
          CoachConversationTurn(
            role: 'assistant',
            content: 'Sleep private-sleep',
          ),
        ],
      );
      expect(result.answer?.text, 'Fixture review');
      expect(cloud.requests, hasLength(1));
      expect(cloud.consentReads, 1);
      final body = cloud.requests.single;
      expect((body['context_disclosure']! as Map)['categories'], nutritionOnly);
      expect(
        (body['context_disclosure']! as Map)['included_prior_turn_count'],
        0,
      );
      expect(jsonEncode(body), isNot(contains('private-weight')));
      expect(jsonEncode(body), isNot(contains('private-sleep')));
      expect(jsonEncode(body['context']), isNot(contains('currentWeightKg')));
      expect(
        jsonEncode(body['context']),
        isNot(contains('private-profile-weight')),
      );
      expect(jsonEncode(body['context']), isNot(contains('sleepHours')));
      expect(body['context']! as Map, isNot(contains('weight')));
    },
  );

  test('a restricted day review cannot re-enable withheld nutrition', () {
    final projection = projectCoachCloudContext(
      question: 'راجع يومي من التغذية والماء فقط',
      context: CoachContextSnapshot(
        generatedAt: DateTime.utc(2026, 11, 3),
        profile: const {},
        weights: const [],
        weightReadStatus: CoachWeightReadStatus.withheld,
        nutritionDays: const [],
        waterHistory: const [],
        activityHistory: const [
          {'day': '2026-11-03', 'steps': 3000},
        ],
        computedHealth: const {
          'today': {
            'exerciseEnergy': {'verifiedBurnedKcal': 150},
          },
        },
      ),
    );
    expect(projection.disclosure['categories'], isEmpty);
    expect(projection.context.keys, {'schema', 'generatedAt'});
  });

  test(
    'conflicting fields in one approved group fail closed for that group',
    () {
      final projection = projectCoachCloudContext(
        question: 'Review my day using only meals, without water.',
        context: _preparedContext(),
      );
      expect(projection.disclosure['categories'], isEmpty);
      expect(projection.context.keys, {'schema', 'generatedAt'});
    },
  );
}

CoachContextSnapshot _preparedContext() => CoachContextSnapshot(
  generatedAt: DateTime.utc(2026, 11, 3),
  profile: const {'currentWeightKg': 80, 'exercises': 3},
  weights: const [],
  weightReadStatus: CoachWeightReadStatus.verified,
  nutritionDays: const [],
  waterHistory: const [],
  activityHistory: const [
    {'day': '2026-11-03', 'steps': 4000, 'sleepHours': 7},
  ],
  computedHealth: const {
    'today': {
      'day': '2026-11-03',
      'nutrition': {'caloriesKcal': 500},
      'sleep': {'hours': 7},
      'exerciseEnergy': {'verifiedBurnedKcal': 200},
    },
  },
  explicitMemories: const [
    {'topic': 'nutrition weight', 'text': 'private-profile-weight'},
  ],
);

final class _ReviewCloudSpy implements CoachCloudAccess {
  int consentReads = 0;
  final requests = <Map<String, Object?>>[];
  @override
  bool get hasAuthenticatedSession => true;
  @override
  Future<Object?> readRemoteAiConsent() async {
    consentReads++;
    return const {'granted': true, 'policy_version': '3'};
  }

  @override
  Future<CoachCloudFunctionResponse> invokeCoach(
    Map<String, Object?> body,
  ) async {
    requests.add(body);
    return const CoachCloudFunctionResponse(
      status: 200,
      data: {'reply': 'Fixture review'},
    );
  }
}
