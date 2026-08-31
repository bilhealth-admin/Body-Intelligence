part of 'intelligence_center_engine.dart';

class IntelligenceCenterReply {
  const IntelligenceCenterReply({
    required this.message,
    required this.actions,
    required this.usedExternalKnowledge,
    this.spokenText,
    this.serviceStatus = CoachServiceStatus.ready,
    this.runtime = CoachAnswerRuntime.onDevice,
  });
  final IntelligenceMessage message;
  final List<IntelligenceAction> actions;
  final bool usedExternalKnowledge;
  final String? spokenText;
  final CoachServiceStatus serviceStatus;
  final CoachAnswerRuntime runtime;
}

/// Safety-first, presentation-neutral orchestration for AI Coach.
