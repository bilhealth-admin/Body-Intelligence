import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_history.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/physiological_reality_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'isolates mechanistic water drivers from energy-supported tissue change',
    () {
      final timeline = LocalIntelligenceTimeline(
        age: 36,
        heightCm: 181,
        gender: 'male',
        activityLevel: 'moderate',
        targetWeightKg: 88,
        decisionHistory: const <DecisionMemoryHistory>[],
        days: List.generate(14, (index) {
          return LocalDailyPhysiology(
            day: DateTime.utc(2026, 7, 1 + index),
            weightKg: index == 0
                ? 96
                : index == 13
                ? 95.2
                : null,
            caloriesKcal: 1800,
            proteinG: 140,
            carbsG: index < 7 ? 100 : 220,
            fatG: 60,
            sodiumMg: index < 7 ? 1800 : 3200,
            potassiumMg: 3000,
            waterMl: index < 7 ? 2200 : 3200,
            contextTypes: const [],
          );
        }),
      );
      const model = PhysiologicalRealityModel();
      final tdee = model.adaptiveTdee(timeline);
      final result = model.analyze(timeline, tdeeKcal: tdee);

      expect(tdee, greaterThan(1800));
      expect(result.estimatedTissueChangeKg, lessThan(0));
      expect(result.sodiumDriverKg, greaterThan(0));
      expect(result.carbohydrateDriverKg, greaterThan(0));
      expect(result.explanations, isNotEmpty);
      expect(result.confidence, inInclusiveRange(0, 1));
    },
  );
}
