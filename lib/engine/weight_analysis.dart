class WeightAnalysis {
  static double? calculateWeeklyTrend(List<double> chronologicalWeights) {
    if (chronologicalWeights.length < 2) return null;
    final window = chronologicalWeights.length > 7
        ? chronologicalWeights.sublist(chronologicalWeights.length - 7)
        : chronologicalWeights;
    return window.last - window.first;
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
