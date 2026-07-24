import 'dart:math' as math;

import '../domain/local_intelligence_runtime.dart';

/// Explainable local physiology model. It estimates tissue change from energy
/// balance and separately attributes transient scale movement to glycogen,
/// sodium, hydration and digestive-mass drivers.
final class PhysiologicalRealityModel {
  const PhysiologicalRealityModel();

  double adaptiveTdee(LocalIntelligenceTimeline timeline) {
    final weighted = timeline.weightedDays;
    if (weighted.isEmpty) return 0;
    final latestWeight = weighted.last.weightKg!;
    final sexOffset = timeline.gender.toLowerCase().startsWith('f')
        ? -161.0
        : 5.0;
    final bmr =
        (10 * latestWeight) +
        (6.25 * timeline.heightCm) -
        (5 * timeline.age) +
        sexOffset;
    final factor = switch (timeline.activityLevel) {
      'veryActive' => 1.725,
      'active' => 1.55,
      'moderate' => 1.375,
      _ => 1.2,
    };
    final formulaTdee = bmr * factor;
    if (weighted.length < 8) return formulaTdee;

    final first = weighted.first;
    final last = weighted.last;
    final days = math.max(1, last.day.difference(first.day).inDays);
    final observedDailyEnergy =
        ((first.weightKg! - last.weightKg!) * 7700) / days;
    final logged = timeline.days.where((day) => day.caloriesKcal > 0).toList();
    if (logged.length < 5) return formulaTdee;
    final averageIntake =
        logged.fold<double>(0, (sum, day) => sum + day.caloriesKcal) /
        logged.length;
    final observedTdee = averageIntake + observedDailyEnergy;
    return (formulaTdee * 0.55) +
        (observedTdee.clamp(formulaTdee * 0.65, formulaTdee * 1.35) * 0.45);
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
    final tissue = ((averageIntake - tdeeKcal) * intervalDays) / 7700;

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
    final confidence = (0.35 + (coverage * 0.35) + (driverAgreement * 0.3))
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
        'Tissue change uses logged energy balance at 7700 kcal per kilogram.',
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
