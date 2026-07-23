import 'dart:collection';

import 'ai_evidence.dart';

/// Deterministic interpretation of evidence for a single proposition.
enum TruthAssessmentStatus {
  supported,
  contradicted,
  uncertain,
  insufficientEvidence,
}

/// Immutable, provider-neutral result emitted by the Truth Engine.
final class TruthAssessment {
  TruthAssessment({
    required this.status,
    required this.score,
    required this.confidence,
    required String rationale,
    required Iterable<AiEvidence> evidence,
    required Iterable<String> missingEvidence,
  }) : rationale = _validatedText(rationale, 'rationale'),
       evidence = UnmodifiableListView<AiEvidence>(List.of(evidence)),
       missingEvidence = UnmodifiableListView<String>(
         missingEvidence
             .map((item) => _validatedText(item, 'missingEvidence'))
             .toList(growable: false),
       ) {
    _requireSignedUnitInterval(score, 'score');
    _requireUnitInterval(confidence, 'confidence');
    if (status == TruthAssessmentStatus.insufficientEvidence &&
        this.missingEvidence.isEmpty) {
      throw ArgumentError(
        'Insufficient-evidence assessments must disclose missing evidence.',
      );
    }
    if (status != TruthAssessmentStatus.insufficientEvidence &&
        this.evidence.isEmpty) {
      throw ArgumentError('A resolved assessment must cite evidence.');
    }
  }

  final TruthAssessmentStatus status;

  /// Signed normalized score in the inclusive range -1..1.
  final double score;

  /// Deterministic evidence coverage in the inclusive range 0..1.
  final double confidence;
  final String rationale;
  final List<AiEvidence> evidence;
  final List<String> missingEvidence;

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }

  static void _requireUnitInterval(double value, String field) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, field);
    }
  }

  static void _requireSignedUnitInterval(double value, String field) {
    if (!value.isFinite || value < -1 || value > 1) {
      throw RangeError.range(value, -1, 1, field);
    }
  }
}
