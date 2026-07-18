enum ChangeInterpretation { insufficient, stable, likelyNoise, directional }

class WhatChangedReport {
  const WhatChangedReport({
    required this.interpretation,
    required this.summary,
    required this.evidence,
    required this.alternatives,
  });

  final ChangeInterpretation interpretation;
  final String summary;
  final List<String> evidence;
  final List<String> alternatives;
}

class WhatChangedEngine {
  const WhatChangedEngine._();

  static WhatChangedReport compare({
    required List<double> chronologicalWeights,
    required bool comparableConditions,
  }) {
    if (chronologicalWeights.length < 2) {
      return const WhatChangedReport(
        interpretation: ChangeInterpretation.insufficient,
        summary: 'Another comparable weight is needed to describe change.',
        evidence: [],
        alternatives: ['Normal measurement variation remains unknown'],
      );
    }
    final change =
        chronologicalWeights.last -
        chronologicalWeights.elementAt(chronologicalWeights.length - 2);
    if (change.abs() < 0.2) {
      return WhatChangedReport(
        interpretation: ChangeInterpretation.stable,
        summary: 'Weight is broadly stable since the previous check-in.',
        evidence: ['${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg'],
        alternatives: const [
          'Small daily variation can mask the underlying trend',
        ],
      );
    }
    if (change.abs() >= 0.8 || !comparableConditions) {
      return WhatChangedReport(
        interpretation: ChangeInterpretation.likelyNoise,
        summary:
            'The scale changed, but one reading is not enough to justify a plan change.',
        evidence: [
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg since the previous check-in',
          if (!comparableConditions) 'Measurement conditions differed',
        ],
        alternatives: const [
          'Water and glycogen',
          'Digestive content',
          'Measurement timing or conditions',
          'Incomplete food logging',
        ],
      );
    }
    return WhatChangedReport(
      interpretation: ChangeInterpretation.directional,
      summary:
          'A modest change was recorded; the multi-day trend is more informative.',
      evidence: ['${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg'],
      alternatives: const ['Normal day-to-day scale variation'],
    );
  }
}
