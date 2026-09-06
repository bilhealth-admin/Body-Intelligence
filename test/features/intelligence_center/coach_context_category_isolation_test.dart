import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const health = <String, Object?>{
    'status': 'ready',
    'bodyModelVersion': 'body-model-v1',
    'goalDirection': 'lose',
    'kilogramsToGoal': 5.0,
    'bmrKcal': 1750,
    'tdeeKcal': 2450,
    'bmiScreeningValue': 24.7,
    'waistToHeightRatio': 0.48,
    'expectedBodyFatPercent': 18.2,
    'expectedFatFreeMassKg': 63.4,
    'bodyFatEstimateMethod': 'circumference',
    'bodyFatEstimateUncertainty': 'lower',
    'bodyFatEstimateIssue': 'none',
    'healthyWaistScreeningUpperCm': 90.0,
    'obesityRiskScreening': 'no_elevated_bmi_screening_signal',
    'notice': 'Screening estimate only.',
    'dailyTargets': <String, Object?>{'proteinG': 150.0},
    'dailyTargetSources': <String, Object?>{'proteinG': 'saved_plan_override'},
    'mealTargets': <String, Object?>{
      'breakfast': <String, Object?>{'proteinG': 35.0},
    },
    'futureUnclassifiedComputedField': 'must-not-leak',
    'today': <String, Object?>{
      'day': '2026-09-05',
      'nutrition': <String, Object?>{'consumedCaloriesKcal': 800.0},
      'exerciseEnergy': <String, Object?>{
        'verifiedBurnedKcal': 320.0,
        'burnSource': 'connected_health',
      },
      'sleep': <String, Object?>{'hours': 7.5, 'source': 'connected_health'},
      'fasting': <String, Object?>{'status': 'active'},
      'bodyContext': <String, Object?>{
        'types': <String>['menstrual'],
      },
      'futureUnclassifiedTodayField': 'must-not-leak',
    },
  };

  Map<String, Object?> scoped({
    bool nutrition = false,
    bool training = false,
    bool habits = false,
    bool analytics = false,
  }) {
    return scopeCoachHealthForFocus(
      health: health,
      includeNutrition: nutrition,
      includeTraining: training,
      includeHabits: habits,
      includeAnalytics: analytics,
    );
  }

  Map<Object?, Object?> today(Map<String, Object?> value) =>
      value['today']! as Map<Object?, Object?>;

  test('nutrition exposes only nutrition payloads and their targets', () {
    final value = scoped(nutrition: true);

    expect(value.keys, <String>{
      'status',
      'dailyTargets',
      'dailyTargetSources',
      'mealTargets',
      'today',
    });
    expect(today(value).keys, <Object?>{'day', 'nutrition'});
    expect(value, isNot(contains('bmiScreeningValue')));
  });

  test(
    'training exposes connected exercise energy but not other categories',
    () {
      final value = scoped(training: true);

      expect(value.keys, <String>{'status', 'today'});
      expect(today(value).keys, <Object?>{'day', 'exerciseEnergy'});
      expect(
        (today(value)['exerciseEnergy']! as Map)['burnSource'],
        'connected_health',
      );
    },
  );

  test('habits exposes connected sleep, fasting, and body context only', () {
    final value = scoped(habits: true);

    expect(value.keys, <String>{'status', 'today'});
    expect(today(value).keys, <Object?>{
      'day',
      'sleep',
      'fasting',
      'bodyContext',
    });
    expect((today(value)['sleep']! as Map)['source'], 'connected_health');
  });

  test('analytics is an explicit allow-list and cannot reopen categories', () {
    final value = scoped(analytics: true);

    expect(value['bodyModelVersion'], 'body-model-v1');
    expect(value['bmiScreeningValue'], 24.7);
    expect(value['expectedFatFreeMassKg'], 63.4);
    expect(value, isNot(contains('dailyTargets')));
    expect(value, isNot(contains('mealTargets')));
    expect(value, isNot(contains('futureUnclassifiedComputedField')));
    expect(today(value).keys, <Object?>{'day'});
  });

  test('none retains only non-category envelope fields', () {
    final value = scoped();

    expect(value, <String, Object?>{
      'status': 'ready',
      'today': <String, Object?>{'day': '2026-09-05'},
    });
  });

  test('all 16 combinations include each category independently', () {
    for (var mask = 0; mask < 16; mask++) {
      final nutrition = mask & 1 != 0;
      final training = mask & 2 != 0;
      final habits = mask & 4 != 0;
      final analytics = mask & 8 != 0;
      final value = scoped(
        nutrition: nutrition,
        training: training,
        habits: habits,
        analytics: analytics,
      );
      final todayValue = today(value);
      final reason = 'category mask $mask';

      expect(value.containsKey('dailyTargets'), nutrition, reason: reason);
      expect(value.containsKey('mealTargets'), nutrition, reason: reason);
      expect(todayValue.containsKey('nutrition'), nutrition, reason: reason);
      expect(
        todayValue.containsKey('exerciseEnergy'),
        training,
        reason: reason,
      );
      expect(todayValue.containsKey('sleep'), habits, reason: reason);
      expect(todayValue.containsKey('fasting'), habits, reason: reason);
      expect(todayValue.containsKey('bodyContext'), habits, reason: reason);
      expect(value.containsKey('bmiScreeningValue'), analytics, reason: reason);
      expect(
        value.containsKey('futureUnclassifiedComputedField'),
        isFalse,
        reason: reason,
      );
      expect(
        todayValue.containsKey('futureUnclassifiedTodayField'),
        isFalse,
        reason: reason,
      );
    }
  });
}
