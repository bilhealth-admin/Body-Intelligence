import '../domain/adaptive_metabolic_forecast.dart';

final class AdaptiveMetabolicForecastIntegrityValidator {
  const AdaptiveMetabolicForecastIntegrityValidator();

  List<String> validate(AdaptiveMetabolicForecast forecast) {
    final issues = <String>[];
    if (forecast.status == AdaptiveMetabolicForecastStatus.accepted) {
      if (forecast.points.isEmpty) {
        issues.add('accepted forecast has no points');
      }
      if (forecast.assumptionIds.isEmpty) {
        issues.add('accepted forecast has no assumptions');
      }
      if (forecast.evidenceIds.isEmpty) {
        issues.add('accepted forecast has no evidence');
      }
      if (forecast.points.any(
        (point) => point.confidence < 0 || point.confidence > 1,
      )) {
        issues.add('forecast confidence is outside [0, 1]');
      }
      for (var index = 1; index < forecast.points.length; index++) {
        if (forecast.points[index].horizon <=
            forecast.points[index - 1].horizon) {
          issues.add('forecast horizons are not strictly increasing');
          break;
        }
      }
    } else if (forecast.points.isNotEmpty) {
      issues.add('non-accepted forecast exposes points');
    }
    issues.sort();
    return List<String>.unmodifiable(issues);
  }
}
