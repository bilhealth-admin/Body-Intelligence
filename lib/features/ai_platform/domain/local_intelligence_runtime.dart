import 'dart:collection';

import 'bil_intelligence_integration.dart';
import 'decision_memory_history.dart';

final class LocalDailyPhysiology {
  LocalDailyPhysiology({
    required DateTime day,
    this.weightKg,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sodiumMg,
    required this.potassiumMg,
    required this.waterMl,
    this.sleepHours,
    this.steps,
    required Iterable<String> contextTypes,
  }) : day = DateTime.utc(day.year, day.month, day.day),
       contextTypes = UnmodifiableListView<String>(
         (contextTypes.toSet().toList()..sort()),
       );

  final DateTime day;
  final double? weightKg;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sodiumMg;
  final double potassiumMg;
  final int waterMl;
  final double? sleepHours;
  final int? steps;
  final List<String> contextTypes;
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
    required this.carbohydrateDriverKg,
    required this.hydrationDriverKg,
    required this.confidence,
    required Iterable<String> explanations,
  }) : explanations = UnmodifiableListView<String>(explanations.toList());

  final double observedScaleChangeKg;
  final double estimatedTissueChangeKg;
  final double waterAndGlycogenNoiseKg;
  final double digestiveMassNoiseKg;
  final double sodiumDriverKg;
  final double carbohydrateDriverKg;
  final double hydrationDriverKg;
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
    required this.noiseEstimate,
    required Iterable<RuntimeForecastPoint> forecast,
    required this.adaptiveTdeeKcal,
    required this.plateauRisk,
    required this.primaryMessage,
    required Iterable<String> explanation,
  }) : forecast = UnmodifiableListView<RuntimeForecastPoint>(forecast.toList()),
       explanation = UnmodifiableListView<String>(explanation.toList());

  final UnifiedHealthBrainResult brainResult;
  final PhysiologicalNoiseEstimate noiseEstimate;
  final List<RuntimeForecastPoint> forecast;
  final double adaptiveTdeeKcal;
  final double plateauRisk;
  final String primaryMessage;
  final List<String> explanation;

  bool get canPresent => brainResult.canProceed;
}
