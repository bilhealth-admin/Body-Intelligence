class ChallengeDayEvidence {
  const ChallengeDayEvidence({
    required this.hasMeal,
    required this.hasWeight,
    required this.protein,
    required this.fiber,
    required this.waterMl,
  });
  final bool hasMeal;
  final bool hasWeight;
  final double protein;
  final double fiber;
  final int waterMl;
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.qualifyingDays,
    required this.targetDays,
  });
  final int qualifyingDays;
  final int targetDays;
  bool get complete => qualifyingDays >= targetDays;
  double get fraction => targetDays == 0
      ? 0
      : (qualifyingDays / targetDays).clamp(0, 1).toDouble();
}

class ChallengeEngine {
  const ChallengeEngine._();

  static const supportedTypes = {
    'protein',
    'water',
    'consistentLogging',
    'fiber',
    'return',
    'weightCheckIn',
  };

  static ChallengeProgress calculate({
    required String type,
    required int targetDays,
    required List<ChallengeDayEvidence> days,
    required int proteinTarget,
    required int fiberTarget,
    required int waterTarget,
  }) {
    if (!supportedTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported challenge');
    }
    final qualifying = days.where((day) {
      return switch (type) {
        'protein' => day.protein >= proteinTarget * .8,
        'water' => day.waterMl >= waterTarget * .8,
        'consistentLogging' => day.hasMeal || day.hasWeight || day.waterMl > 0,
        'fiber' => day.fiber >= fiberTarget * .8,
        'return' => day.hasMeal || day.hasWeight || day.waterMl > 0,
        'weightCheckIn' => day.hasWeight,
        _ => false,
      };
    }).length;
    return ChallengeProgress(
      qualifyingDays: qualifying,
      targetDays: targetDays,
    );
  }
}
