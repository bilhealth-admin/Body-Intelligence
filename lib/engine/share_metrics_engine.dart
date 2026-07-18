class ShareMetrics {
  const ShareMetrics({
    required this.consistentDays,
    required this.proteinDays,
    required this.hydrationDays,
    required this.observedDays,
    required this.score,
  });

  final int consistentDays;
  final int proteinDays;
  final int hydrationDays;
  final int observedDays;
  final int score;
}

class ShareDayEvidence {
  const ShareDayEvidence({
    required this.hasMeal,
    required this.hasWeight,
    required this.protein,
    required this.waterMl,
  });
  final bool hasMeal;
  final bool hasWeight;
  final double protein;
  final int waterMl;
}

class ShareMetricsEngine {
  const ShareMetricsEngine._();

  static ShareMetrics calculate(
    List<ShareDayEvidence> days, {
    required int proteinTarget,
    required int waterTarget,
  }) {
    if (days.isEmpty) {
      return const ShareMetrics(
        consistentDays: 0,
        proteinDays: 0,
        hydrationDays: 0,
        observedDays: 0,
        score: 0,
      );
    }
    final consistent = days.where((day) => day.hasMeal || day.hasWeight).length;
    final protein = days
        .where((day) => proteinTarget > 0 && day.protein >= proteinTarget * .8)
        .length;
    final hydration = days
        .where((day) => waterTarget > 0 && day.waterMl >= waterTarget * .8)
        .length;
    final score = ((consistent + protein + hydration) / (days.length * 3) * 100)
        .round();
    return ShareMetrics(
      consistentDays: consistent,
      proteinDays: protein,
      hydrationDays: hydration,
      observedDays: days.length,
      score: score,
    );
  }
}
