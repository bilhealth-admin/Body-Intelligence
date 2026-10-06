import 'dart:math' as math;

import '../domain/local_intelligence_runtime.dart';
import '../domain/personal_health_ai.dart';
import 'personal_health_ai_engine.dart';

/// Explainable local physiology model. It estimates tissue change from energy
/// balance and separately attributes transient scale movement to glycogen,
/// sodium, hydration and digestive-mass drivers.
final class PhysiologicalRealityModel {
  const PhysiologicalRealityModel();

  double adaptiveTdee(LocalIntelligenceTimeline timeline) {
    final weighted = timeline.weightedDays;
    if (weighted.isEmpty) return 0;
    return const PersonalHealthAiEngine()
        .evaluate(
          asOf: timeline.days.last.day.add(const Duration(hours: 23)),
          weights: [
            for (final day in weighted)
              WeightObservation(at: day.day, kg: day.weightKg!),
          ],
          age: timeline.age,
          heightCm: timeline.heightCm,
          gender: timeline.gender,
          activityLevel: timeline.activityLevel,
          dailyCalories: {
            for (final day in timeline.days)
              day.day: day.hasNutritionItems ? day.caloriesKcal : null,
          },
        )
        .tdee
        .kcal;
  }

  PhysiologicalNoiseEstimate analyze(
    LocalIntelligenceTimeline timeline, {
    required double tdeeKcal,
  }) {
    final weighted = timeline.weightedDays;
    if (weighted.length < 2) {
      return PhysiologicalNoiseEstimate(
        observedScaleChangeKg: 0,
        estimatedTissueChangeKg: null,
        waterAndGlycogenNoiseKg: null,
        digestiveMassNoiseKg: null,
        sodiumDriverKg: null,
        potassiumDriverKg: null,
        carbohydrateDriverKg: null,
        hydrationDriverKg: null,
        confidence: 0,
        explanations: const [
          'At least two local weight observations are required.',
        ],
      );
    }
    final first = weighted.first;
    final last = weighted.last;
    final observed = last.weightKg! - first.weightKg!;
    final intervalDays = math.max(1, last.day.difference(first.day).inDays);
    final relevant = timeline.days
        .where(
          (day) => !day.day.isBefore(first.day) && !day.day.isAfter(last.day),
        )
        .toList();
    final logged = relevant
        .where(
          (day) =>
              day.hasNutritionItems &&
              day.caloriesKcal != null &&
              day.caloriesKcal! > 0,
        )
        .toList();
    final averageIntake = LocalNutritionEvidence.average(
      relevant,
      (day) => day.caloriesKcal,
    );
    final hasEnergyEvidence =
        averageIntake != null &&
        logged.length >= 2 &&
        tdeeKcal.isFinite &&
        tdeeKcal > 0;
    final tissue = hasEnergyEvidence
        ? ((averageIntake - tdeeKcal) * intervalDays) / 7700
        : null;

    final early = _window(relevant, true);
    final late = _window(relevant, false);
    final sodiumDelta = _delta(early.sodiumMg, late.sodiumMg);
    final potassiumDelta = _delta(early.potassiumMg, late.potassiumMg);
    final sodium = sodiumDelta == null
        ? null
        : (sodiumDelta / 2300).clamp(-2.0, 2.0) * 0.24;
    final potassium = potassiumDelta == null
        ? null
        : (-potassiumDelta / 3500).clamp(-2.0, 2.0) * 0.16;
    final electrolyteBalance = sodium == null || potassium == null
        ? null
        : (sodium + potassium).clamp(-0.6, 0.6);
    final carbohydrateDelta = _delta(early.carbsG, late.carbsG);
    final carbohydrate = carbohydrateDelta == null
        ? null
        : (carbohydrateDelta * 0.003).clamp(-1.2, 1.2);
    final hydrationDelta = _delta(early.waterMl, late.waterMl);
    final hydration = hydrationDelta == null
        ? null
        : (hydrationDelta / 1000).clamp(-1.0, 1.0) * 0.18;
    final calorieDelta = _delta(early.caloriesKcal, late.caloriesKcal);
    final digestive = calorieDelta == null
        ? null
        : (calorieDelta / 2500).clamp(-0.45, 0.45);
    final mechanistic =
        electrolyteBalance == null ||
            carbohydrate == null ||
            hydration == null ||
            digestive == null
        ? null
        : electrolyteBalance + carbohydrate + hydration + digestive;
    final residual = tissue == null ? null : observed - tissue;
    final noise = mechanistic == null || residual == null
        ? null
        : (mechanistic * 0.6) + (residual * 0.4);
    final coverage = logged.length / math.max(1, relevant.length);
    final driverAgreement = mechanistic == null || residual == null
        ? null
        : 1 - ((mechanistic - residual).abs() / 2.5).clamp(0.0, 1.0);
    final confidence =
        (hasEnergyEvidence
                ? 0.20 +
                      (coverage * 0.35) +
                      (driverAgreement == null ? 0 : driverAgreement * 0.3)
                : math.min(0.2, coverage))
            .clamp(0.0, 1.0);

    return PhysiologicalNoiseEstimate(
      observedScaleChangeKg: observed,
      estimatedTissueChangeKg: tissue,
      waterAndGlycogenNoiseKg: noise,
      digestiveMassNoiseKg: digestive,
      sodiumDriverKg: sodium,
      potassiumDriverKg: potassium,
      carbohydrateDriverKg: carbohydrate,
      hydrationDriverKg: hydration,
      confidence: confidence,
      explanations: [
        if (hasEnergyEvidence)
          'Probable tissue direction uses logged energy balance; 7700 kcal/kg is an uncertain approximation, not a direct fat measurement.'
        else
          'Insufficient calorie evidence to separate tissue and fluid reliably.',
        if (electrolyteBalance != null)
          'Sodium and potassium are modeled as opposing electrolyte water drivers.',
        if (carbohydrate != null)
          'Carbohydrate driver models glycogen-bound water from intake change.',
        if (hydration != null && digestive != null)
          'Hydration and digestive-mass drivers remain explicit and independently inspectable.',
      ],
    );
  }

  _Window _window(List<LocalDailyPhysiology> days, bool first) {
    final available = days
        .where((day) => day.hasNutritionItems || day.waterMl > 0)
        .toList();
    if (available.isEmpty) return const _Window();
    final slice = first ? available.take(3) : available.reversed.take(3);
    final values = slice.toList();
    return _Window(
      caloriesKcal: LocalNutritionEvidence.average(
        values,
        (day) => day.caloriesKcal,
      ),
      carbsG: LocalNutritionEvidence.average(values, (day) => day.carbsG),
      sodiumMg: LocalNutritionEvidence.average(values, (day) => day.sodiumMg),
      potassiumMg: LocalNutritionEvidence.average(
        values,
        (day) => day.potassiumMg,
      ),
      waterMl: _average(values.map((day) => day.waterMl.toDouble())),
    );
  }

  double? _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;
  }

  double? _delta(double? early, double? late) =>
      early == null || late == null ? null : late - early;
}

final class _Window {
  const _Window({
    this.caloriesKcal,
    this.carbsG,
    this.sodiumMg,
    this.potassiumMg,
    this.waterMl,
  });
  final double? caloriesKcal;
  final double? carbsG;
  final double? sodiumMg;
  final double? potassiumMg;
  final double? waterMl;
}
