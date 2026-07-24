import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/physiological_reality_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'forecast remains deterministic and bounded for identical local history',
    () {
      final timeline = LocalIntelligenceTimeline(
        age: 40,
        heightCm: 175,
        gender: 'female',
        activityLevel: 'active',
        targetWeightKg: 70,
        days: [
          for (var index = 0; index < 21; index++)
            LocalDailyPhysiology(
              day: DateTime.utc(2026, 6, 1 + index),
              weightKg: index % 7 == 0 ? 82 - (index * 0.03) : null,
              caloriesKcal: 1700,
              proteinG: 110,
              carbsG: 150,
              fatG: 55,
              sodiumMg: 2100,
              potassiumMg: 2800,
              waterMl: 2400,
              contextTypes: const [],
            ),
        ],
      );
      const model = PhysiologicalRealityModel();
      final first = model.adaptiveTdee(timeline);
      final second = model.adaptiveTdee(timeline);
      final noiseA = model.analyze(timeline, tdeeKcal: first);
      final noiseB = model.analyze(timeline, tdeeKcal: second);

      expect(first, second);
      expect(noiseA.estimatedTissueChangeKg, noiseB.estimatedTissueChangeKg);
      expect(noiseA.confidence, inInclusiveRange(0, 1));
    },
  );
}
