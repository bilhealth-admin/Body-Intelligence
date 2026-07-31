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
              day.day: day.caloriesKcal > 0 ? day.caloriesKcal : null,
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
        estimatedTissueChangeKg: 0,
        waterAndGlycogenNoiseKg: 0,
        digestiveMassNoiseKg: 0,
        sodiumDriverKg: 0,
        potassiumDriverKg: 0,
        carbohydrateDriverKg: 0,
        hydrationDriverKg: 0,
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
    final logged = relevant.where((day) => day.caloriesKcal > 0).toList();
    final averageIntake = logged.isEmpty
        ? tdeeKcal
        : logged.fold<double>(0, (sum, day) => sum + day.caloriesKcal) /
              logged.length;
    final hasEnergyEvidence = logged.length >= 2;
    final tissue = hasEnergyEvidence
        ? ((averageIntake - tdeeKcal) * intervalDays) / 7700
        : 0.0;

    final early = _window(relevant, true);
    final late = _window(relevant, false);
    final sodiumDelta = (late.sodiumMg - early.sodiumMg) / 2300;
    final potassiumDelta = (late.potassiumMg - early.potassiumMg) / 3500;
    final sodium = sodiumDelta.clamp(-2.0, 2.0) * 0.24;
    final potassium = (-potassiumDelta).clamp(-2.0, 2.0) * 0.16;
    final electrolyteBalance = (sodium + potassium).clamp(-0.6, 0.6);
    final carbohydrate = ((late.carbsG - early.carbsG) * 0.003).clamp(
      -1.2,
      1.2,
    );
    final hydration =
        ((late.waterMl - early.waterMl) / 1000).clamp(-1.0, 1.0) * 0.18;
    final digestive = ((late.caloriesKcal - early.caloriesKcal) / 2500).clamp(
      -0.45,
      0.45,
    );
    final mechanistic =
        electrolyteBalance + carbohydrate + hydration + digestive;
    final residual = observed - tissue;
    final noise = (mechanistic * 0.6) + (residual * 0.4);
    final coverage = logged.length / math.max(1, relevant.length);
    final driverAgreement =
        1 - ((mechanistic - residual).abs() / 2.5).clamp(0.0, 1.0);
    final confidence =
        (hasEnergyEvidence
                ? 0.20 + (coverage * 0.35) + (driverAgreement * 0.3)
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
        'Sodium and potassium are modeled as opposing electrolyte water drivers.',
        'Carbohydrate driver models glycogen-bound water from intake change.',
        'Hydration and digestive-mass drivers remain explicit and independently inspectable.',
      ],
    );
  }

  _Window _window(List<LocalDailyPhysiology> days, bool first) {
    final available = days
        .where((day) => day.caloriesKcal > 0 || day.waterMl > 0)
        .toList();
    if (available.isEmpty) return const _Window();
    final slice = first ? available.take(3) : available.reversed.take(3);
    final values = slice.toList();
    return _Window(
      caloriesKcal: _average(values.map((day) => day.caloriesKcal)),
      carbsG: _average(values.map((day) => day.carbsG)),
      sodiumMg: _average(values.map((day) => day.sodiumMg)),
      potassiumMg: _average(values.map((day) => day.potassiumMg)),
      waterMl: _average(values.map((day) => day.waterMl.toDouble())),
    );
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }
}

final class _Window {
  const _Window({
    this.caloriesKcal = 0,
    this.carbsG = 0,
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.waterMl = 0,
  });
  final double caloriesKcal;
  final double carbsG;
  final double sodiumMg;
  final double potassiumMg;
  final double waterMl;
}
