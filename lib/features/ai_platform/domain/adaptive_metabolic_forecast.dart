import 'dart:collection';

enum AdaptiveMetabolicForecastStatus { accepted, abstained, rejected }

final class AdaptiveMetabolicForecastPoint {
  const AdaptiveMetabolicForecastPoint({
    required this.horizon,
    required this.projectedTissueChangeKg,
    required this.projectedScaleChangeKg,
    required this.confidence,
  });

  final Duration horizon;
  final double projectedTissueChangeKg;
  final double projectedScaleChangeKg;
  final double confidence;
}

final class AdaptiveMetabolicForecast {
  AdaptiveMetabolicForecast({
    required this.status,
    required DateTime asOf,
    required Iterable<AdaptiveMetabolicForecastPoint> points,
    required Iterable<String> assumptionIds,
    required Iterable<String> evidenceIds,
    required Iterable<String> uncertaintyReasons,
  }) : asOf = asOf.toUtc(),
       points = UnmodifiableListView<AdaptiveMetabolicForecastPoint>(
         points.toList(growable: false),
       ),
       assumptionIds = UnmodifiableListView<String>(
         (assumptionIds.toSet().toList()..sort()),
       ),
       evidenceIds = UnmodifiableListView<String>(
         (evidenceIds.toSet().toList()..sort()),
       ),
       uncertaintyReasons = UnmodifiableListView<String>(
         (uncertaintyReasons.toSet().toList()..sort()),
       );

  final AdaptiveMetabolicForecastStatus status;
  final DateTime asOf;
  final List<AdaptiveMetabolicForecastPoint> points;
  final List<String> assumptionIds;
  final List<String> evidenceIds;
  final List<String> uncertaintyReasons;

  bool get canProceed => status == AdaptiveMetabolicForecastStatus.accepted;
}

final class AdaptiveMetabolicForecastResult {
  AdaptiveMetabolicForecastResult({
    required this.forecast,
    required Iterable<String> integrityIssues,
  }) : integrityIssues = UnmodifiableListView<String>(
         (integrityIssues.toSet().toList()..sort()),
       );

  final AdaptiveMetabolicForecast forecast;
  final List<String> integrityIssues;

  bool get canProceed => forecast.canProceed && integrityIssues.isEmpty;
  AdaptiveMetabolicForecast? get acceptedForecast =>
      canProceed ? forecast : null;
}
