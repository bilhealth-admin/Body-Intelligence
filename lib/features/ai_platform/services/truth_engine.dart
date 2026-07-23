import '../domain/truth_assessment.dart';
import '../domain/truth_signal.dart';

/// Deterministic and offline-first evaluator for BIL-owned truth signals.
///
/// The engine performs transparent arithmetic only. It does not use a model,
/// prompt, network, clock, randomness, persistence, or user-state mutation.
final class TruthEngine {
  const TruthEngine({
    this.supportThreshold = 0.35,
    this.contradictThreshold = -0.35,
    this.minimumConfidence = 0.25,
  }) : assert(supportThreshold > 0 && supportThreshold <= 1),
       assert(contradictThreshold >= -1 && contradictThreshold < 0),
       assert(minimumConfidence >= 0 && minimumConfidence <= 1);

  final double supportThreshold;
  final double contradictThreshold;
  final double minimumConfidence;

  TruthAssessment assess({
    required Iterable<TruthSignal> signals,
    Iterable<String> missingEvidence = const [],
  }) {
    final ordered = List<TruthSignal>.of(signals)
      ..sort((left, right) => left.key.compareTo(right.key));
    final missing =
        missingEvidence
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    _requireUniqueKeys(ordered);

    if (ordered.isEmpty) {
      return TruthAssessment(
        status: TruthAssessmentStatus.insufficientEvidence,
        score: 0,
        confidence: 0,
        rationale: 'No deterministic BIL signals were available.',
        evidence: const [],
        missingEvidence: missing.isEmpty
            ? const ['deterministic signals']
            : missing,
      );
    }

    final signedTotal = ordered.fold<double>(
      0,
      (total, signal) => total + signal.signedWeight,
    );
    final possibleTotal = ordered.fold<double>(
      0,
      (total, signal) => total + signal.reliability,
    );
    final score = possibleTotal == 0 ? 0.0 : signedTotal / possibleTotal;
    final confidence =
        ordered.fold<double>(0, (total, signal) => total + signal.reliability) /
        ordered.length;

    final status = _resolveStatus(score: score, confidence: confidence);
    final rationale = _buildRationale(
      status: status,
      signalCount: ordered.length,
      score: score,
      confidence: confidence,
    );

    return TruthAssessment(
      status: status,
      score: score.clamp(-1, 1),
      confidence: confidence.clamp(0, 1),
      rationale: rationale,
      evidence: ordered.map((signal) => signal.evidence),
      missingEvidence: missing,
    );
  }

  TruthAssessmentStatus _resolveStatus({
    required double score,
    required double confidence,
  }) {
    if (confidence < minimumConfidence) {
      return TruthAssessmentStatus.insufficientEvidence;
    }
    if (score >= supportThreshold) {
      return TruthAssessmentStatus.supported;
    }
    if (score <= contradictThreshold) {
      return TruthAssessmentStatus.contradicted;
    }
    return TruthAssessmentStatus.uncertain;
  }

  String _buildRationale({
    required TruthAssessmentStatus status,
    required int signalCount,
    required double score,
    required double confidence,
  }) {
    final scoreText = score.toStringAsFixed(3);
    final confidenceText = confidence.toStringAsFixed(3);
    return 'Assessment ${status.name} from $signalCount deterministic '
        'signal(s); normalized score=$scoreText; '
        'evidence confidence=$confidenceText.';
  }

  void _requireUniqueKeys(List<TruthSignal> signals) {
    final seen = <String>{};
    for (final signal in signals) {
      if (!seen.add(signal.key)) {
        throw ArgumentError.value(
          signal.key,
          'signals',
          'signal keys must be unique',
        );
      }
    }
  }
}
