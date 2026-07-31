import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_history.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/physiological_reality_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low potassium amplifies sodium-associated water noise', () {
    final balanced = _timeline(latePotassium: 4200);
    final lowPotassium = _timeline(latePotassium: 1800);
    const model = PhysiologicalRealityModel();

    final balancedResult = model.analyze(balanced, tdeeKcal: 2400);
    final lowResult = model.analyze(lowPotassium, tdeeKcal: 2400);

    expect(
      lowResult.potassiumDriverKg,
      greaterThan(balancedResult.potassiumDriverKg),
    );
    expect(
      lowResult.waterAndGlycogenNoiseKg,
      greaterThan(balancedResult.waterAndGlycogenNoiseKg),
    );
  });
}

LocalIntelligenceTimeline _timeline({required double latePotassium}) =>
    LocalIntelligenceTimeline(
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
              ? 95.6
              : null,
          caloriesKcal: 1800,
          proteinG: 130,
          carbsG: 150,
          fatG: 60,
          sodiumMg: index < 7 ? 1800 : 3400,
          potassiumMg: index < 7 ? 3500 : latePotassium,
          waterMl: 2600,
          contextTypes: const [],
        );
      }),
    );
