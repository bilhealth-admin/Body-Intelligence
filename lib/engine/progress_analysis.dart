import 'dart:math' as math;

enum ProgressConfidence { insufficient, low, medium, high }

class ProgressSample {
  const ProgressSample({required this.date, required this.weightKg});
  final DateTime date;
  final double weightKg;
}

class ProgressAnalysis {
  const ProgressAnalysis({
    required this.confidence,
    required this.weeklyDirectionKg,
    required this.monthlyDirectionKg,
    required this.variabilityKg,
    required this.spanDays,
    required this.sampleCount,
    required this.projectedGoalDate,
  });

  final ProgressConfidence confidence;
  final double? weeklyDirectionKg;
  final double? monthlyDirectionKg;
  final double? variabilityKg;
  final int spanDays;
  final int sampleCount;
  final DateTime? projectedGoalDate;

  static ProgressAnalysis evaluate({
    required List<ProgressSample> samples,
    double? goalWeightKg,
    DateTime? now,
  }) {
    final ordered = [...samples]..sort((a, b) => a.date.compareTo(b.date));
    if (ordered.isEmpty) {
      return const ProgressAnalysis(
        confidence: ProgressConfidence.insufficient,
        weeklyDirectionKg: null,
        monthlyDirectionKg: null,
        variabilityKg: null,
        spanDays: 0,
        sampleCount: 0,
        projectedGoalDate: null,
      );
    }
    final spanDays = ordered.length == 1
        ? 0
        : ordered.last.date.difference(ordered.first.date).inDays.abs();
    final confidence = ordered.length < 4 || spanDays < 6
        ? ProgressConfidence.insufficient
        : ordered.length >= 14 && spanDays >= 21
        ? ProgressConfidence.high
        : ordered.length >= 7 && spanDays >= 13
        ? ProgressConfidence.medium
        : ProgressConfidence.low;
    final slope = confidence == ProgressConfidence.insufficient
        ? null
        : _dailySlope(ordered);
    final variability = ordered.length < 3
        ? null
        : _variability(ordered, slope);
    final weekly = slope == null ? null : slope * 7;
    final monthly = weekly == null ? null : weekly * (30 / 7);
    DateTime? projected;
    if (goalWeightKg != null &&
        weekly != null &&
        confidence.index >= ProgressConfidence.medium.index &&
        weekly.abs() >= 0.1) {
      final remaining = goalWeightKg - ordered.last.weightKg;
      if (remaining != 0 && remaining.sign == weekly.sign) {
        final weeks = remaining / weekly;
        if (weeks > 0 && weeks <= 104) {
          projected = (now ?? DateTime.now()).add(
            Duration(days: (weeks * 7).round()),
          );
        }
      }
    }
    return ProgressAnalysis(
      confidence: confidence,
      weeklyDirectionKg: weekly,
      monthlyDirectionKg: monthly,
      variabilityKg: variability,
      spanDays: spanDays,
      sampleCount: ordered.length,
      projectedGoalDate: projected,
    );
  }

  static double _dailySlope(List<ProgressSample> values) {
    final origin = values.first.date;
    final xs = values
        .map((sample) => sample.date.difference(origin).inHours / 24)
        .toList();
    final ys = values.map((sample) => sample.weightKg).toList();
    final meanX = xs.reduce((a, b) => a + b) / xs.length;
    final meanY = ys.reduce((a, b) => a + b) / ys.length;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var index = 0; index < xs.length; index++) {
      numerator += (xs[index] - meanX) * (ys[index] - meanY);
      denominator += math.pow(xs[index] - meanX, 2);
    }
    return denominator == 0 ? 0 : numerator / denominator;
  }

  static double _variability(List<ProgressSample> values, double? slope) {
    final direction = slope ?? 0;
    final origin = values.first.date;
    final intercept = values.first.weightKg;
    final residuals = values.map((sample) {
      final days = sample.date.difference(origin).inHours / 24;
      return sample.weightKg - (intercept + direction * days);
    }).toList();
    final mean = residuals.reduce((a, b) => a + b) / residuals.length;
    final variance =
        residuals
            .map((value) => math.pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        residuals.length;
    return math.sqrt(variance);
  }
}
