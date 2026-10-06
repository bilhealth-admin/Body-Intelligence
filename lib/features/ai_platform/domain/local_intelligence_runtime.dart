import 'dart:collection';

import '../../../engine/nutrient_evidence_engine.dart';
import 'bil_intelligence_integration.dart';
import 'body_twin_engine_result.dart';
import 'decision_memory_history.dart';

final class LocalDailyPhysiology {
  LocalDailyPhysiology({
    required DateTime day,
    this.weightKg,
    required double? caloriesKcal,
    required double? proteinG,
    required double? carbsG,
    required double? fatG,
    required double? sodiumMg,
    required double? potassiumMg,
    this.hasNutritionItems = true,
    required this.waterMl,
    this.sleepHours,
    this.steps,
    required Iterable<String> contextTypes,
  }) : day = DateTime.utc(day.year, day.month, day.day),
       caloriesKcal = _knownValue(caloriesKcal),
       proteinG = _knownValue(proteinG),
       carbsG = _knownValue(carbsG),
       fatG = _knownValue(fatG),
       sodiumMg = _knownValue(sodiumMg),
       potassiumMg = _knownValue(potassiumMg),
       contextTypes = UnmodifiableListView<String>(
         (contextTypes.toSet().toList()..sort()),
       );

  final DateTime day;
  final double? weightKg;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? sodiumMg;
  final double? potassiumMg;

  /// Empty days are distinct from logged foods whose values are all unknown.
  /// In particular, a known zero does not make a recorded day disappear.
  final bool hasNutritionItems;
  final int waterMl;
  final double? sleepHours;
  final int? steps;
  final List<String> contextTypes;

  static double? _knownValue(double? value) =>
      value != null && value.isFinite && value >= 0 ? value : null;
}

/// An incomplete recorded day cannot silently disappear from an intake mean.
/// Days without food records remain outside that mean, as in the local ledger.
final class LocalNutritionEvidence {
  const LocalNutritionEvidence._();

  static double? average(
    Iterable<LocalDailyPhysiology> days,
    double? Function(LocalDailyPhysiology day) valueFor,
  ) {
    final values = days
        .where((day) => day.hasNutritionItems)
        .map(valueFor)
        .toList(growable: false);
    final report = NutrientEvidenceEngine.total([
      for (final value in values)
        NutrientObservation(
          value: value ?? 0,
          available: value != null && value.isFinite && value >= 0,
        ),
    ]);
    final total = report.completeTotal;
    return total == null || !total.isFinite ? null : total / values.length;
  }
}

final class LocalIntelligenceTimeline {
  LocalIntelligenceTimeline({
    required this.age,
    required this.heightCm,
    required this.gender,
    required this.activityLevel,
    required this.targetWeightKg,
    this.waistCm,
    this.neckCm,
    required Iterable<LocalDailyPhysiology> days,
    required Iterable<DecisionMemoryHistory> decisionHistory,
  }) : days = UnmodifiableListView<LocalDailyPhysiology>(
         (days.toList()..sort((a, b) => a.day.compareTo(b.day))),
       ),
       decisionHistory = UnmodifiableListView<DecisionMemoryHistory>(
         (decisionHistory.toList()
           ..sort((a, b) => b.record.createdAt.compareTo(a.record.createdAt))),
       );

  final int age;
  final double heightCm;
  final String gender;
  final String activityLevel;
  final double targetWeightKg;
  final double? waistCm;
  final double? neckCm;
  final List<LocalDailyPhysiology> days;
  final List<DecisionMemoryHistory> decisionHistory;

  List<LocalDailyPhysiology> get weightedDays =>
      days.where((day) => day.weightKg != null).toList(growable: false);
}

final class PhysiologicalNoiseEstimate {
  PhysiologicalNoiseEstimate({
    required this.observedScaleChangeKg,
    required this.estimatedTissueChangeKg,
    required this.waterAndGlycogenNoiseKg,
    required this.digestiveMassNoiseKg,
    required this.sodiumDriverKg,
    required this.potassiumDriverKg,
    required this.carbohydrateDriverKg,
    required this.hydrationDriverKg,
    required this.confidence,
    required Iterable<String> explanations,
  }) : explanations = UnmodifiableListView<String>(explanations.toList());

  final double observedScaleChangeKg;
  final double? estimatedTissueChangeKg;
  final double? waterAndGlycogenNoiseKg;
  final double? digestiveMassNoiseKg;
  final double? sodiumDriverKg;
  final double? potassiumDriverKg;
  final double? carbohydrateDriverKg;
  final double? hydrationDriverKg;
  final double confidence;
  final List<String> explanations;
}

final class RuntimeForecastPoint {
  const RuntimeForecastPoint({
    required this.days,
    required this.projectedWeightKg,
    required this.projectedTissueChangeKg,
    required this.confidence,
  });

  final int days;
  final double projectedWeightKg;
  final double projectedTissueChangeKg;
  final double confidence;
}

final class ProductIntelligenceOutput {
  ProductIntelligenceOutput({
    required this.brainResult,
    required this.bodyTwinResult,
    required this.noiseEstimate,
    required Iterable<RuntimeForecastPoint> forecast,
    required this.adaptiveTdeeKcal,
    required this.plateauRisk,
    required this.primaryMessage,
    required Iterable<String> explanation,
  }) : forecast = UnmodifiableListView<RuntimeForecastPoint>(forecast.toList()),
       explanation = UnmodifiableListView<String>(explanation.toList());

  final UnifiedHealthBrainResult brainResult;
  final BodyTwinEngineResult bodyTwinResult;
  final PhysiologicalNoiseEstimate noiseEstimate;
  final List<RuntimeForecastPoint> forecast;
  final double adaptiveTdeeKcal;
  final double? plateauRisk;
  final String primaryMessage;
  final List<String> explanation;

  bool get canPresent => brainResult.canProceed;
}
