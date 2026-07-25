import 'package:body_intelligence_log/features/ai_platform/domain/personal_health_ai.dart';
import 'package:body_intelligence_log/features/ai_platform/services/personal_health_ai_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = PersonalHealthAiEngine();
  final start = DateTime.utc(2026, 1, 1, 7);

  PersonalHealthAiSnapshot evaluate(
    List<WeightObservation> weights, {
    Map<DateTime, double?> calories = const {},
  }) => engine.evaluate(
    asOf: DateTime.utc(2026, 2, 1),
    weights: weights,
    age: 35,
    heightCm: 175,
    gender: 'male',
    activityLevel: 'moderate',
    dailyCalories: calories,
  );

  test('second weight initializes an immediate low-confidence trend', () {
    final result = evaluate([
      WeightObservation(at: start, kg: 90),
      WeightObservation(
        at: start.add(const Duration(days: 3, hours: 6)),
        kg: 89.5,
      ),
    ]);

    expect(result.currentPhase.kgPerDay, isNotNull);
    expect(result.currentPhase.state, HealthAiLearningState.initial);
    expect(result.currentPhase.confidence, lessThan(0.5));
    expect(result.currentPhase.observationCount, 2);
  });

  test('later irregular measurements correct the estimate', () {
    final early = evaluate([
      WeightObservation(at: start, kg: 90),
      WeightObservation(at: start.add(const Duration(days: 2)), kg: 88),
    ]);
    final corrected = evaluate([
      WeightObservation(at: start, kg: 90),
      WeightObservation(at: start.add(const Duration(days: 2)), kg: 88),
      WeightObservation(
        at: start.add(const Duration(days: 9, hours: 12)),
        kg: 89.4,
      ),
      WeightObservation(at: start.add(const Duration(days: 17)), kg: 89.1),
    ]);

    expect(corrected.currentPhase.kgPerDay, isNot(equals(early.currentPhase.kgPerDay)));
    expect(corrected.currentPhase.kgPerDay!.abs(), lessThan(0.2));
  });

  test('one isolated outlier does not dominate Theil-Sen direction', () {
    final values = <WeightObservation>[
      WeightObservation(at: start, kg: 90),
      WeightObservation(at: start.add(const Duration(days: 2)), kg: 89.8),
      WeightObservation(at: start.add(const Duration(days: 5)), kg: 95),
      WeightObservation(at: start.add(const Duration(days: 9)), kg: 89.2),
      WeightObservation(at: start.add(const Duration(days: 15)), kg: 88.8),
    ];
    expect(evaluate(values).currentPhase.kgPerDay, lessThan(0));
  });

  test('formula TDEE exists and does not calibrate without calories', () {
    final result = evaluate([
      WeightObservation(at: start, kg: 90),
      WeightObservation(at: start.add(const Duration(days: 4)), kg: 89.6),
    ]);
    expect(result.tdee.kcal, greaterThan(0));
    expect(result.tdee.state, HealthAiLearningState.initial);
    expect(result.tdee.missingEvidence, isNotEmpty);
    expect(result.tissueFluid.probableTissueChangeKg, isNull);
  });

  test('TDEE begins calibration as soon as interval evidence is sufficient', () {
    final weights = [
      WeightObservation(at: start, kg: 90),
      WeightObservation(at: start.add(const Duration(days: 3)), kg: 89.7),
    ];
    final calories = {
      DateTime.utc(2026, 1, 1): 2100.0,
      DateTime.utc(2026, 1, 2): 2050.0,
      DateTime.utc(2026, 1, 3): 2150.0,
      DateTime.utc(2026, 1, 4): 2100.0,
    };
    final result = evaluate(weights, calories: calories);
    expect(result.tdee.state, HealthAiLearningState.calibrating);
    expect(result.tissueFluid.probableTissueChangeKg, isNotNull);
  });

  test('full journey and current phase are both exposed', () {
    final values = List.generate(
      8,
      (index) => WeightObservation(
        at: start.add(Duration(days: index * 7)),
        kg: 95 - index.toDouble(),
      ),
    );
    final result = engine.evaluate(
      asOf: start.add(const Duration(days: 50)),
      weights: values,
      age: 35,
      heightCm: 175,
      gender: 'male',
      activityLevel: 'moderate',
      dailyCalories: const {},
    );
    expect(result.fullJourney.observationCount, 8);
    expect(result.currentPhase.observationCount, lessThan(8));
  });
}
