import 'progress_analysis.dart';

class WeightAnalysis {
  static double? calculateWeeklyTrend(List<double> chronologicalWeights) {
    if (chronologicalWeights.length < 2) return null;
    final window = chronologicalWeights.length > 7
        ? chronologicalWeights.sublist(chronologicalWeights.length - 7)
        : chronologicalWeights;
    return window.last - window.first;
  }

  /// Observed endpoint difference across exactly seven calendar days.
  /// The caller supplies the displayed ending day; no measurement is carried
  /// forward from an older day and no unobserved endpoint is interpolated.
  static double? calculateSevenDayChange({
    required List<ProgressSample> samples,
    required DateTime endingOn,
  }) {
    final endDay = DateTime.utc(endingOn.year, endingOn.month, endingOn.day);
    final startDay = endDay.subtract(const Duration(days: 7));
    final measuredAtByDay = <DateTime, DateTime>{};
    final weightByDay = <DateTime, double>{};
    final ambiguousDays = <DateTime>{};
    for (final sample in samples) {
      final day = DateTime.utc(
        sample.date.year,
        sample.date.month,
        sample.date.day,
      );
      if (day != startDay && day != endDay) continue;
      if (!sample.weightKg.isFinite || sample.weightKg <= 0) return null;
      final previous = measuredAtByDay[day];
      if (previous == null || sample.date.isAfter(previous)) {
        measuredAtByDay[day] = sample.date;
        weightByDay[day] = sample.weightKg;
        ambiguousDays.remove(day);
      } else if (sample.date.isAtSameMomentAs(previous) &&
          sample.weightKg != weightByDay[day]) {
        // Equal timestamps with conflicting values do not identify a latest
        // observation. Input-list order must never choose the user's result.
        ambiguousDays.add(day);
      }
    }
    final startWeight = weightByDay[startDay];
    final endWeight = weightByDay[endDay];
    if (startWeight == null ||
        endWeight == null ||
        ambiguousDays.contains(startDay) ||
        ambiguousDays.contains(endDay)) {
      return null;
    }
    return endWeight - startWeight;
  }

  static String analyze({required double today, required double yesterday}) {
    final diff = today - yesterday;

    if (diff.abs() < 0.2) {
      return "Weight is stable.";
    }

    if (diff < 0) {
      return "Weight decreased by ${diff.abs().toStringAsFixed(1)} kg.";
    }

    return "Weight increased by ${diff.toStringAsFixed(1)} kg.";
  }
}
