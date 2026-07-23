import 'dart:collection';

import 'ai_evidence.dart';

/// Confidence is deliberately coarse until a BIL-owned calibration policy is
/// introduced. It must never be presented as medical certainty.
enum AiConfidenceLevel { low, medium, high }

/// An AI decision either carries one chosen action or safely abstains.
enum AiDecisionDisposition { action, abstain }

final class AiDecisionAlternative {
  AiDecisionAlternative({required this.label, required this.reasonNotChosen}) {
    _requireText(label, 'label');
    _requireText(reasonNotChosen, 'reasonNotChosen');
  }

  final String label;
  final String reasonNotChosen;

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
  }
}

/// Provider-neutral contract for every explainable decision exposed by BIL AI.
///
/// The deterministic BIL engines remain the source of truth. This object only
/// carries a selected action and its explanation; it performs no inference,
/// storage, network access, entitlement checks, or health-state mutation.
final class ExplainableAiDecision<T> {
  ExplainableAiDecision.action({
    required T value,
    required String summary,
    required String rationale,
    required Iterable<AiEvidence> evidence,
    required AiConfidenceLevel confidence,
    Iterable<AiDecisionAlternative> alternatives = const [],
    Iterable<String> missingEvidence = const [],
  }) : this._(
         disposition: AiDecisionDisposition.action,
         value: value,
         summary: summary,
         rationale: rationale,
         evidence: evidence,
         confidence: confidence,
         alternatives: alternatives,
         missingEvidence: missingEvidence,
       );

  ExplainableAiDecision.abstain({
    required String summary,
    required String rationale,
    required Iterable<String> missingEvidence,
    Iterable<AiEvidence> evidence = const [],
    Iterable<AiDecisionAlternative> alternatives = const [],
  }) : this._(
         disposition: AiDecisionDisposition.abstain,
         value: null,
         summary: summary,
         rationale: rationale,
         evidence: evidence,
         confidence: AiConfidenceLevel.low,
         alternatives: alternatives,
         missingEvidence: missingEvidence,
       );

  ExplainableAiDecision._({
    required this.disposition,
    required this.value,
    required String summary,
    required String rationale,
    required Iterable<AiEvidence> evidence,
    required this.confidence,
    required Iterable<AiDecisionAlternative> alternatives,
    required Iterable<String> missingEvidence,
  }) : summary = _validatedText(summary, 'summary'),
       rationale = _validatedText(rationale, 'rationale'),
       evidence = UnmodifiableListView<AiEvidence>(List.of(evidence)),
       alternatives = UnmodifiableListView<AiDecisionAlternative>(
         List.of(alternatives),
       ),
       missingEvidence = UnmodifiableListView<String>(
         missingEvidence
             .map((item) => _validatedText(item, 'missingEvidence'))
             .toList(growable: false),
       ) {
    if (disposition == AiDecisionDisposition.action) {
      if (value == null) {
        throw ArgumentError('An action decision must contain a value.');
      }
      if (this.evidence.isEmpty) {
        throw ArgumentError(
          'An action decision must cite deterministic BIL evidence.',
        );
      }
    } else {
      if (value != null) {
        throw ArgumentError('An abstention cannot contain an action value.');
      }
      if (this.missingEvidence.isEmpty) {
        throw ArgumentError(
          'An abstention must identify the missing evidence.',
        );
      }
    }
  }

  final AiDecisionDisposition disposition;
  final T? value;
  final String summary;
  final String rationale;
  final List<AiEvidence> evidence;
  final AiConfidenceLevel confidence;
  final List<AiDecisionAlternative> alternatives;
  final List<String> missingEvidence;

  bool get hasAction => disposition == AiDecisionDisposition.action;

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}
