import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_history.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/physiological_reality_model.dart';
import 'package:body_intelligence_log/features/ai_platform/services/product_intelligence_behavior_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const behavior = ProductIntelligenceBehaviorModel();
  const physiology = PhysiologicalRealityModel();

  test(
    'sleep and activity evidence deterministically change candidate ranking',
    () {
      final supported = _timeline(sleepHours: 5.5, steps: 3500);
      final unsupported = _timeline(sleepHours: null, steps: null);

      final supportedEstimate = physiology.analyze(supported, tdeeKcal: 2400);
      final unsupportedEstimate = physiology.analyze(
        unsupported,
        tdeeKcal: 2400,
      );

      final supportedCandidates = behavior.candidates(
        timeline: supported,
        estimate: supportedEstimate,
        adaptiveTdeeKcal: 2400,
        averageIntakeKcal: 1850,
        plateauRisk: 0.35,
      );
      final unsupportedCandidates = behavior.candidates(
        timeline: unsupported,
        estimate: unsupportedEstimate,
        adaptiveTdeeKcal: 2400,
        averageIntakeKcal: 1850,
        plateauRisk: 0.35,
      );

      final sleep = supportedCandidates.singleWhere(
        (candidate) => candidate.id == 'protect-sleep',
      );
      final activity = supportedCandidates.singleWhere(
        (candidate) => candidate.id == 'increase-activity',
      );

      expect(sleep.evidenceIds, contains('local-sleep'));
      expect(activity.evidenceIds, contains('local-activity'));
      expect(sleep.rankingScore, greaterThan(0));
      expect(activity.rankingScore, greaterThan(0));
      expect(
        unsupportedCandidates.any(
          (candidate) => candidate.id == 'protect-sleep',
        ),
        isFalse,
      );
      expect(
        unsupportedCandidates.any(
          (candidate) => candidate.id == 'increase-activity',
        ),
        isFalse,
      );
    },
  );

  test(
    'better sleep and activity do not create unsupported recovery actions',
    () {
      final constrained = _timeline(sleepHours: 5.5, steps: 3500);
      final recovered = _timeline(sleepHours: 7.5, steps: 9000);

      final constrainedCandidates = behavior.candidates(
        timeline: constrained,
        estimate: physiology.analyze(constrained, tdeeKcal: 2400),
        adaptiveTdeeKcal: 2400,
        averageIntakeKcal: 1850,
        plateauRisk: 0.35,
      );
      final recoveredCandidates = behavior.candidates(
        timeline: recovered,
        estimate: physiology.analyze(recovered, tdeeKcal: 2400),
        adaptiveTdeeKcal: 2400,
        averageIntakeKcal: 1850,
        plateauRisk: 0.35,
      );

      expect(
        constrainedCandidates.any(
          (candidate) => candidate.id == 'protect-sleep',
        ),
        isTrue,
      );
      expect(
        constrainedCandidates.any(
          (candidate) => candidate.id == 'increase-activity',
        ),
        isTrue,
      );
      expect(
        recoveredCandidates.any((candidate) => candidate.id == 'protect-sleep'),
        isFalse,
      );
      expect(
        recoveredCandidates.any(
          (candidate) => candidate.id == 'increase-activity',
        ),
        isFalse,
      );
    },
  );
}

LocalIntelligenceTimeline _timeline({
  required double? sleepHours,
  required int? steps,
}) => LocalIntelligenceTimeline(
  age: 36,
  heightCm: 181,
  gender: 'male',
  activityLevel: 'moderate',
  targetWeightKg: 88,
  decisionHistory: const <DecisionMemoryHistory>[],
  days: List.generate(
    7,
    (index) => LocalDailyPhysiology(
      day: DateTime.utc(2026, 7, 1 + index),
      weightKg: index == 0
          ? 96
          : index == 6
          ? 95.5
          : null,
      caloriesKcal: 1850,
      proteinG: 135,
      carbsG: 155,
      fatG: 60,
      sodiumMg: 2200,
      potassiumMg: 3500,
      waterMl: 2800,
      sleepHours: sleepHours,
      steps: steps,
      contextTypes: const [],
    ),
  ),
);
