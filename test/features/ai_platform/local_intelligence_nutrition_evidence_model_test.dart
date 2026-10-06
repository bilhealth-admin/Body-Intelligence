import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/physiological_reality_model.dart';
import 'package:body_intelligence_log/features/ai_platform/services/product_intelligence_behavior_model.dart';
import 'package:flutter_test/flutter_test.dart';

LocalIntelligenceTimeline _timeline({
  Map<int, double?> calories = const {},
  Map<int, double?> protein = const {},
  Map<int, double?> sodium = const {},
  Map<int, double?> potassium = const {},
  Map<int, double?> carbs = const {},
  Set<int> emptyDays = const {},
}) => LocalIntelligenceTimeline(
  age: 36,
  heightCm: 181,
  gender: 'male',
  activityLevel: 'moderate',
  targetWeightKg: 88,
  days: [
    for (var index = 0; index < 14; index++)
      LocalDailyPhysiology(
        day: DateTime.utc(2026, 9, 1 + index),
        weightKg: index == 0
            ? 96
            : index == 13
            ? 95.5
            : null,
        caloriesKcal: calories.containsKey(index) ? calories[index] : 1800,
        proteinG: protein.containsKey(index) ? protein[index] : 110,
        carbsG: carbs.containsKey(index) ? carbs[index] : 150,
        fatG: 60,
        sodiumMg: sodium.containsKey(index) ? sodium[index] : 2800,
        potassiumMg: potassium.containsKey(index) ? potassium[index] : 2500,
        hasNutritionItems: !emptyDays.contains(index),
        waterMl: 2300,
        sleepHours: 5.5,
        steps: 4000,
        contextTypes: const [],
      ),
  ],
  decisionHistory: const [],
);

AdaptiveMetabolicForecastResult _unavailableForecast() =>
    AdaptiveMetabolicForecastResult(
      forecast: AdaptiveMetabolicForecast(
        status: AdaptiveMetabolicForecastStatus.abstained,
        asOf: DateTime.utc(2026, 9, 14),
        points: const [],
        assumptionIds: const [],
        evidenceIds: const [],
        uncertaintyReasons: const ['test has no accepted forecast'],
      ),
      integrityIssues: const [],
    );

void main() {
  const physiology = PhysiologicalRealityModel();
  const behavior = ProductIntelligenceBehaviorModel();

  test('a recorded unknown day cannot be dropped from an intake average', () {
    final timeline = _timeline(calories: {3: null});
    expect(
      LocalNutritionEvidence.average(timeline.days, (day) => day.caloriesKcal),
      isNull,
    );
    expect(
      physiology.analyze(timeline, tdeeKcal: 2400).estimatedTissueChangeKg,
      isNull,
    );
    final emptyInstead = _timeline(calories: {3: null}, emptyDays: {3});
    expect(
      LocalNutritionEvidence.average(
        emptyInstead.days,
        (day) => day.caloriesKcal,
      ),
      1800,
    );
  });

  test('a known zero remains in the average denominator', () {
    final timeline = _timeline(protein: {3: 0});
    expect(
      LocalNutritionEvidence.average(timeline.days, (day) => day.proteinG),
      closeTo(110 * 13 / 14, 1e-9),
    );
    expect(timeline.days[3].proteinG, 0);
  });

  test('partial protein across days cannot generate a protein-gap claim', () {
    final timeline = _timeline(protein: {3: null});
    final candidates = behavior.candidates(
      timeline: timeline,
      estimate: physiology.analyze(timeline, tdeeKcal: 2400),
      adaptiveTdeeKcal: 2400,
      averageIntakeKcal: 1800,
      plateauRisk: .35,
    );
    expect(
      candidates.map((candidate) => candidate.id),
      isNot(contains('increase-protein')),
    );
    final complete = _timeline();
    expect(
      behavior
          .candidates(
            timeline: complete,
            estimate: physiology.analyze(complete, tdeeKcal: 2400),
            adaptiveTdeeKcal: 2400,
            averageIntakeKcal: 1800,
            plateauRisk: .35,
          )
          .map((candidate) => candidate.id),
      contains('increase-protein'),
    );
  });

  test(
    'unknown energy cannot authorize dependent activity or plateau claims',
    () {
      final timeline = _timeline(calories: {3: null});
      final estimate = physiology.analyze(timeline, tdeeKcal: 2400);
      final candidates = behavior.candidates(
        timeline: timeline,
        estimate: estimate,
        adaptiveTdeeKcal: 2400,
        // A caller's old aggregate is not evidence for the missing recorded day.
        averageIntakeKcal: 1800,
        plateauRisk: .9,
      );
      expect(
        candidates.map((candidate) => candidate.id),
        isNot(
          anyOf(
            contains('increase-activity'),
            contains('continue-plan'),
            contains('audit-plateau-inputs'),
          ),
        ),
      );
      expect(
        candidates.map((candidate) => candidate.id),
        contains('protect-sleep'),
      );
      expect(
        behavior.plateauRisk(
          timeline: timeline,
          adaptiveTdeeKcal: 2400,
          averageIntakeKcal: 1800,
          forecastResult: _unavailableForecast(),
          physiologyConfidence: estimate.confidence,
        ),
        isNull,
      );
    },
  );

  test('one missing electrolyte cannot manufacture a balance candidate', () {
    final timeline = _timeline(potassium: {3: null});
    final candidates = behavior.candidates(
      timeline: timeline,
      estimate: physiology.analyze(timeline, tdeeKcal: 2400),
      adaptiveTdeeKcal: 2400,
      averageIntakeKcal: 1800,
      plateauRisk: .35,
    );
    expect(
      candidates.map((candidate) => candidate.id),
      isNot(contains('rebalance-electrolytes')),
    );
  });

  test('known zero electrolyte and carbohydrate changes remain zero', () {
    final zeros = <int, double?>{
      for (var index = 0; index < 14; index++) index: 0,
    };
    final timeline = _timeline(sodium: zeros, potassium: zeros, carbs: zeros);
    final estimate = physiology.analyze(timeline, tdeeKcal: 2400);
    expect(estimate.sodiumDriverKg, 0);
    expect(estimate.potassiumDriverKg, 0);
    expect(estimate.carbohydrateDriverKg, 0);
    expect(estimate.waterAndGlycogenNoiseKg, isNotNull);
  });

  test('non-finite nutrient values cannot enter canonical averages', () {
    for (final invalid in [double.nan, double.infinity, -1.0]) {
      final timeline = _timeline(calories: {3: invalid});
      expect(timeline.days[3].caloriesKcal, isNull);
      expect(
        LocalNutritionEvidence.average(
          timeline.days,
          (day) => day.caloriesKcal,
        ),
        isNull,
      );
      expect(
        physiology.analyze(timeline, tdeeKcal: 2400).estimatedTissueChangeKg,
        isNull,
      );
    }
  });
}
