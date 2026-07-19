enum BestActionType {
  weighIn,
  completeLogging,
  protein,
  hydration,
  holdPlan,
  none,
}

class BestAction {
  const BestAction({
    required this.type,
    required this.title,
    required this.reason,
    required this.evidence,
  });

  final BestActionType type;
  final String title;
  final String reason;
  final List<String> evidence;
}

class OneBestActionEngine {
  const OneBestActionEngine._();

  static BestAction choose({
    required bool weighedToday,
    required bool loggingComplete,
    required double protein,
    required int proteinTarget,
    required int waterMl,
    required int waterTarget,
    required int trackedDays,
    Set<BestActionType> suppressedTypes = const {},
  }) {
    if (!weighedToday && !suppressedTypes.contains(BestActionType.weighIn)) {
      return const BestAction(
        type: BestActionType.weighIn,
        title: 'Log today’s weight',
        reason: 'A comparable daily check-in improves trend confidence.',
        evidence: ['No weight check-in recorded today'],
      );
    }
    if (!loggingComplete &&
        !suppressedTypes.contains(BestActionType.completeLogging)) {
      return const BestAction(
        type: BestActionType.completeLogging,
        title: 'Complete one missing meal',
        reason: 'An incomplete day can make intake-based explanations weaker.',
        evidence: ['Today’s meal record may be incomplete'],
      );
    }
    final proteinGap = (proteinTarget - protein).round();
    if (proteinGap >= 20 && !suppressedTypes.contains(BestActionType.protein)) {
      return BestAction(
        type: BestActionType.protein,
        title: 'Add about $proteinGap g protein',
        reason: 'Protein is the largest actionable gap in today’s logged plan.',
        evidence: ['${protein.round()} g logged', '$proteinTarget g target'],
      );
    }
    final waterGap = waterTarget - waterMl;
    if (waterGap >= 400 &&
        !suppressedTypes.contains(BestActionType.hydration)) {
      return BestAction(
        type: BestActionType.hydration,
        title: 'Drink ${waterGap.clamp(400, 1000)} ml gradually',
        reason: 'Recorded hydration remains meaningfully below target.',
        evidence: ['$waterMl ml recorded', '$waterTarget ml target'],
      );
    }
    if (trackedDays < 14 &&
        !suppressedTypes.contains(BestActionType.holdPlan)) {
      return const BestAction(
        type: BestActionType.holdPlan,
        title: 'Keep the plan unchanged today',
        reason: 'More consistent observations are safer than reacting early.',
        evidence: ['Fewer than 14 comparable tracked days'],
      );
    }
    return BestAction(
      type: BestActionType.none,
      title: 'No plan change needed',
      reason: suppressedTypes.isEmpty
          ? 'Today’s recorded priorities are broadly covered.'
          : 'A repeatedly unhelpful recommendation was not repeated.',
      evidence: suppressedTypes.isEmpty
          ? const ['Weight, meal, protein, and hydration records are present']
          : const ['Two or more explicit low helpfulness ratings'],
    );
  }
}
