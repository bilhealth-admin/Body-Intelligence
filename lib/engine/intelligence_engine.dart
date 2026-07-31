import 'dart:math' as math;

enum InsightPriority { low, medium, high }

enum InsightConfidence { insufficient, low, medium, high }

class Insight {
  const Insight({
    required this.title,
    required this.explanation,
    required this.evidence,
    required this.suggestedAction,
    required this.priority,
    required this.confidence,
  });

  final String title;
  final String explanation;
  final List<String> evidence;
  final String suggestedAction;
  final InsightPriority priority;
  final InsightConfidence confidence;
}

class IntelligenceReport {
  const IntelligenceReport({
    required this.score,
    required this.scoreConfidence,
    required this.insights,
    required this.goalDate,
    required this.weeklyRateKg,
  });

  final int? score;
  final InsightConfidence scoreConfidence;
  final List<Insight> insights;
  final DateTime? goalDate;
  final double? weeklyRateKg;
}

class IntelligenceEngine {
  static IntelligenceReport evaluate({
    required int calorieTarget,
    required int proteinTarget,
    required int waterTarget,
    required double calories,
    required double protein,
    required int waterMl,
    required List<double> chronologicalWeights,
    required double goalWeight,
    int trackedDays = 1,
    double sodium = 0,
  }) {
    final adherence = <double>[
      _ratioScore(calories, calorieTarget.toDouble()),
      _ratioScore(protein, proteinTarget.toDouble()),
      _ratioScore(waterMl.toDouble(), waterTarget.toDouble()),
    ];
    final confidence = trackedDays == 0
        ? InsightConfidence.insufficient
        : trackedDays >= 7
        ? InsightConfidence.high
        : trackedDays >= 3
        ? InsightConfidence.medium
        : InsightConfidence.low;
    final score = (adherence.reduce((a, b) => a + b) / adherence.length * 100)
        .round()
        .clamp(0, 100);
    final insights = <Insight>[];

    if (protein < proteinTarget * 0.8) {
      insights.add(
        Insight(
          title: 'Protein below target',
          explanation: 'Logged protein is below the personalized daily range.',
          evidence: [
            '${protein.toStringAsFixed(0)} g logged',
            '$proteinTarget g target',
          ],
          suggestedAction:
              'Add a protein-rich food that fits your preferences.',
          priority: InsightPriority.high,
          confidence: confidence,
        ),
      );
    }
    if (waterMl < waterTarget * 0.75) {
      insights.add(
        Insight(
          title: 'Hydration opportunity',
          explanation:
              'Recorded water is below three quarters of today’s target.',
          evidence: ['$waterMl ml recorded', '$waterTarget ml target'],
          suggestedAction: 'Drink water gradually through the remaining day.',
          priority: InsightPriority.medium,
          confidence: confidence,
        ),
      );
    }

    final rate = weeklyRate(chronologicalWeights);
    final goalDate = estimateGoalDate(
      currentWeight: chronologicalWeights.isEmpty
          ? null
          : chronologicalWeights.last,
      goalWeight: goalWeight,
      weeklyRateKg: rate,
    );
    if (chronologicalWeights.length >= 14 && rate != null && rate.abs() < 0.1) {
      insights.add(
        const Insight(
          title: 'Possible plateau',
          explanation:
              'The recent smoothed weight direction is nearly flat. Daily weight can still fluctuate.',
          evidence: [
            'At least 14 weight records',
            'Weekly change below 0.1 kg',
          ],
          suggestedAction:
              'Review two more weeks of consistent nutrition and weigh-ins before changing the plan.',
          priority: InsightPriority.medium,
          confidence: InsightConfidence.medium,
        ),
      );
    }
    if (chronologicalWeights.length >= 4) {
      final recent = chronologicalWeights.sublist(
        chronologicalWeights.length - 4,
      );
      final jump = recent.last - recent.first;
      if (jump >= 1.0) {
        insights.add(
          Insight(
            title: 'Possible short-term water retention',
            explanation:
                'A rapid scale increase is often influenced by fluid and food mass; this is a hypothesis, not a diagnosis.',
            evidence: [
              '${jump.toStringAsFixed(1)} kg change across four records',
              if (sodium > 2300)
                '${sodium.toStringAsFixed(0)} mg sodium logged',
            ],
            suggestedAction:
                'Keep normal hydration and review the trend over several more days.',
            priority: InsightPriority.low,
            confidence: InsightConfidence.low,
          ),
        );
      }
    }
    if (insights.isEmpty) {
      insights.add(
        Insight(
          title: trackedDays < 3
              ? 'Build your baseline'
              : 'Daily targets are broadly aligned',
          explanation: trackedDays < 3
              ? 'More logged days are needed for reliable trend intelligence.'
              : 'Calories, protein, and hydration are within useful ranges today.',
          evidence: ['$trackedDays tracked day${trackedDays == 1 ? '' : 's'}'],
          suggestedAction: 'Keep logging consistently.',
          priority: InsightPriority.low,
          confidence: confidence,
        ),
      );
    }

    insights.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    return IntelligenceReport(
      score: trackedDays == 0 ? null : score,
      scoreConfidence: confidence,
      insights: insights,
      goalDate: goalDate,
      weeklyRateKg: rate,
    );
  }

  static double? weeklyRate(List<double> chronologicalWeights) {
    if (chronologicalWeights.length < 4) return null;
    final window = chronologicalWeights.length > 14
        ? chronologicalWeights.sublist(chronologicalWeights.length - 14)
        : chronologicalWeights;
    final first = _average(window.take(math.min(3, window.length)).toList());
    final last = _average(window.skip(math.max(0, window.length - 3)).toList());
    final periods = math.max(1.0, (window.length - 1) / 7);
    return (last - first) / periods;
  }

  static DateTime? estimateGoalDate({
    required double? currentWeight,
    required double goalWeight,
    required double? weeklyRateKg,
  }) {
    if (currentWeight == null ||
        weeklyRateKg == null ||
        weeklyRateKg.abs() < 0.1) {
      return null;
    }
    final remaining = goalWeight - currentWeight;
    if (remaining == 0 || remaining.sign != weeklyRateKg.sign) return null;
    final weeks = remaining / weeklyRateKg;
    if (weeks <= 0 || weeks > 104) return null;
    return DateTime.now().add(Duration(days: (weeks * 7).round()));
  }

  static double _ratioScore(double actual, double target) {
    if (target <= 0) return 0;
    return (1 - ((actual - target).abs() / target)).clamp(0, 1);
  }

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}
